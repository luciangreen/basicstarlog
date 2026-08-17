/* starlog.pl — BASIC Starlog interpreter/compiler for SWI-Prolog

   Operators defined:
     &  (500, xfy)  — list append
     The : and ^ operators are already defined in SWI-Prolog at priority 200.

   Public predicates
   -----------------
   starlog_eval(+Expr, -Result)           evaluate a Starlog expression
   starlog_order_statements(+In, -Out)    reorder statements (penultimate rule)
   load_starlog(+File)                    load Starlog rules from a file
   run_starlog(+Name, +Inputs, -Outputs)  run a loaded Starlog rule
   starlog_to_prolog(+Rule, -Clause)      translate a rule to a Prolog clause
*/

:- module(starlog, [
    op(500, xfy, &),
    starlog_eval/2,
    starlog_order_statements/2,
    load_starlog/1,
    run_starlog/3,
    starlog_to_prolog/2
]).

:- op(500, xfy, &).

:- use_module(library(lists)).

/* ------------------------------------------------------------------ *
 *  1.  Internal rule representation                                   *
 *                                                                      *
 *  starlog_rule(Name, Inputs, Outputs, Body)                          *
 *  Body is a list of Starlog statements.                               *
 * ------------------------------------------------------------------ */

:- dynamic starlog_rule/4.

/* ------------------------------------------------------------------ *
 *  2.  Expression evaluator                                            *
 * ------------------------------------------------------------------ */

%% starlog_eval(+Expr, -Result)
%
%  Evaluate a Starlog expression.  Nested sub-expressions are evaluated
%  recursively before the outermost operator is applied.

% List append  A & B
starlog_eval(A & B, Result) :- !,
    starlog_eval(A, VA),
    starlog_eval(B, VB),
    (   is_list(VA), is_list(VB)
    ->  append(VA, VB, Result)
    ;   throw(error(starlog_type_error('&', expected_list, VA/VB),
                    context(starlog_eval/2, 'arguments must be lists')))
    ).

% String concatenation  A : B
starlog_eval(A : B, Result) :- !,
    starlog_eval(A, VA),
    starlog_eval(B, VB),
    (   ( string(VA) ; atom(VA) ), ( string(VB) ; atom(VB) )
    ->  (   string(VA) -> VA2 = VA ; atom_string(VA, VA2) ),
        (   string(VB) -> VB2 = VB ; atom_string(VB, VB2) ),
        string_concat(VA2, VB2, Result)
    ;   throw(error(starlog_type_error(':', expected_string_or_atom, VA/VB),
                    context(starlog_eval/2, 'arguments must be strings or atoms')))
    ).

% Atom concatenation  A ^ B
starlog_eval(A ^ B, Result) :- !,
    starlog_eval(A, VA),
    starlog_eval(B, VB),
    (   atom(VA), atom(VB)
    ->  atom_concat(VA, VB, Result)
    ;   throw(error(starlog_type_error('^', expected_atom, VA/VB),
                    context(starlog_eval/2, 'arguments must be atoms')))
    ).

% Base case: anything else evaluates to itself
starlog_eval(X, X).

/* ------------------------------------------------------------------ *
 *  3.  Statement ordering (penultimate-statement transformation)      *
 * ------------------------------------------------------------------ */

%% starlog_order_statements(+Stmts, -Ordered)
%
%  Apply Starlog's statement reordering: place each statement as early
%  as possible once its required variables are available.  The final
%  output-assignment statement is kept last when possible.
%
%  Because Starlog rule variables are represented as atoms ('A', 'B' …)
%  rather than Prolog variables, readiness is determined by checking
%  whether those atom-names have been produced by earlier statements.
%
%  Variables not yet produced are assumed to be rule inputs and are
%  treated as initially available.

starlog_order_statements(Stmts, Ordered) :-
    collect_all_read_vars(Stmts, ReadVars),
    collect_all_produced_vars(Stmts, ProducedVars),
    subtract(ReadVars, ProducedVars, InputVars),
    order_stmts(Stmts, InputVars, Ordered), !.

