# SCIP R Package — Build Notes & Upstream Patch History

## Submodule / Branch Architecture

The R package vendors three upstream libraries as git submodules, each
pointing to our forks. Our forks maintain an `r_pkg` branch containing
R-specific patches on top of the upstream release tag:

| Submodule | Upstream | Our fork | Branch |
|-----------|----------|----------|--------|
| `inst/scip` | [scipopt/scip](https://github.com/scipopt/scip) | [bnaras/scip-src](https://github.com/bnaras/scip-src) | `r_pkg` |
| `inst/soplex` | [scipopt/soplex](https://github.com/scipopt/soplex) | [bnaras/soplex-src](https://github.com/bnaras/soplex-src) | `r_pkg` |
| `src/papilo` | [scipopt/papilo](https://github.com/scipopt/papilo) | [bnaras/papilo-src](https://github.com/bnaras/papilo-src) | `r_pkg` |

The `.gitmodules` file specifies `branch = r_pkg` for all three.
The main R package always points its submodules at the `r_pkg` branch
tip of our forks.

## Why patches are needed

CRAN's `R CMD check` rejects compiled code that calls `exit()`,
`abort()`, `printf()`, `fprintf(stderr,...)`, `std::cerr`, `std::cout`,
etc. These are present throughout the SCIP and SoPlex C/C++ sources.
Our `r_pkg` patches replace them with R-safe equivalents (`Rprintf`,
`REprintf`, `Rf_error`, R I/O stream wrappers).

## Workflow for upgrading to a new upstream release

1. **Create a feature branch** on the main R package:
   ```
   cd ~/GitHub/scip && git checkout -b upgrade/scip-X.Y.Z
   ```

2. **For each submodule fork** (scip-src, soplex-src, papilo-src):
   ```
   cd inst/scip   # (or inst/soplex, src/papilo)
   git fetch upstream --tags
   git checkout master && git reset --hard vX.Y.Z
   ```

3. **Export current R patches** before rebasing (safety net):
   ```
   git format-patch master..r_pkg -o ~/patches/scip-src/
   ```

4. **Start a fresh `r_pkg` from the new tag** and try applying patches:
   ```
   git checkout -b r_pkg_new master
   git am --3way ~/patches/scip-src/0001-*.patch
   # ... resolve conflicts, skip dead patches
   ```

5. **Build and check** from the main R package:
   ```
   cd ~/GitHub && R CMD build scip && R CMD check scip_*.tar.gz --no-manual
   ```
   The key check is `checking compiled code ...` — it must show OK,
   not WARNING. If symbols like `_exit`, `_abort`, `_printf`,
   `__ZNSt3__14cerrE` appear, more patches are needed.

6. **Once clean**, rename `r_pkg_new` → `r_pkg`, force-push, update
   submodule pointers, commit on the main R package.

7. **Document** which patches were applied, which were dropped, and
   why, in this file.

## Toward eliminating patches: upstream `-DR_INTERFACE`

All our patches exist because SCIP/SoPlex assume a standalone
executable context (stdout/stderr/exit are fine). For an embedded
library context (R, Python, etc.), these need to be redirected.

A clean upstream solution would be a compile-time flag, e.g.:

```cmake
option(EMBEDDED_INTERFACE "Build for embedded use (R, Python)" OFF)
```

When enabled, a header like `scip/embedded_io.h` would redirect:

```c
#ifdef EMBEDDED_INTERFACE
  #include "embedded_streams.h"   // provided by the embedding package
  #define SCIP_PRINTF(...)  embedded_printf(__VA_ARGS__)
  #define SCIP_ABORT()      embedded_abort()
  // etc.
#else
  #define SCIP_PRINTF(...)  printf(__VA_ARGS__)
  #define SCIP_ABORT()      abort()
#endif
```

The embedding package (R, Python, etc.) would provide the
`embedded_streams.h` implementation mapping to its own I/O system.

This would benefit all downstream packages (R, Python, Julia) and
eliminate the need for fork-specific patches entirely. PRs to
upstream repos are a future goal.

---

## Patch history

### Upgrade 10.0.1 → 10.0.2 (2026-04-06)

**Upstream tags**: SCIP `v10.0.2`, SoPlex `v8.0.2`, PaPILO `v3.0.0`

Clean 10.0.2 sources build and pass tests but fail `R CMD check`
compiled code checks (stdout/stderr/exit/abort symbols in static libs).
Applied the patches below → `R CMD check` passes with Status: OK.

#### Tinycthread patches confirmed dead

With TPI=omp (or TPI=none on macOS), tinycthread is never compiled.
The bulk of our 10.0.1 patch burden was tinycthread-related
(prefixing C11 names to avoid glibc C23 collisions, guarding
includes, etc.). All of this is gone now.

#### scip-src (9 original patches, 6 applied)

**Applied** (needed for CRAN compliance):

- `0001` — Bulk stdio/abort replacements in SCIP core (message.c, misc.c, etc.)
- `0002` — Compiler warning fixes in dejavu, nauty, lpi_spx, rational.cpp.
  Minor conflict in dejavu/ds.h and dejavu/utility.h (upstream changed
  `<ostream>` to `<iostream>` in dejavu 2.1).
- `0004` — macOS `strerror_r` variant detection with `_GNU_SOURCE`.
- `0005` — `r_streams.h` header declaring `Rprintf`/`REprintf`/`r_cout()`/`r_cerr()` wrappers.
  Minor conflict in dejavu/utility.h (same `<ostream>` → `<iostream>` change).
- `0006` — More stdio/abort replacements (separate commit from 0001).
- `0008` — `objconshdlr.h`: `fprintf(stdout,...)` → `Rprintf`.

**Dropped** (dead with TPI=omp):

- `0003` — Static `githash.c` for non-CMake builds. CMake generates this now.
- `0007` — Prefix tinycthread C11 names. Pure tinycthread fix.
- `0009` — Guard tinycthread.h includes. Pure tinycthread fix.

#### soplex-src (5 original patches, 4 applied)

**Applied** (needed for CRAN compliance):

- `0001` — Redirect `std::cerr`/`std::cout` through R I/O streams.
- `0002` — Disable `fmt` `string_view`, redirect fmt I/O to R.
- `0004` — `r_streams.h` header for R I/O wrappers.
- `0005` — Fix deprecated literal operator spacing in `fmt/format.h`.
  Upstream did not fix this in 8.0.2.

**Dropped**:

- `0003` — Static `git_hash.cpp`. CMake generates this now.

#### papilo-src

No R-specific patches needed. Clean `v3.0.0` tag used directly.

### Saved patch files

The `scip-src/` and `soplex-src/` subdirectories contain the original
`git format-patch` exports from the 10.0.1 `r_pkg` branches, preserved
for reference. These can be applied with `git am --3way <file>.patch`.
