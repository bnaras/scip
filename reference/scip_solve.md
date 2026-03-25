# Solve a linear or mixed-integer program using SCIP

One-shot interface to the SCIP solver. Formulates and solves:
\$\$\min\_{x} \\ obj' x\$\$ subject to constraint rows defined by `A`,
`b`, `sense`, with variable types `vtype` and bounds `lb`, `ub`.

## Usage

``` r
scip_solve(obj, A, b, sense, vtype = "C", lb = 0, ub = Inf, control = list())
```

## Arguments

- obj:

  Numeric vector of length `n`; objective coefficients.

- A:

  Constraint matrix (`m x n`). Can be a dense matrix, `dgCMatrix`, or
  `simple_triplet_matrix`.

- b:

  Numeric vector of length `m`; constraint right-hand side.

- sense:

  Character vector of length `m`; constraint sense. Each element must be
  `"<="`, `">="`, or `"=="`.

- vtype:

  Character; variable types. Either a single value applied to all
  variables, or a vector of length `n`. Values: `"C"` (continuous),
  `"B"` (binary), `"I"` (integer). Default `"C"`.

- lb:

  Numeric; lower bounds for variables. Single value or vector of length
  `n`. Default `0`.

- ub:

  Numeric; upper bounds for variables. Single value or vector of length
  `n`. Default `Inf`.

- control:

  A list of solver parameters, typically from
  [`scip_control`](scip_control.md).

## Value

A named list with components:

- status:

  Character; solver status (e.g., "optimal", "infeasible", "unbounded").

- objval:

  Numeric; optimal objective value (or `NA` if no solution).

- x:

  Numeric vector; primal solution (or `NULL` if no solution).

- sol_count:

  Integer; number of solutions found.

- gap:

  Numeric; relative optimality gap.

- info:

  List with additional solver information (solve_time, iterations,
  nodes).
