# Get solver information

Get solver information

## Usage

``` r
scip_get_info(model)
```

## Arguments

- model:

  A SCIP model (after [`scip_optimize`](scip_optimize.md)).

## Value

A list with `solve_time`, `nodes`, `iterations`, `gap`, `sol_count`.
