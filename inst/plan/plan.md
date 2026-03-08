# SCIP R Package Plan

## Decisions Made
- **Package name**: `scip`
- **Build strategy**: Git submodules for scip + soplex + papilo; detect system install first, fall back to building from submodules
- **Scope**: Level 2 — Full modeling API (all native SCIP constraint types, parameter control, solution pools). Plugin architecture (level 3) deferred to later.
- **CVXR path**: Conic solver (MIP_CAPABLE = TRUE), following cvxpy's pattern

## Git Submodules

Three submodules from https://github.com/scipopt:

| Repo | Latest | Purpose | Required |
|------|--------|---------|----------|
| `scipopt/scip` | v10.0.1 | Core solver (C, Apache-2.0) | Yes |
| `scipopt/soplex` | v8.0.1 | Default LP solver backend (C++, Apache-2.0) | Yes |
| `scipopt/papilo` | v3.0.0 | Parallel presolve (C++, Apache-2.0) | Yes |

Submodules go under `src/`:
```
src/
  scip/       # git submodule -> scipopt/scip@v10.0.1
  soplex/     # git submodule -> scipopt/soplex@v8.0.1
  papilo/     # git submodule -> scipopt/papilo@v3.0.0
```

### Build Order (when building from submodules)
1. Build SoPlex (CMake, static lib)
2. Build PaPILO (CMake, static lib, needs SoPlex)
3. Build SCIP (CMake, static lib, `-DLPS=spx -DPAPILO=ON`, point at SoPlex + PaPILO)
4. Link R shared object against all three

### System Library Detection (preferred path)
- `configure` checks for system SCIP via pkg-config or `SCIP_DIR` env var
- If found, use system install (fast)
- If not found, build from submodules (slow but portable)

