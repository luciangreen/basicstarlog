/* multi.star — multi-operator BASIC Starlog example (section 19)
   Load with: load_starlog('examples/multi.star').

   Demonstrates: string concat (:), atom concat (^), list append (&),
   and intermediate variable chaining in a single rule.
*/

/* make_result(A,B,C)->Result
   Build a mixed list from two strings and one extra term.

   Equivalent Prolog:
     make_result(A, B, C, Result) :-
         string_concat(A, B, Name),
         atom_concat(star, log, Atom),
         append([Name], [Atom,C], Result).
*/
starlog_rule(make_result, ['A','B','C'], ['Result'],
    [
        'Name'   = ('A' : 'B'),
        'Atom'   = (star ^ log),
        'Values' = (['Name'] & ['Atom','C']),
        'Result' = 'Values'
    ]).
