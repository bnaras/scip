# SCIP solver control parameters

Create a list of control parameters for the SCIP solver. Parameters are
organized into logical groups: output, limits, tolerances, presolving,
LP, branching, heuristics, separating, and emphasis. Any SCIP parameter
can also be set directly using its native path via `...`.

## Usage

``` r
scip_control(
  verbose = TRUE,
  verbosity_level = 3L,
  display_freq = 100L,
  time_limit = Inf,
  node_limit = -1L,
  stall_node_limit = -1L,
  sol_limit = -1L,
  best_sol_limit = -1L,
  mem_limit = Inf,
  restart_limit = -1L,
  gap_limit = 0,
  abs_gap_limit = 0,
  feastol = 1e-06,
  dualfeastol = 1e-07,
  epsilon = 1e-09,
  presolving = TRUE,
  presolve_rounds = -1L,
  presolve_emphasis = "default",
  lp_threads = 1L,
  lp_iteration_limit = -1L,
  lp_scaling = TRUE,
  branching_score = "p",
  heuristics_emphasis = "default",
  separating_emphasis = "default",
  emphasis = "default",
  threads = 1L,
  ...
)
```

## Arguments

- verbose:

  Logical; print solver output. Default `TRUE`.

- verbosity_level:

  Integer 0–5; verbosity detail. Default `3`.

- display_freq:

  Integer; node display frequency. Default `100`.

- time_limit:

  Numeric; time limit in seconds. Default `Inf`.

- node_limit:

  Integer; max nodes. Default `-1L`.

- stall_node_limit:

  Integer; stall nodes. Default `-1L`.

- sol_limit:

  Integer; solution limit. Default `-1L`.

- best_sol_limit:

  Integer; improving solution limit. Default `-1L`.

- mem_limit:

  Numeric; memory limit in MB. Default `Inf`.

- restart_limit:

  Integer; restart limit. Default `-1L`.

- gap_limit:

  Numeric; relative MIP gap. Default `0`.

- abs_gap_limit:

  Numeric; absolute gap. Default `0`.

- feastol:

  Numeric; feasibility tolerance. Default `1e-6`.

- dualfeastol:

  Numeric; dual feasibility tolerance. Default `1e-7`.

- epsilon:

  Numeric; zero tolerance. Default `1e-9`.

- presolving:

  Logical; enable presolving. Default `TRUE`.

- presolve_rounds:

  Integer; presolve rounds. Default `-1L`.

- presolve_emphasis:

  Character; presolving emphasis. Default `"default"`.

- lp_threads:

  Integer; LP solver threads. Default `1L`.

- lp_iteration_limit:

  Integer; LP iteration limit. Default `-1L`.

- lp_scaling:

  Logical; LP scaling. Default `TRUE`.

- branching_score:

  Character; score function. Default `"p"`.

- heuristics_emphasis:

  Character; heuristic emphasis. Default `"default"`.

- separating_emphasis:

  Character; separating emphasis. Default `"default"`.

- emphasis:

  Character; global solver emphasis. Default `"default"`. See the
  Emphasis section.

- threads:

  Integer; parallel solving threads. Default `1L`. See Parallel section
  for caveats.

