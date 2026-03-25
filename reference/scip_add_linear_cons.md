# Add a linear constraint to a SCIP model

Adds `lhs <= sum(coefs * x[vars]) <= rhs`.

## Usage

``` r
scip_add_linear_cons(model, vars, coefs, lhs = -Inf, rhs = Inf, name = NULL)
```

## Arguments

- model:

  A SCIP model.

- vars:

  Integer vector; 1-based variable indices.

- coefs:

  Numeric vector; coefficients (same length as `vars`).

- lhs:

  Numeric; left-hand side. Default `-Inf`.

- rhs:

  Numeric; right-hand side. Default `Inf`.

- name:

  Character; constraint name. Default auto-generated.

## Value

Integer; 1-based constraint index.
