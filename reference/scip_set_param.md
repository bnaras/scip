# Set a SCIP parameter

Set a SCIP parameter

## Usage

``` r
scip_set_param(model, name, value)
```

## Arguments

- model:

  A SCIP model.

- name:

  Character; SCIP parameter name (e.g., `"limits/time"`).

- value:

  The parameter value (type is auto-detected by SCIP).

## Value

Invisible `NULL`.