order_stmts([], _Avail, []) :- !.
order_stmts(Stmts, Avail, [Next|Rest]) :-
    Stmts \= [],
    select_ready(Stmts, Avail, Next, Remaining), !,
    stmt_produces(Next, Produced),
    append(Avail, Produced, NewAvail),
    order_stmts(Remaining, NewAvail, Rest).

%  select_ready(+Stmts, +Avail, -Chosen, -Others)
%  Choose the first statement whose required atom-variables are available.
select_ready([S|Rest], Avail, S, Rest) :-
    stmt_requires(S, Req),
    all_available(Req, Avail), !.
select_ready([S|Rest], Avail, Chosen, [S|Others]) :-
    select_ready(Rest, Avail, Chosen, Others).

all_available([], _).
all_available([V|Vs], Avail) :-
    member(V, Avail),
    all_available(Vs, Avail).

%  collect_all_read_vars(+Stmts, -VarNames)
collect_all_read_vars(Stmts, All) :-
    maplist(stmt_requires, Stmts, Lists),
    append(Lists, All0),
    list_to_set(All0, All).

%  collect_all_produced_vars(+Stmts, -VarNames)
collect_all_produced_vars(Stmts, All) :-
    maplist(stmt_produces, Stmts, Lists),
    append(Lists, All0),
    list_to_set(All0, All).

%  stmt_requires(+Stmt, -VarNames)  — atom variable names read by a statement
stmt_requires(LHS = RHS, Vars) :- !,
    atom(LHS),
    collect_atom_vars(RHS, Vars).
stmt_requires(r(_, ListExpr, _Goal), Vars) :- !,
    collect_atom_vars(ListExpr, Vars).
stmt_requires(Stmt, Vars) :-
    collect_atom_vars(Stmt, Vars).

%  stmt_produces(+Stmt, -VarNames) — atom variable names written by statement
stmt_produces(LHS = _RHS, [LHS]) :- atom(LHS), !.
stmt_produces(r(ResultVar, _, _), [ResultVar]) :- atom(ResultVar), !.
stmt_produces(_, []).

%  collect_atom_vars(+Term, -AtomVarList)
%  Collect atoms that look like variable names (single uppercase letter or
%  atoms starting with an uppercase letter) used inside a term.
collect_atom_vars(Term, Vars) :-
    collect_atom_vars_(Term, [], Vars0),
    list_to_set(Vars0, Vars).

collect_atom_vars_(A, Acc, [A|Acc]) :-
    atom(A),
    atom_string(A, S),
    string_codes(S, [C|_]),
    C >= 0'A, C =< 0'Z, !.
collect_atom_vars_(Term, Acc, Out) :-
    compound(Term), !,
    Term =.. [_|Args],
    foldl(collect_atom_vars_, Args, Acc, Out).
collect_atom_vars_(_, Acc, Acc).

/* ------------------------------------------------------------------ *
 *  4.  r loop construct                                               *
 * ------------------------------------------------------------------ */

%% eval_r(+GoalAtom, +List, -Results)
%
%  Apply Goal(Elem, Result) to each element of List, collecting Results.
%  This implements Starlog's r looping notation.

eval_r(_Goal, [], []).
eval_r(Goal, [H|T], [R|Rs]) :-
    call(Goal, H, R),
    eval_r(Goal, T, Rs).

/* ------------------------------------------------------------------ *
 *  5.  Statement executor                                              *
 * ------------------------------------------------------------------ */

%% exec_stmts(+Stmts, +Env, -Env2)
%
%  Execute a list of Starlog statements in environment Env, producing
%  updated environment Env2.  Env is an association list Var-Value.

exec_stmts([], Env, Env).
exec_stmts([Stmt|Rest], Env, EnvOut) :-
    exec_stmt(Stmt, Env, Env1),
    exec_stmts(Rest, Env1, EnvOut).

%  Assignment: VarName = Expr  (VarName is an atom)
exec_stmt(Var = Expr, Env, [Var-Val|Env]) :-
    atom(Var), !,
    subst_expr(Expr, Env, SExpr),
    starlog_eval(SExpr, Val).

