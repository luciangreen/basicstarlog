# BASIC Starlog — Program Requirements

## 1. Objective

Create a BASIC version of Starlog implemented in SWI-Prolog.

The implementation is a small Starlog interpreter/compiler, not a general
optimisation framework.  It demonstrates that ordinary Prolog-like operations
can be represented in a concise Starlog notation and executed correctly.

---

## 2. Scope

The BASIC implementation supports:

1. Starlog programs expressed as `starlog_rule/4` terms.
2. Explicit input/output declarations.
3. Nested predicate expressions.
4. Compact operators: `&` (list append), `:` (string concat), `^` (atom concat).
5. The Starlog `r` looping construct.
6. Starlog statement ordering (penultimate-statement transformation).
7. Translation of BASIC Starlog into executable Prolog.
8. Execution under SWI-Prolog.

---

## 3. Features explicitly excluded

This implementation does **not** include:

* Automatic algorithm synthesis (Spec to Algorithm).
* General choicepoint elimination or findall conversion (Loop2).
* Semantic superoptimisation or predicate splicing (PLOp).
* Deterministic splice compilation or effect scheduling (Detlog).
* Predictive parallel scheduling (Piglog2).

---

## 4. Rule representation

```prolog
starlog_rule(Name, Inputs, Outputs, Body).
```

* `Name`    — predicate atom
* `Inputs`  — list of atom variable names, e.g. `['A','B']`
* `Outputs` — list of atom variable names, e.g. `['C']`
* `Body`    — list of Starlog statements

---

## 5. Operators

| Operator | Prolog equivalent      | Notes                  |
|----------|------------------------|------------------------|
| `A & B`  | `append(A, B, C)`      | Both operands must be lists |
| `A : B`  | `string_concat(A,B,C)` | Operands: strings or atoms → produces string |
| `A ^ B`  | `atom_concat(A, B, C)` | Both operands must be atoms |

Operators may be nested arbitrarily.

---

## 6. r loop

```prolog
r('Result', 'ListVar', Goal)
```

Equivalent to `maplist(Goal, ListVar, Result)`.

---

## 7. Statement ordering

`starlog_order_statements/2` reorders a list of statements so that each
statement is placed as early as possible once the variables it reads have been
produced by earlier statements.

---

## 8. Public predicates

```prolog
starlog_eval(+Expr, -Result)
starlog_order_statements(+Stmts, -Ordered)
load_starlog(+File)
run_starlog(+Name, +Inputs, -Outputs)
starlog_to_prolog(+Rule, -Clause)
```

---

## 9. Error terms

| Error term                                      | Meaning                       |
|-------------------------------------------------|-------------------------------|
| `starlog_type_error(Op, Expected, Got)`         | Wrong argument type           |
| `starlog_undefined_predicate(Name)`             | Rule not loaded               |
| `starlog_arity_error(Name, expected(N), got(V))`| Wrong number of inputs        |
| `starlog_missing_output(Var)`                   | Output variable not produced  |
| `starlog_malformed_rule(Term)`                  | Bad term in `.star` file      |

---

## 10. Acceptance criteria

```prolog
?- starlog_eval([a] & [b], X).
X = [a,b].

?- starlog_eval("Star" : "log", X).
X = "Starlog".

?- starlog_eval(star ^ log, X).
X = starlog.
```

A Starlog program with explicit inputs and outputs can be loaded and executed.
Nested Starlog expressions work.
The `r` looping construct works for empty, singleton, and multi-element lists.
Statement ordering is implemented and dependency-safe.
A Starlog program can be translated into readable SWI-Prolog.
All 33 plunit tests pass.
