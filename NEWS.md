# scip 0.0.2

Initial CRAN submission.

- One-shot solver interface (`scip_solve`) and incremental
  model-building API (`scip_model`, `scip_add_var`,
  `scip_add_linear_cons`, `scip_add_quadratic_cons`,
  `scip_add_sos1_cons`, `scip_add_sos2_cons`,
  `scip_add_indicator_cons`).
- Solver control parameters (`scip_control`).
- Sparse matrix support (dgCMatrix, simple_triplet_matrix).
- Vignette with LP, MIP, quadratic, and indicator constraint examples.
- Builds on macOS, Linux, and Windows using vendored SCIP 10.0.1 and
  SoPlex 8.0.1 sources.
