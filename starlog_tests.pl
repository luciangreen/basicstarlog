/* starlog_tests.pl — plunit tests for BASIC Starlog

   Run with:
     swipl -g "run_tests" -t halt starlog_tests.pl
*/

:- use_module(starlog).
:- use_module(library(plunit)).

/* ------------------------------------------------------------------ *
 *  1.  starlog_eval/2 — operator evaluation                          *
 * ------------------------------------------------------------------ */

:- begin_tests(starlog_eval).

test(list_append_basic) :-
    starlog_eval([1,2] & [3,4], X),
    X = [1,2,3,4].

test(list_append_empty_left) :-
    starlog_eval([] & [1,2], X),
    X = [1,2].

test(list_append_empty_right) :-
    starlog_eval([a,b] & [], X),
    X = [a,b].

test(list_append_atoms) :-
    starlog_eval([a] & [b], X),
    X = [a,b].

test(string_concat_basic) :-
    starlog_eval("hello" : " world", X),
    X = "hello world".

test(string_concat_star_log) :-
    starlog_eval("Star" : "log", X),
    X = "Starlog".

test(atom_concat_basic) :-
    starlog_eval(star ^ log, X),
    X = starlog.

test(atom_concat_hello_world) :-
    starlog_eval(hello ^ world, X),
    X = helloworld.

test(nested_list_append) :-
    starlog_eval(([1] & [2]) & [3], X),
    X = [1,2,3].

test(nested_strings) :-
    starlog_eval(("Star" : "log") : " BASIC", X),
    X = "Starlog BASIC".

test(literal_passthrough_number) :-
    starlog_eval(42, X),
    X = 42.

test(literal_passthrough_list) :-
    starlog_eval([a,b,c], X),
    X = [a,b,c].

:- end_tests(starlog_eval).

/* ------------------------------------------------------------------ *
 *  2.  Type error tests                                               *
 * ------------------------------------------------------------------ */

:- begin_tests(starlog_type_errors).

test(bad_append_not_list,
        [throws(error(starlog_type_error('&', expected_list, _), _))]) :-
    starlog_eval("abc" & [1], _).

test(bad_concat_not_string,
        [throws(error(starlog_type_error(':', expected_string_or_atom, _), _))]) :-
    starlog_eval(42 : "x", _).

test(bad_atom_concat_not_atom,
        [throws(error(starlog_type_error('^', expected_atom, _), _))]) :-
    starlog_eval(42 ^ foo, _).

:- end_tests(starlog_type_errors).

/* ------------------------------------------------------------------ *
 *  3.  Statement ordering                                             *
 * ------------------------------------------------------------------ */

:- begin_tests(starlog_order_statements).

test(already_ordered, [nondet]) :-
    Stmts = [('A' = 'B'), ('C' = 'A')],
    starlog_order_statements(Stmts, Ordered),
    Ordered = [('A' = 'B'), ('C' = 'A')].

test(empty, [nondet]) :-
    starlog_order_statements([], []).

test(single, [nondet]) :-
    starlog_order_statements([('X' = foo)], [('X' = foo)]).

test(preserves_output, [nondet]) :-
    Stmts = [('C' = ('A' & 'B')), ('D' = 'C')],
    starlog_order_statements(Stmts, Ordered),
    length(Ordered, 2).

test(reorders_dependency, [nondet]) :-
    %  'C' depends on 'B', so 'B' = [1,2] must come first
    Stmts = [('C' = ('B' & [3])), ('B' = [1,2])],
    starlog_order_statements(Stmts, Ordered),
    Ordered = [('B' = [1,2]), ('C' = ('B' & [3]))].

:- end_tests(starlog_order_statements).

/* ------------------------------------------------------------------ *
 *  4.  run_starlog/3 — header execution                              *
 * ------------------------------------------------------------------ */

:- retractall(starlog:starlog_rule(combine_words, _, _, _)),
   assertz(starlog:starlog_rule(combine_words,
       ['A','B'], ['C'],
       ['C' = ('A' : 'B')])).

:- retractall(starlog:starlog_rule(join_lists, _, _, _)),
   assertz(starlog:starlog_rule(join_lists,
       ['A','B'], ['C'],
       ['C' = ('A' & 'B')])).

:- retractall(starlog:starlog_rule(join_atoms, _, _, _)),
   assertz(starlog:starlog_rule(join_atoms,
       ['A','B'], ['C'],
       ['C' = ('A' ^ 'B')])).