## Lessons from cvxpy's SCIP Integration
- cvxpy uses PySCIPOpt, which doesn't fully expose SCIP's capabilities
- cvxpy treats SCIP as a conic solver: Zero, NonNeg, SOC constraints
- SOC is not native in SCIP — reformulated as auxiliary vars + quadratic constraints (x'x <= t^2)
- Duals only recovered for continuous LPs (not MIP, not SOC); requires disabling presolve/heuristics
- Key PySCIPOpt API: Model(), addVar(), addCons(), optimize(), getBestSol(), getStatus()
- Equivalent C API: SCIPcreate, SCIPcreateVarBasic, SCIPcreateConsBasicLinear, SCIPsolve, SCIPgetBestSol, SCIPgetSolVal
- Status mapping: optimal, timelimit, gaplimit, unbounded, infeasible -> standard codes
- Source: `cvxpy/reductions/solvers/conic_solvers/scip_conif.py`

## Package Structure

```
scip/
  DESCRIPTION, NAMESPACE, LICENSE, README.md
  .gitmodules               # submodule definitions
  .Rbuildignore             # exclude inst/plan from built package
  configure, configure.win, cleanup
  R/
    scip-package.R          # Package docs, useDynLib
    scip.R                  # Main solver API
    model.R                 # Model object (create, add vars/cons, solve)
    controls.R              # Solver parameter settings
    sparse.R                # CSC matrix utilities
    zzz.R                   # .onLoad / .onUnload
  src/
    Makevars.in             # Template for configure
    Makevars.win
    scip_init.c             # R_registerRoutines
    scip_wrapper.c          # C wrapper calling SCIP C API
    scip/                   # submodule: scipopt/scip@v10.0.1
    soplex/                 # submodule: scipopt/soplex@v8.0.1
    papilo/                 # submodule: scipopt/papilo@v3.0.0
  inst/
    plan/                   # This plan (excluded from R CMD build)
    tinytest/               # Tests
  man/
  tools/                    # Helper scripts for configure
  vignettes/
```

## Build System

### R Toolchain Conventions (CRITICAL)
All compilation must use R's toolchain from `$(R_HOME)/etc/Makeconf`. Never hardcode compilers.

**Compilers:**
- `$(CC)`, `$(CXX)`, `$(CXX17)` — C/C++ compilers
- `$(FC)` — Fortran compiler (if needed)
- `$(AR)`, `$(RANLIB)` — archiver

**Flags:**
- `$(CFLAGS)`, `$(CXXFLAGS)`, `$(CXX17FLAGS)` — compiler flags
- `$(CPICFLAGS)`, `$(CXXPICFLAGS)` — position-independent code
- `$(CPPFLAGS)` — preprocessor flags
- `$(LDFLAGS)` — linker flags
- `$(SAFE_FFLAGS)` — Fortran flags if needed

**Libraries (for linking):**
- `$(BLAS_LIBS)` — R's BLAS
- `$(LAPACK_LIBS)` — R's LAPACK
- `$(FLIBS)` — Fortran runtime libraries (needed when linking Fortran code from C/C++)
- `$(SHLIB_OPENMP_CFLAGS)` / `$(SHLIB_OPENMP_CXXFLAGS)` — OpenMP if SCIP uses threads

### Makevars.in template
```makefile
# Filled in by configure
SCIP_CFLAGS = @SCIP_CFLAGS@
SCIP_LIBS = @SCIP_LIBS@

CXX_STD = CXX17

PKG_CFLAGS = $(SCIP_CFLAGS)
PKG_CXXFLAGS = $(SCIP_CFLAGS)
PKG_LIBS = $(SCIP_LIBS) $(LAPACK_LIBS) $(BLAS_LIBS) $(FLIBS)
```

### Pass to CMake submodule builds
```
cmake ... \
  -DCMAKE_C_COMPILER="$(CC)" \
  -DCMAKE_CXX_COMPILER="$(CXX17)" \
  -DCMAKE_C_FLAGS="$(CFLAGS) $(CPICFLAGS) $(CPPFLAGS)" \
  -DCMAKE_CXX_FLAGS="$(CXX17FLAGS) $(CXXPICFLAGS) $(CPPFLAGS)" \
  -DCMAKE_AR="$(AR)" \
  -DCMAKE_RANLIB="$(RANLIB)" \
  -DCMAKE_EXE_LINKER_FLAGS="$(LDFLAGS)" \
  -DCMAKE_SHARED_LINKER_FLAGS="$(LDFLAGS)" \
  -DBLA_VENDOR=Generic \
  -DLAPACK_LIBRARIES="$(LAPACK_LIBS)" \
  -DBLAS_LIBRARIES="$(BLAS_LIBS)"
```

On macOS, also respect `$(MACOSX_DEPLOYMENT_TARGET)` if set.

### configure logic (pseudocode)
```
# Source R's toolchain variables
R_HOME=$(R RHOME)
. ${R_HOME}/etc/Makeconf  # or extract via Rscript

if pkg-config --exists scip; then
  SCIP_CFLAGS=$(pkg-config --cflags scip)
  SCIP_LIBS=$(pkg-config --libs scip)
elif [ -n "$SCIP_DIR" ]; then
  SCIP_CFLAGS="-I${SCIP_DIR}/include"
  SCIP_LIBS="-L${SCIP_DIR}/lib -lscip -lsoplex -lpapilo"
else
  # Build from submodules using R's compilers
  build_soplex_static()   # cmake with R toolchain vars
  build_papilo_static()   # cmake with R toolchain vars
  build_scip_static()     # cmake with R toolchain vars
  SCIP_CFLAGS="-I./scip_build/include"
  SCIP_LIBS="-L./scip_build/lib -lscip -lsoplex -lpapilo"
fi
```

## C Wrapper — Two Layers

### Layer 1: One-shot solver (for simple use and CVXR)
| C Function | Purpose |
|---|---|
| scip_solve | One-shot: create model, add vars/cons, solve, return solution, free |

### Layer 2: Model-building API (full SCIP modeling)
| C Function | Purpose |
|---|---|
| scip_model_create | Create SCIP instance, return external pointer |
| scip_model_add_var | Add variable (continuous/binary/integer) with bounds and obj |
| scip_model_add_linear_cons | Add linear constraint (<=, >=, ==) |
| scip_model_add_quadratic_cons | Add quadratic constraint |
| scip_model_add_sos1_cons | Add SOS1 constraint |
| scip_model_add_sos2_cons | Add SOS2 constraint |
| scip_model_add_indicator_cons | Add indicator constraint |
| scip_model_add_knapsack_cons | Add knapsack constraint |
| scip_model_set_param | Set solver parameter |
| scip_model_optimize | Solve |
| scip_model_get_status | Get solver status |
| scip_model_get_solution | Extract primal solution, objective |
| scip_model_get_dual | Extract dual values (continuous LP only) |
| scip_model_get_nsols | Number of solutions found |
| scip_model_get_sol_at | Get k-th solution (solution pool) |
| scip_model_free | Free SCIP instance |

Key SCIP C API functions:
- Model: SCIPcreate, SCIPcreateProbBasic, SCIPfree
- Variables: SCIPcreateVarBasic, SCIPaddVar, SCIPreleaseVar
- Linear: SCIPcreateConsBasicLinear, SCIPaddCons, SCIPreleaseCons
- Quadratic: SCIPcreateConsBasicQuadraticNonlinear (SCIP 10)
- SOS: SCIPcreateConsBasicSOS1, SCIPcreateConsBasicSOS2
- Indicator: SCIPcreateConsBasicIndicator
- Knapsack: SCIPcreateConsBasicKnapsack
- Solve: SCIPsolve, SCIPgetStatus
- Solution: SCIPgetBestSol, SCIPgetSolVal, SCIPgetSolOrigObj, SCIPgetNSols
- Params: SCIPsetRealParam, SCIPsetIntParam, SCIPsetBoolParam, etc.
- Duals: SCIPgetDualsolLinear (continuous LP only)

## R API

### One-shot interface
```r
scip_solve(obj, A, b, sense, vtype = "C", lb = 0, ub = Inf, control = list())
# obj    - objective coefficients (n-vector), minimize by default
# A      - constraint matrix (m x n, sparse)
# b      - constraint RHS (m-vector)
# sense  - constraint sense ("<=" / ">=" / "==") per row
# vtype  - variable types ("C"/"B"/"I") per variable or single value
# lb, ub - variable bounds (per variable or single value)
# control - solver parameters from scip_control()
# Returns: list(status, objval, x, sol_count, gap, info)

scip_control(verbose = TRUE, time_limit = Inf, gap_limit = 0, ...)
```

### Model-building interface
```r
m <- scip_model()                              # create model
scip_add_var(m, obj, lb, ub, vtype, name)      # add variable, returns var index
scip_add_linear_cons(m, vars, coefs, lhs, rhs) # add linear constraint
scip_add_quadratic_cons(m, ...)                 # add quadratic constraint
scip_add_sos1_cons(m, vars, weights)            # SOS type 1
scip_add_sos2_cons(m, vars, weights)            # SOS type 2
scip_add_indicator_cons(m, binvar, vars, coefs, rhs) # indicator
scip_set_param(m, name, value)                  # set SCIP parameter
scip_optimize(m)                                # solve
scip_get_status(m)                              # solver status
scip_get_solution(m)                            # primal solution
scip_get_objval(m)                              # objective value
scip_get_nsols(m)                               # number of solutions
scip_get_sol(m, k)                              # k-th solution from pool
```

## CVXR Integration

- Conic solver: MIP_CAPABLE = TRUE
- File: CVXR/R/2XX_reductions_solvers_conic_solvers_scip_conif.R
- SUPPORTED_CONSTRAINTS: list(Zero, NonNeg) — SOC via quadratic reformulation
- Uses scip_solve() one-shot interface internally
- Maps CVXR conic data (c, A, b, cone dims, bool_idx, int_idx) to scip_solve() args
- Status mapping: SCIP statuses -> CVXR OPTIMAL/INFEASIBLE/UNBOUNDED/etc.
- Dual recovery for continuous LPs only (disable presolve)

## Execution Order

1. Package skeleton (DESCRIPTION, NAMESPACE, R files)
2. Add git submodules (scip, soplex, papilo)
3. Build system (configure, Makevars.in) — detect system SCIP or build from submodules
4. C wrapper layer 1: scip_solve one-shot
5. R one-shot API (scip_solve, scip_control)
6. Sparse matrix utilities
7. Basic tests (LP, MIP)
8. C wrapper layer 2: model-building API
9. R model-building API
10. CVXR solver plugin
11. Documentation and vignettes
