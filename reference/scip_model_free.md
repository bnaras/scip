# Free a SCIP model

Explicitly frees the SCIP model and all associated memory. The model is
also freed automatically when garbage collected.

## Usage

``` r
scip_model_free(model)
```

## Arguments

- model:

  A SCIP model.

## Value

Invisible `NULL`.
