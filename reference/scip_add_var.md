# Add a variable to a SCIP model

Add a variable to a SCIP model

## Usage

``` r
scip_add_var(model, obj, lb = 0, ub = Inf, vtype = "C", name = NULL)
```

## Arguments

- model:

  A SCIP model (external pointer from [`scip_model`](scip_model.md)).

- obj:

  Numeric; objective coefficient.

- lb:

  Numeric; lower bound. Default `0`.

- ub:

  Numeric; upper bound. Default `Inf`.

- vtype:

  Character; variable type: `"C"` (continuous), `"B"` (binary), or `"I"`
  (integer). Default `"C"`.

- name:

  Character; variable name. Default auto-generated.

## Value

Integer; 1-based variable index.
