# BASIC Starlog

A small Starlog interpreter/compiler implemented in SWI-Prolog.

BASIC Starlog lets you write concise, specification-style Prolog programs using
Starlog's characteristic notation: explicit input/output headers, symbolic
operators, the `r` loop construct, and Starlog-specific statement ordering.

---

## Quick start

```prolog
?- [starlog].
?- load_starlog('examples/basic.star').
?- run_starlog(combine_names, ["Star","log"], O).
O = ["Starlog"].
```

---

## Language overview

### Rules

A Starlog rule is the Prolog term:

```prolog
starlog_rule(Name, Inputs, Outputs, Body).
```

where `Inputs` and `Outputs` are lists of atom-variable names and `Body` is a
list of statements.

### Operators

| Operator | Meaning                         | SWI-Prolog equivalent  |
|----------|---------------------------------|------------------------|
| `A & B`  | list append                     | `append(A,B,C)`        |
| `A : B`  | string concatenation            | `string_concat(A,B,C)` |
| `A ^ B`  | atom concatenation              | `atom_concat(A,B,C)`   |

Operators may be nested:

```prolog
([1] & [2]) & [3]              % => [1,2,3]
("Star":"log") : " BASIC"      % => "Starlog BASIC"
```

### r loop

```prolog
r('Out', 'In', Goal)
```

Applies `Goal(Elem, Result)` to each element of `In`, collecting results in
`Out`.  Equivalent to `maplist(Goal, In, Out)`.

### Statement ordering

`starlog_order_statements/2` reorders statements so that each is placed once
its required variables are available, implementing Starlog's characteristic
penultimate-statement transformation.

---

## Public predicates

| Predicate                          | Description                             |
|------------------------------------|-----------------------------------------|
| `starlog_eval(+Expr, -Result)`     | Evaluate a Starlog expression           |
| `starlog_order_statements(+I, -O)` | Reorder statements (dependency-safe)    |
| `load_starlog(+File)`              | Load Starlog rules from a `.star` file  |
| `run_starlog(+Name, +In, -Out)`    | Execute a named Starlog rule            |
| `starlog_to_prolog(+Rule, -Clause)`| Translate a rule to a Prolog clause     |

---

## Example

**Starlog rule**

```prolog
starlog_rule(combine_names, ['A','B'], ['C'],
    ['C' = ('A' : 'B')]).
```

**Generated Prolog** (via `starlog_to_prolog/2`)

```prolog
combine_names(A, B, C) :-
    string_concat(A, B, C).
```

**Query**

```prolog
?- run_starlog(combine_names, ["Star","log"], O).
O = ["Starlog"].
```

---

## Running the tests

```sh
swipl -g "run_tests" -t halt starlog_tests.pl
```

All 33 plunit tests pass.

---

## Files

| File                      | Description                              |
|---------------------------|------------------------------------------|
| `starlog.pl`              | Interpreter, evaluator, compiler, loader |
| `starlog_tests.pl`        | plunit test suite                        |
| `examples/basic.star`     | Basic operator examples                  |
| `examples/multi.star`     | Multi-operator example                   |
| `PROGRAM_REQUIREMENTS.md` | Full specification                       |