%  r loop: r(ResultVarName, ListExpr, Goal)
exec_stmt(r(ResultVar, ListExpr, Goal), Env, [ResultVar-Results|Env]) :-
    atom(ResultVar), !,
    subst_expr(ListExpr, Env, SListExpr),
    starlog_eval(SListExpr, List),
    eval_r(Goal, List, Results).

%  Plain Prolog call (fall-through)
exec_stmt(Call, Env, Env) :-
    subst_expr(Call, Env, SCall),
    call(SCall).

%% subst_expr(+Expr, +Env, -Expr2)
%  Replace variable names (atoms) with their bound values from Env.

subst_expr(Var, Env, Val) :-
    atom(Var),
    member(Var-Val, Env), !.
subst_expr(A & B, Env, SA & SB) :- !,
    subst_expr(A, Env, SA),
    subst_expr(B, Env, SB).
subst_expr(A : B, Env, SA : SB) :- !,
    subst_expr(A, Env, SA),
    subst_expr(B, Env, SB).
subst_expr(A ^ B, Env, SA ^ SB) :- !,
    subst_expr(A, Env, SA),
    subst_expr(B, Env, SB).
subst_expr(Term, Env, STerm) :-
    compound(Term), !,
    Term =.. [F|Args],
    maplist(subst_expr_(Env), Args, SArgs),
    STerm =.. [F|SArgs].
subst_expr(X, _Env, X).

subst_expr_(Env, A, SA) :- subst_expr(A, Env, SA).

/* ------------------------------------------------------------------ *
 *  6.  load_starlog/1 and run_starlog/3                               *
 * ------------------------------------------------------------------ */

%% load_starlog(+File)
%
%  Load Starlog rules from File.  Each term in the file should be:
%    starlog_rule(Name, Inputs, Outputs, Body).

load_starlog(File) :-
    setup_call_cleanup(
        open(File, read, Stream),
        load_rules_from_stream(Stream),
        close(Stream)
    ).

load_rules_from_stream(Stream) :-
    read_term(Stream, Term, [end_of_file(end_of_file),
                             module(starlog),
                             operators([op(500, xfy, &)])]),
    (   Term == end_of_file
    ->  true
    ;   assert_rule(Term),
        load_rules_from_stream(Stream)
    ).

assert_rule(starlog_rule(Name, Inputs, Outputs, Body)) :- !,
    retractall(starlog_rule(Name, _, _, _)),
    assertz(starlog_rule(Name, Inputs, Outputs, Body)).
assert_rule(Term) :-
    throw(error(starlog_malformed_rule(Term), context(load_starlog/1, 'expected starlog_rule/4'))).

%% run_starlog(+Name, +Inputs, -Outputs)
%
%  Execute the named Starlog rule with the given input values.

run_starlog(Name, InputValues, OutputValues) :-
    (   starlog_rule(Name, InputVars, OutputVars, Body)
    ->  true
    ;   throw(error(starlog_undefined_predicate(Name),
                    context(run_starlog/3, 'rule not loaded')))
    ),
    length(InputVars, NI),
    (   length(InputValues, NI)
    ->  true
    ;   throw(error(starlog_arity_error(Name, expected(NI), got(InputValues)),
                    context(run_starlog/3, 'wrong number of inputs')))
    ),
    pairs_keys_values(InputPairs, InputVars, InputValues),
    starlog_order_statements(Body, OrderedBody),
    exec_stmts(OrderedBody, InputPairs, FinalEnv),
    maplist(lookup_output(FinalEnv), OutputVars, OutputValues), !.

lookup_output(Env, Var, Val) :-
    (   member(Var-Val, Env)
    ->  true
    ;   throw(error(starlog_missing_output(Var),
                    context(run_starlog/3, 'output variable not set')))
    ).

/* ------------------------------------------------------------------ *
 *  7.  Translation to Prolog                                          *
 * ------------------------------------------------------------------ */

%% starlog_to_prolog(+Rule, -Clause)
%
%  Translate a starlog_rule/4 term into a readable Prolog clause.
%  Each Starlog atom variable name maps to a fresh, distinct Prolog variable.

