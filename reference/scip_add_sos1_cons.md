# Add a SOS1 constraint to a SCIP model

At most one variable in the set can be nonzero.

## Usage

``` r
scip_add_sos1_cons(model, vars, weights = NULL, name = NULL)
```

## Arguments

- model:

  A SCIP model.

- vars:

  Integer vector; 1-based variable indices.

- weights:

  Numeric vector; weights determining branching order.

- name:

  Character; constraint name.

## Value

Integer; 1-based constraint index.
