# Add a quadratic constraint to a SCIP model

Adds `lhs <= linexpr + quadexpr <= rhs` where
`quadexpr = sum(quadcoefs[k] * x[quadvars1[k]] * x[quadvars2[k]])`.

## Usage

``` r
scip_add_quadratic_cons(
  model,
  linvars = integer(0),
  lincoefs = double(0),
  quadvars1 = integer(0),
  quadvars2 = integer(0),
  quadcoefs = double(0),
  lhs = -Inf,
  rhs = Inf,
  name = NULL
)
```

## Arguments

- model:

  A SCIP model.

- linvars:

  Integer vector; 1-based variable indices for linear part.

- lincoefs:

  Numeric vector; linear coefficients.

- quadvars1, quadvars2:

  Integer vectors; 1-based variable indices for quadratic terms.

- quadcoefs:

  Numeric vector; quadratic coefficients.

- lhs, rhs:

  Numeric; constraint bounds.

- name:

  Character; constraint name.

## Value

Integer; 1-based constraint index.
