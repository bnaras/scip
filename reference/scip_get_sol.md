# Get the k-th solution from the solution pool

Get the k-th solution from the solution pool

## Usage

``` r
scip_get_sol(model, k)
```

## Arguments

- model:

  A SCIP model.

- k:

  Integer; 1-based solution index (1 = best).

## Value

A list with `objval` and `x`.
