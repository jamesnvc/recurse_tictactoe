:- module(tictactoe, []).

:- use_module(library(tty), [tty_clear/0]).
:- use_module(library(terms), [mapargs/3]).
:- use_module(library(random), [random_member/2]).

:- initialization(main, main).

main(_) :-
    init_state(StateI),
    with_tty_raw(
        game_loop(StateI)
    ).

init_state(state(turn(x),
                 board(row(cell(empty), cell(empty), cell(empty)),
                       row(cell(empty), cell(empty), cell(empty)),
                       row(cell(empty), cell(empty), cell(empty))))).

game_loop(State0) :-
    draw_board(State0),
    ( game_over(State0, How)
    -> display_game_over(How)
    ; get_next_state(State0, State1),
      game_loop(State1) ).

get_next_state(state(turn(x), Board), State1) :-
    play_human_move(state(turn(x), Board), State1).
get_next_state(state(turn(o), Board), State1) :-
    play_robot_move(state(turn(o), Board), State1).

play_robot_move(state(turn(Me), Board), State1) :-
    findall(Xe-Ye,
            ( arg(Ye, Board, Row),
              arg(Xe, Row, cell(empty)) ),
            EmptyCellCoords),
    random_member(X-Y, EmptyCellCoords),
    arg(Y, Board, Row),
    replace_arg(X, Row, cell(Me), NewRow),
    replace_arg(Y, Board, NewRow, NewBoard),
    next_player(Me, NextPlayer),
    State1 = state(turn(NextPlayer), NewBoard).

play_human_move(State0, State1) :-
    repeat,
    start_mouse_tracking,
    read_mouse_event(Event),
    stop_mouse_tracking,
    handle_click(Event, State0, State1), !.

% Horizontal winner
game_over(state(_, Board), winner(P)) :-
    between(1, 3, X),
    setof(Cell,
          Y^Row^( between(1, 3, Y),
                arg(Y, Board, Row),
                arg(X, Row, Cell)),
          [cell(P)]),
    P \= empty,
    !.
% Vertical winner
game_over(state(_, Board), winner(P)) :-
    between(1, 3, Y),
    setof(Cell,
          X^Row^( between(1, 3, X),
                arg(Y, Board, Row),
                arg(X, Row, Cell)),
          [cell(P)]),
    P \= empty,
    !.
% Diagonal 1
game_over(state(_, Board), winner(P)) :-
    setof(Cell,
          XY^Row^( between(1, 3, XY),
                arg(XY, Board, Row),
                arg(XY, Row, Cell)),
          [cell(P)]),
    P \= empty,
    !.
% Diagonal 2
game_over(state(_, Board), winner(P)) :-
    setof(Cell,
          X^Y^Row^( member(X-Y, [1-3, 2-2, 3-1]),
                arg(Y, Board, Row),
                arg(X, Row, Cell)),
          [cell(P)]),
    P \= empty,
    !.
% draw
game_over(state(_, Board), draw) :-
    forall(( between(1, 3, X),
             between(1, 3, Y) ),
          ( arg(Y, Board, Row),
            arg(X, Row, Cell),
            Cell \= cell(empty) )
          ).

display_game_over(draw) :-
    format("~nTie game :S~n", []),
    sleep(2).
display_game_over(winner(Player)) :-
    format("~n~w wins!~n", [Player]),
    sleep(2).