:- begin_tests(run_starlog).

test(combine_words) :-
    run_starlog(combine_words, ["Star","log"], Outputs),
    Outputs = ["Starlog"].

test(join_lists) :-
    run_starlog(join_lists, [[1,2],[3,4]], Outputs),
    Outputs = [[1,2,3,4]].

test(join_atoms) :-
    run_starlog(join_atoms, [star,log], Outputs),
    Outputs = [starlog].

test(undefined_rule,
        [throws(error(starlog_undefined_predicate(no_such_rule), _))]) :-
    run_starlog(no_such_rule, [], _).

:- end_tests(run_starlog).

/* ------------------------------------------------------------------ *
 *  5.  r loop construct                                               *
 * ------------------------------------------------------------------ */

% Helper predicate for squaring — defined in user so starlog can call it
square(X, Y) :- Y is X * X.

:- retractall(starlog:starlog_rule(square_list, _, _, _)),
   assertz(starlog:starlog_rule(square_list,
       ['In'], ['Out'],
       [r('Out', 'In', square)])).

:- begin_tests(r_loop).

test(r_empty) :-
    run_starlog(square_list, [[]], Outputs),
    Outputs = [[]].

test(r_one_element) :-
    run_starlog(square_list, [[3]], Outputs),
    Outputs = [[9]].

test(r_multi_element) :-
    run_starlog(square_list, [[2,3,4]], Outputs),
    Outputs = [[4,9,16]].

:- end_tests(r_loop).

/* ------------------------------------------------------------------ *
 *  6.  starlog_to_prolog/2 — translation                             *
 * ------------------------------------------------------------------ */

:- begin_tests(starlog_to_prolog).

test(translate_append, [nondet]) :-
    Rule = starlog_rule(combine, ['A','B'], ['C'], ['C' = ('A' & 'B')]),
    starlog_to_prolog(Rule, Clause),
    Clause = (combine(_,_,_) :- _).

test(translate_string_concat, [nondet]) :-
    Rule = starlog_rule(combine_str, ['A','B'], ['C'], ['C' = ('A' : 'B')]),
    starlog_to_prolog(Rule, Clause),
    Clause = (combine_str(_,_,_) :- _).

test(translate_atom_concat, [nondet]) :-
    Rule = starlog_rule(combine_atoms, ['A','B'], ['C'], ['C' = ('A' ^ 'B')]),
    starlog_to_prolog(Rule, Clause),
    Clause = (combine_atoms(_,_,_) :- _).

:- end_tests(starlog_to_prolog).

/* ------------------------------------------------------------------ *
 *  7.  Equivalence tests (Starlog vs plain Prolog)                   *
 * ------------------------------------------------------------------ */

:- begin_tests(equivalence).

prolog_append(A, B, C) :- append(A, B, C).
prolog_string_concat(A, B, C) :- string_concat(A, B, C).
prolog_atom_concat(A, B, C) :- atom_concat(A, B, C).

test(equiv_append) :-
    starlog_eval([1,2] & [3,4], StarlogResult),
    prolog_append([1,2], [3,4], PrologResult),
    StarlogResult = PrologResult.

test(equiv_string_concat) :-
    starlog_eval("hello" : " world", StarlogResult),
    prolog_string_concat("hello", " world", PrologResult),
    StarlogResult = PrologResult.

test(equiv_atom_concat) :-
    starlog_eval(hello ^ world, StarlogResult),
    prolog_atom_concat(hello, world, PrologResult),
    StarlogResult = PrologResult.

:- end_tests(equivalence).

/* ------------------------------------------------------------------ *
 *  8.  Multi-operator example (section 19)                           *
 * ------------------------------------------------------------------ */

:- retractall(starlog:starlog_rule(make_result, _, _, _)),
   assertz(starlog:starlog_rule(make_result,
       ['A','B','C'], ['Result'],
       [
           'Name'   = ('A' : 'B'),
           'Atom'   = (star ^ log),
           'Values' = (['Name'] & ['Atom','C']),
           'Result' = 'Values'
       ])).

:- begin_tests(multi_operator).

test(make_result) :-
    run_starlog(make_result, ["Star","log",extra], Outputs),
    Outputs = [["Starlog", starlog, extra]].

:- end_tests(multi_operator).
