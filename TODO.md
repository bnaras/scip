# scip — TODO for next version

## Parameter introspection API

Add runtime parameter discovery so users can explore SCIP’s ~2,700
native hierarchical parameters from within R:

- **`scip_params()`**: Query all SCIP parameters via `SCIPgetParams()` /
  `SCIPgetNParams()`. Return a data frame with columns: `name`, `type`,
  `value`, `default`, `min`, `max`, `description`. Enables
  `View(scip_params())` or `grep("conflict", scip_params()$name)`.

- **`scip_get_param(model, name)`**: Read the current value of a single
  parameter on a model instance.

Both require small C additions using SCIP’s `SCIPparamGet*` accessors.
The existing [`scip_set_param()`](reference/scip_set_param.md) already
handles setting; these complete the read side.

A vignette section showing parameter exploration workflow (discover →
inspect → set) would accompany this.
