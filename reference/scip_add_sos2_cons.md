# Add a SOS2 constraint to a SCIP model

At most two adjacent variables in the set can be nonzero.

## Usage

``` r
scip_add_sos2_cons(model, vars, weights = NULL, name = NULL)
```

## Arguments

- model:

  A SCIP model.

- vars:

  Integer vector; 1-based variable indices.

- weights:

  Numeric vector; weights determining adjacency order.

- name:

  Character; constraint name.

## Value

Integer; 1-based constraint index.
