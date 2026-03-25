# Get solver status

Get solver status

## Usage

``` r
scip_get_status(model)
```

## Arguments

- model:

  A SCIP model (after [`scip_optimize`](scip_optimize.md)).

## Value

Character; status string (e.g., `"optimal"`, `"infeasible"`).
