# BASIC Starlog

BASIC Starlog is a small Starlog interpreter and Prolog compiler implemented in
SWI-Prolog. It supports explicit rule inputs and outputs, compact expression
operators, list mapping with `r`, dependency-based statement ordering, loading
`.star` files, and translation to ordinary Prolog clauses.

## Requirements and quick start

Install SWI-Prolog, then start the interpreter from the repository root:

```sh
swipl
```

In the Prolog prompt:

```prolog
?- [starlog].
?- load_starlog('examples/basic.star').
?- run_starlog(combine_names, ["Star", "log"], Outputs).
Outputs = ["Starlog"].
```

The rule files use atom names in single quotes to denote Starlog variables:

```prolog
starlog_rule(combine_names, ['A','B'], ['C'],
    ['C' = ('A' : 'B')]).
```

Inputs and outputs are lists of variable names; the body is a list of
assignments, `r` loops, or callable Prolog goals. Each run supplies one value
per input and returns output values in the declared order.

## Language features

### Expressions

Expressions can nest these operators:

| Operator | Behavior | Example |
|---|---|---|
| `A & B` | Append two lists | `[a] & [b]` evaluates to `[a,b]` |
| `A : B` | Concatenate strings or atoms, returning a string | `"Star" : "log"` evaluates to `"Starlog"` |
| `A ^ B` | Concatenate two atoms, returning an atom | `star ^ log` evaluates to `starlog` |

Other values pass through unchanged. Invalid operand types raise
`starlog_type_error(Op, Expected, Got)`.

### Rules, assignments, and statement ordering

An assignment has the form `'Variable' = Expression`. A variable can be an
input, a value assigned earlier (or later in the source and moved earlier by
the ordering pass), or an output. Statement ordering places assignments after
the statements that produce their dependencies; names read but never produced
are treated as input variables. The first ready statement in source order is
selected, so independent statements keep a stable order.

### `r` list mapping

`r('Output', ListExpression, Goal)` applies a two-argument predicate to each
list element and collects the results, equivalent to `maplist(Goal, List,
Output)`. For example, `r('Out', 'In', user:square)` maps `user:square/2`.
Qualify helper predicates with their module when needed. Empty lists produce
empty outputs.

### Loading and compiling

`load_starlog(+File)` reads `starlog_rule/4` terms from a `.star` file. Loading
a rule with a name already present replaces that rule. A non-rule term raises
`starlog_malformed_rule(Term)`.

`starlog_to_prolog(+Rule, -Clause)` translates a rule into a clause term whose
head arguments are the declared inputs followed by the declared outputs.
Intermediate assignment variables are shared correctly throughout the
generated clause. The returned clause can be asserted into a module or written
with Prolog's term-writing predicates.

## Public predicates and errors

| Predicate | Description |
|---|---|
| `starlog_eval(+Expr, -Result)` | Evaluate an expression |
| `starlog_order_statements(+Statements, -Ordered)` | Reorder statements by dependencies |
| `load_starlog(+File)` | Load or replace rules from a file |
| `run_starlog(+Name, +Inputs, -Outputs)` | Run a loaded rule |
| `starlog_to_prolog(+Rule, -Clause)` | Translate a rule into a Prolog clause |

The implementation reports errors as:

| Error term | Meaning |
|---|---|
| `starlog_type_error(Op, Expected, Got)` | Operator received unsupported operand types |
| `starlog_undefined_predicate(Name)` | Requested rule is not loaded |
| `starlog_arity_error(Name, expected(N), got(Actual))` | Wrong number of input values |
| `starlog_missing_output(Var)` | A declared output was not assigned or supplied |
| `starlog_malformed_rule(Term)` | A loaded file contained a term other than `starlog_rule/4` |
| `starlog_missing_variable(Name)` | A generated clause references a variable not declared or produced by the rule |

## Tests and examples

Run all plunit tests from the repository root:

```sh
swipl -g "run_tests" -t halt starlog_tests.pl
```

The suite covers operator results and type errors, statement ordering,
rule execution and arity errors, empty/singleton/multiple-element loops,
generated clauses (including intermediate variables and loops), and equivalence
with corresponding Prolog operations. Example rule files are in `examples/`.

## Scope and remaining work

This BASIC implementation intentionally does not implement automatic
specification-to-algorithm synthesis, general choicepoint elimination or
`findall` conversion (Loop2), semantic superoptimization or predicate splicing
(PLOp), deterministic splice compilation or effect scheduling (Detlog), or
predictive parallel scheduling (Piglog2). These are separate extensions, not
part of the current BASIC feature set.

## Files

| File | Description |
|---|---|
| `starlog.pl` | Interpreter, dependency ordering, loader, and compiler |
| `starlog_tests.pl` | plunit regression suite |
| `examples/basic.star` | Operators and list-loop rule examples |
| `examples/multi.star` | Combined operators and intermediate assignments |
| `PROGRAM_REQUIREMENTS.md` | Feature scope and acceptance requirements |