starlog_to_prolog(starlog_rule(Name, Inputs, Outputs, Body), Clause) :-
    append(Inputs, Outputs, AllArgNames),
    length(AllArgNames, NArgs),
    length(AllArgVars, NArgs),          % creates NArgs fresh Prolog variables
    pairs_keys_values(VarMap, AllArgNames, AllArgVars),
    Head =.. [Name|AllArgVars],
    starlog_order_statements(Body, OrderedBody),
    maplist(translate_stmt(VarMap), OrderedBody, Goals0),
    flatten_goals(Goals0, Goals),
    (   Goals = []
    ->  Clause = (Head :- true)
    ;   goals_to_conjunction(Goals, Conj),
        Clause = (Head :- Conj)
    ).

%  translate_stmt(+VarMap, +Stmt, -Goal)
translate_stmt(VarMap, LHS = RHS, Goal) :-
    atom(LHS), !,
    lookup_or_new_var(VarMap, LHS, LVar),
    translate_expr(VarMap, RHS, LVar, Goal).
translate_stmt(VarMap, r(ResultVar, ListExpr, GoalTerm), Goal) :-
    atom(ResultVar), !,
    lookup_or_new_var(VarMap, ResultVar, RVar),
    fresh_pvar(LVar),
    translate_expr(VarMap, ListExpr, LVar, ListGoal),
    Goal = (ListGoal, maplist(GoalTerm, LVar, RVar)).
translate_stmt(VarMap, Stmt, Goal) :-
    subst_vars_in(VarMap, Stmt, Goal).

%  translate_expr(+VarMap, +Expr, +ResultVar, -Goal)
%  Produce a Prolog goal that unifies ResultVar with the value of Expr.
translate_expr(VarMap, A & B, Result, Goal) :-
    !,
    fresh_pvar(VA), fresh_pvar(VB),
    translate_expr(VarMap, A, VA, GA),
    translate_expr(VarMap, B, VB, GB),
    flatten_goals([GA, GB, append(VA, VB, Result)], Gs),
    goals_to_conjunction(Gs, Goal).
translate_expr(VarMap, A : B, Result, Goal) :-
    !,
    fresh_pvar(VA), fresh_pvar(VB),
    translate_expr(VarMap, A, VA, GA),
    translate_expr(VarMap, B, VB, GB),
    flatten_goals([GA, GB, string_concat(VA, VB, Result)], Gs),
    goals_to_conjunction(Gs, Goal).
translate_expr(VarMap, A ^ B, Result, Goal) :-
    !,
    fresh_pvar(VA), fresh_pvar(VB),
    translate_expr(VarMap, A, VA, GA),
    translate_expr(VarMap, B, VB, GB),
    flatten_goals([GA, GB, atom_concat(VA, VB, Result)], Gs),
    goals_to_conjunction(Gs, Goal).
translate_expr(VarMap, Name, Result, (Result = Var)) :-
    atom(Name),
    member(Name-Var, VarMap), !.
translate_expr(_VarMap, Lit, Result, (Result = Lit)) :-
    ( number(Lit) ; string(Lit) ; Lit = [] ; is_list(Lit) ), !.
translate_expr(_VarMap, Atom, Result, (Result = Atom)) :-
    atom(Atom), !.
translate_expr(_VarMap, X, Result, (Result = X)).

lookup_or_new_var(VarMap, Name, Var) :-
    (   member(Name-Var, VarMap)
    ->  true
    ;   true          % Var remains a fresh uninstantiated Prolog variable
    ).

subst_vars_in(VarMap, Atom, Var) :-
    atom(Atom), member(Atom-Var, VarMap), !.
subst_vars_in(VarMap, Term, STerm) :-
    compound(Term), !,
    Term =.. [F|Args],
    maplist(subst_vars_in(VarMap), Args, SArgs),
    STerm =.. [F|SArgs].
subst_vars_in(_VarMap, X, X).

fresh_pvar(_).

flatten_goals([], []).
flatten_goals([true|Rest], Out) :- !, flatten_goals(Rest, Out).
flatten_goals([G|Gs], [G|Rest]) :- flatten_goals(Gs, Rest).

goals_to_conjunction([G], G) :- !.
goals_to_conjunction([G|Gs], (G, Rest)) :- goals_to_conjunction(Gs, Rest).
