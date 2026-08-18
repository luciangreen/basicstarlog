/* basic.star — example BASIC Starlog programs
   Load with: load_starlog('examples/basic.star').
*/

/* combine_names(A,B)->C
   Concatenate two strings into one. */
starlog_rule(combine_names, ['A','B'], ['C'],
    ['C' = ('A' : 'B')]).

/* join_words(A,B)->C
   Join two atoms into a single atom. */
starlog_rule(join_words, ['A','B'], ['C'],
    ['C' = ('A' ^ 'B')]).

/* merge_lists(A,B)->C
   Append two lists. */
starlog_rule(merge_lists, ['A','B'], ['C'],
    ['C' = ('A' & 'B')]).

/* square_each(In)->Out
   Square every element in a list. */
starlog_rule(square_each, ['In'], ['Out'],
    [r('Out', 'In', user:square)]).
