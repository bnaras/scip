# Add an indicator constraint to a SCIP model

If `binvar = 1` then `sum(coefs * x[vars]) <= rhs`.

## Usage

``` r
scip_add_indicator_cons(model, binvar, vars, coefs, rhs, name = NULL)
```

## Arguments

- model:

  A SCIP model.

- binvar:

  Integer; 1-based index of the binary indicator variable.

- vars:

  Integer vector; 1-based variable indices.

- coefs:

  Numeric vector; coefficients.

- rhs:

  Numeric; right-hand side.

- name:

  Character; constraint name.

## Value

Integer; 1-based constraint index.
