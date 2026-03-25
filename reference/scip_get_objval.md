# Get objective value of best solution

Get objective value of best solution

## Usage

``` r
scip_get_objval(model)
```

## Arguments

- model:

  A SCIP model (after [`scip_optimize`](scip_optimize.md)).

## Value

Numeric; objective value, or `NA` if no solution.