- ...:

  Additional SCIP parameters as name-value pairs, using SCIP's native
  hierarchical parameter paths (e.g., `"lp/fastmip" = 1`,
  `"conflict/enable" = FALSE`). See the [SCIP parameter
  documentation](https://www.scipopt.org/doc/html/PARAMETERS.php) for
  the full list.

## Value

A named list of class `"scip_control"` with components:

- `verbose`:

  Logical; verbosity flag.

- `scip_params`:

  Named list; all parameters as SCIP native paths.

## Details

The four emphasis arguments (`emphasis`, `presolve_emphasis`,
`heuristics_emphasis`, `separating_emphasis`) are SCIP meta-settings:
each one adjusts a whole family of native parameters at once, the same
way SCIP's interactive shell commands `set emphasis`,
`set presolving emphasis`, `set heuristics emphasis` and
`set separating emphasis` do. They are applied before any individual
parameter, in that order, so a native parameter given via `...` always
overrides whatever the emphasis chose for it.

## Output

- `verbose`:

  Logical; print solver output. Default `TRUE`.

- `verbosity_level`:

  Integer 0–5; verbosity detail (0 = none, 3 = normal, 5 = full).
  Default `3`. Ignored if `verbose = FALSE`.

- `display_freq`:

  Integer; display a status line every this many nodes (`-1` = never).
  Default `100`.

## Termination Limits

- `time_limit`:

  Numeric; maximum solving time in seconds. Default `Inf` (no limit).

- `node_limit`:

  Integer; maximum number of branch-and-bound nodes. Default `-1L` (no
  limit).

- `stall_node_limit`:

  Integer; nodes without improvement before stopping. Default `-1L` (no
  limit).

- `sol_limit`:

  Integer; stop after finding this many feasible solutions. Default
  `-1L` (no limit).

- `best_sol_limit`:

  Integer; stop after this many improving solutions. Default `-1L` (no
  limit).

- `mem_limit`:

  Numeric; memory limit in MB. Default `Inf` (no limit).

- `restart_limit`:

  Integer; maximum restarts. Default `-1L` (no limit).

## Tolerances

- `gap_limit`:

  Numeric; relative MIP gap tolerance; solver stops when the gap falls
  below this value. Default `0` (prove optimality).

- `abs_gap_limit`:

  Numeric; absolute gap between primal and dual bound. Default `0`.

- `feastol`:

  Numeric; feasibility tolerance for LP constraints. Default `1e-6`.

- `dualfeastol`:

  Numeric; dual feasibility tolerance. Default `1e-7`.

- `epsilon`:

  Numeric; absolute values below this are treated as zero. Default
  `1e-9`.

## Presolving

- `presolving`:

  Logical; enable presolving. Default `TRUE`.

- `presolve_rounds`:

  Integer; maximum presolving rounds (`-1` = unlimited). Default `-1L`.

- `presolve_emphasis`:

  Character; presolving emphasis setting: `"default"`, `"aggressive"`,
  `"fast"`, or `"off"`. Default `"default"`.

## LP

- `lp_threads`:

  Integer; number of threads for LP solver. Default `1L`.

- `lp_iteration_limit`:

  Integer; LP iteration limit per solve (`-1` = no limit). Default
  `-1L`.

- `lp_scaling`:

  Logical; enable LP scaling. Default `TRUE`.

## Branching

- `branching_score`:

  Character; branching score function: `"s"` (sum), `"p"` (product),
  `"q"` (quotient). Default `"p"`.

## Heuristics

- `heuristics_emphasis`:

  Character; heuristic emphasis setting: `"default"`, `"aggressive"`,
  `"fast"`, or `"off"`. Default `"default"`.

## Separating

- `separating_emphasis`:

  Character; cutting-plane separation emphasis setting: `"default"`,
  `"aggressive"`, `"fast"`, or `"off"`. Default `"default"`.

## Emphasis

- `emphasis`:

  Character; global solver emphasis, choosing a predefined parameter
  profile for a problem class or solving goal. One of `"default"`,
  `"cpsolver"` (constraint-programming style search, no LP relaxation),
  `"easycip"` (solve easy problems fast), `"feasibility"` (find a
  feasible solution fast), `"hardlp"` (cope with hard LP relaxations),
  `"optimality"` (prove optimality fast), `"counter"` (solution
  counting), `"phasefeas"`, `"phaseimprove"`, `"phaseproof"` (the three
  phases of SCIP's three-phase approach), `"numerics"` (increased
  numerical safety), or `"benchmark"` (do not try to avoid the memory
  limit). Default `"default"`.

## Parallel

- `threads`:

  Integer; number of threads for concurrent solving. Default `1L`. Note:
  concurrent solving may require a SCIP build compiled with parallel
  support (e.g., `PARASCIP=true`); not all installations provide this.

## See also

[`scip_solve`](scip_solve.md), [`scip_set_param`](scip_set_param.md)

## Examples

``` r
## Quick solve with 60-second time limit
ctrl <- scip_control(time_limit = 60)

## Quiet solve with 1% gap tolerance
ctrl <- scip_control(verbose = FALSE, gap_limit = 0.01)

## Aggressive heuristics, no presolving
ctrl <- scip_control(heuristics_emphasis = "aggressive", presolving = FALSE)

## Aggressive presolving and separation, as for hard combinatorial MIPs
ctrl <- scip_control(presolve_emphasis = "aggressive",
                     separating_emphasis = "aggressive")

## Global profile: find a feasible solution quickly
ctrl <- scip_control(emphasis = "feasibility")

## Pass a native SCIP parameter directly
ctrl <- scip_control("conflict/enable" = FALSE, "separating/maxrounds" = 5L)
```
