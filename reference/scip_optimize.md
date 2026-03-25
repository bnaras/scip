# Solve a SCIP model

Solve a SCIP model

## Usage

``` r
scip_optimize(model)
```

## Arguments

- model:

  A SCIP model.

## Value

Invisible `NULL`. Use [`scip_get_status`](scip_get_status.md) and
[`scip_get_solution`](scip_get_solution.md) to retrieve results.
