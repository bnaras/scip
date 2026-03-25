# Add multiple variables to a SCIP model

Add multiple variables to a SCIP model

## Usage

``` r
scip_add_vars(model, obj, lb = 0, ub = Inf, vtype = "C", names = NULL)
```

## Arguments

- model:

  A SCIP model.

- obj:

  Numeric vector; objective coefficients.

- lb:

  Numeric; lower bounds (scalar or vector). Default `0`.

- ub:

  Numeric; upper bounds (scalar or vector). Default `Inf`.

- vtype:

  Character; variable types (scalar or vector). Default `"C"`.

- names:

  Character vector; variable names. Default auto-generated.

## Value

Integer; 1-based index of first variable added.