draw_board(State) :-
    tty_clear,
    grid_padding(XPad, YPad),

    board_decoration,

    tty_goto(0, YPad),

    State = state(turn(Player), board(L1, L2, L3)),
    length(Padding, XPad),
    maplist(=(0' ), Padding),
    maplist(render_board_line, [L1, L2, L3], [L1r, L2r, L3r]),
    format("~s~s~s~n", [Padding, L1r, Padding]),
    format("~s-+-+-~s~n", [Padding, Padding]),
    format("~s~s~s~n", [Padding, L2r, Padding]),
    format("~s-+-+-~s~n", [Padding, Padding]),
    format("~s~s~s~n", [Padding, L3r, Padding]),

    format("~s~w's turn", [Padding, Player]).

board_decoration :-
    catch(tty_size(Rows, Cols), _, ( Rows = 0, Cols = 0)),
    MaxX is Cols - 2,
    MaxY is Rows - 2,

    tty_goto(0, 0),

    TransFlagCodes = [127987, 65039, 8205, 9895, 65039],

    format("~s", [TransFlagCodes]),

    tty_goto(MaxX, MaxY),
    format("~s", [TransFlagCodes]),

    RainbowFlagCodes = [127987, 65039, 8205, 127752],
    tty_goto(0, MaxY),
    format("~s", [RainbowFlagCodes]),

    tty_goto(MaxX, 0),
    format("~s", [RainbowFlagCodes]).

render_board_line(Cells, Formatted) :-
    mapargs(render_cell, Cells, row(C1, C2, C3)),
    format(string(Formatted), "~s|~s|~s", [C1, C2, C3]).

render_cell(cell(empty), " ").
render_cell(cell(x), "X").
render_cell(cell(o), "O").

%! handle_click(+ScreenClick, +OldState, -NewState) is semidet.
%
%  Update the state based on the click. Fails if invalid (click out of
%  bounds, click on already-occupied cell).
handle_click(click(ScreenX, ScreenY), state(turn(Player), Board0), State1) :-
    screen_to_grid(ScreenX-ScreenY, X-Y),
    update_board(Board0, Player, X-Y, Board),
    next_player(Player, Player1),
    State1 = state(turn(Player1), Board).

update_board(Board0, Player, X-Y, Board1) :-
    arg(Y, Board0, Row),
    arg(X, Row, cell(empty)),
    replace_arg(X, Row, cell(Player), NewRow),
    replace_arg(Y, Board0, NewRow, Board1).

replace_arg(Arg, Term, NewVal, NewTerm) :-
    compound_name_arguments(Term, Name, Args),
    replace_nth1(Arg, Args, NewVal, NewArgs),
    compound_name_arguments(NewTerm, Name, NewArgs).

replace_nth1(Index1, List, NewElem, NewList) :-
    nth1(Index1, List, _, Transfer),
    nth1(Index1, NewList, NewElem, Transfer).

screen_to_grid(Sx-Sy, Gx-Gy) :-
    catch(tty_size(Rows, Cols), _, ( Rows = 0, Cols = 0)),
    grid_padding(XPad, YPad),
    XPadEnd is XPad + 5, between(XPad, XPadEnd, Sx),
    YPadEnd is YPad + 5, between(YPad, YPadEnd, Sy),
    % Even grid numbers are lines
    1 is (Sx - XPad) mod 2,
    1 is (Sy - YPad) mod 2,
    % divided by two to account for grid lines
    Gx is ceil((Sx - XPad) / 2),
    Gy is ceil((Sy - YPad) / 2).

next_player(x, o).
next_player(o, x).

%% Terminal stuff

grid_padding(XPad, YPad) :-
    catch(tty_size(Rows, Cols), _, ( Rows = 0, Cols = 0)),
    XPad is floor(max(0, Cols - 5) / 2),
    YPad is ceil(max(0, Rows - 5) / 2).

start_mouse_tracking :- format('\e[?1000;1006;1015h', []).
stop_mouse_tracking  :- format('\e[?1000;1006;1015l', []).

read_mouse_event(E) :-
    repeat,
    read_chars_until([0'm, 0'M], [0'\e, 0'[, 0'3, 0'5, 0';|Rest]),
    append(XCodes, [0';|YCodes], Rest),
    !,
    number_codes(XPos, XCodes),
    number_codes(YPos, YCodes),
    E = click(XPos, YPos).

read_chars_until(EndCodes, Codes) :-
    get_single_char(Code),
    ( memberchk(Code, EndCodes)
    -> Codes = [] % arguably `Codes = [Code]` makes more sense...but this is more
                  % convenient in this particular case
    ; Codes = [Code|NextCodes],
      read_chars_until(EndCodes, NextCodes) ).
