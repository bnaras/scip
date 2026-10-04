# scip 1.10.1-1

- Upgrade the bundled solvers to the SCIP Optimization Suite 10.1.0
  (released 2026-09-18): SCIP 10.1.0, SoPlex 8.1.0, PaPILO 3.0.2.
- New `scip_control()` arguments `presolve_emphasis` and
  `separating_emphasis`, taking `"default"`, `"aggressive"`, `"fast"`,
  or `"off"` exactly like the existing `heuristics_emphasis`. They map
  to SCIP's `SCIPsetPresolving()` and `SCIPsetSeparating()`
  meta-settings, which adjust whole families of parameters at once and
  cannot be reproduced through individual parameters (#2).
- New `scip_control()` argument `emphasis` exposing SCIP's global
  parameter profiles (`SCIPsetEmphasis()`): `"feasibility"`,
  `"optimality"`, `"hardlp"`, `"numerics"`, `"easycip"`, `"cpsolver"`,
  `"counter"`, `"phasefeas"`, `"phaseimprove"`, `"phaseproof"`,
  `"benchmark"`. All emphasis settings are applied before individual
  parameters, so a native parameter passed via `...` still wins.
- Installing from a source checkout is now more efficient.

# scip 1.10.0-4

- Fix compilation with LLVM 23's libc++, reported by CRAN's
  `r-devel-linux-x86_64-fedora-clang` check. libc++ 23 dropped many
  transitive includes in all language modes, exposing three headers that
  relied on them: `<istream>` in SoPlex's `basevectors.h` and
  `mpsinput.cpp`, and `<cstdlib>` in SCIP's `multiprecision.hpp`. Because
  `basevectors.h` is reached from `soplex.h`, the first of these broke
  every translation unit including SoPlex. No user-visible change.

# scip 1.10.0-3

- Upgrade to SCIP 10.0.2, SoPlex 8.0.2, PaPILO 3.0.0.
- Enable OpenMP thread pool interface (TPI=omp) when the platform
  supports it, giving SCIP parallel branch-and-bound. Falls back
  gracefully to TPI=none when OpenMP is unavailable.
- Use `SHLIB_OPENMP_CXXFLAGS` in both `PKG_CXXFLAGS` and `PKG_LIBS`
  per R-exts §1.2.1.1.
- Drop all tinycthread patches (no longer compiled with TPI=omp/none).
  Reduces R-specific patch burden from 14 to 10 across submodules.

# scip 1.10.0-1

- Switched build system from hand-maintained Makevars.in (472 lines) to
  CMake-based build at install time, following the highs R package pattern.
- Solver sources (SCIP, SoPlex) moved from `src/` to `inst/` and deleted
  after compilation when installing from tarball, reducing installed size
  from ~258 MB to ~10 MB.
- Version now tracks SCIP Optimization Suite (10.0.x).

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
