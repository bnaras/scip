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

### Critical: TPI=omp and `_FORTIFY_SOURCE`

When SCIP is built with TPI=omp (OpenMP thread pool, enabled on Linux),
`tpi_openmp.c` is compiled into `libscip.a`. This file contains a bare
`printf("err1")` call. On Ubuntu with GCC 15 and `-D_FORTIFY_SOURCE=3`
(inherited from R's CFLAGS per R-exts §1.2.6), GCC replaces `printf`
with `__printf_chk` — and this symbol reference persists in the static
library even though it's in an error path that's rarely hit.

**This is invisible on macOS** because:
1. macOS uses TPI=none (Apple clang lacks OpenMP), so `tpi_openmp.c`
   is never compiled
2. Even if it were, clang doesn't use `_FORTIFY_SOURCE` the same way

**Lesson learned**: Always test on Linux with OpenMP when patching
printf calls. macOS builds give false confidence.

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

4. **Start a fresh `r_pkg` from the new tag** and apply patches:
   ```
   git checkout -b r_pkg master
   git am --3way ~/patches/scip-src/0005-*.patch   # r_streams.h first
   git am --3way ~/patches/scip-src/0001-*.patch   # then the rest
   # ... resolve conflicts, skip dead patches
   ```

5. **Check for NEW bare printf calls** added by the upstream release:
   ```
   grep -rn '[^a-zA-Z_]printf\s*(' src/ --include='*.c' --include='*.cpp' \
     | grep -v '//.*printf' \
     | grep -v 'Rprintf\|snprintf\|sprintf\|fprintf\|vprintf' \
     | grep -v '#define\|while.*FALSE'
   ```
   Pay special attention to `src/tpi/tpi_openmp.c` — only compiled
   with TPI=omp on Linux, invisible on macOS.

6. **Find the exact offending object** on Linux if `R CMD check` still
   shows `__printf_chk` or similar:
   ```
   nm -A /path/to/sciplib/lib/libscip.a | grep '__printf_chk'
   ```
   This tells you exactly which `.o` file to fix.

7. **Build and check** from the main R package:
   ```
   cd ~/GitHub && R CMD build scip && R CMD check scip_*.tar.gz --no-manual
   ```
   The key check is `checking compiled code ...` — it must show OK,
   not WARNING or NOTE. **Test on both macOS AND Linux.**

8. **Once clean**, rename branch to `r_pkg`, force-push, update
   submodule pointers, commit on the main R package.

9. **Document** which patches were applied, which were dropped, and
   why, in this file.

## Toward eliminating patches: upstream `-DEMBEDDED_INTERFACE`

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

### R-exts §1.2.6 compliance

Per "Writing R Extensions" §1.2.6, when using cmake to build vendored
sources, R's compiler flags (CC, CFLAGS, CXX, CXXFLAGS, CPPFLAGS,
LDFLAGS) must be passed through. Our `build_scip.sh` does this via
environment variables, which cmake picks up. This means R's
`-D_FORTIFY_SOURCE=3` (on Ubuntu) applies to the cmake build too —
GCC then converts `printf` → `__printf_chk` even in error paths.

---

## Patch history

### Upgrade 10.0.1 → 10.0.2 (2026-04-06)

**Upstream tags**: SCIP `v10.0.2`, SoPlex `v8.0.2`, PaPILO `v3.0.0`

Clean 10.0.2 sources build and pass tests but fail `R CMD check`
compiled code checks (stdout/stderr/exit/abort symbols in static libs).

#### Tinycthread patches confirmed dead

With TPI=omp (or TPI=none on macOS), tinycthread is never compiled.
The bulk of our 10.0.1 patch burden was tinycthread-related
(prefixing C11 names to avoid glibc C23 collisions, guarding
includes, etc.). All of this is gone now.

#### scip-src: `bnaras/scip-src` `r_pkg` branch (7 commits on `v10.0.2`)

Commits (in application order):

1. `59a5149` — **Add r_streams.h include for R-compatible output declarations**
   Applied first since other patches depend on it.
   Minor conflict in `src/dejavu/utility.h` (upstream changed `<ostream>` to `<iostream>`).
   Files: `src/dejavu/utility.h`, `src/dejavu/dejavu.cpp`, `src/dejavu/graph.h`,
   `src/dejavu/bfs.h`, `src/cppad/utility/error_handler.hpp` + 12 more cppad headers,
   `src/lpi/lpi_clp.cpp`

2. `9acd9b4` — **R compatibility: replace exit/abort/fprintf/sprintf with R equivalents**
   Bulk replacements in SCIP core C/C++ files.
   Files: `src/scip/message.c`, `src/scip/message_default.c`, `src/scip/misc.c`,
   `src/scip/scipshell.c`, `src/scip/rational.cpp`, `src/scip/cons_nonlinear.c`,
   `src/scip/exprinterpret_cppad.cpp`, `src/xml/xmlparse.c`, `src/nauty/*.c`,
   `src/tclique/tclique_def.h`, `src/xml/xmldef.h` + others (72 files total)

3. `5be9b93` — **Replace direct stdio/abort calls with R API equivalents**
   More replacements in `src/blockmemshell/memory.c`, `src/dijkstra/dijkstra.c`,
   `src/scip/dialog.c`, `src/scip/dialog_default.c`, `src/scip/disp.c`,
   `src/scip/expr.c`, `src/scip/interrupt.c`, `src/scip/matrix.c`,
   `src/scip/nlp.c`, `src/scip/nlpioracle.c`, `src/scip/reader_gms.c`,
   `src/scip/reader_opb.c`, `src/scip/stat.c`, `src/scip/lpi/lpi_spx.cpp`

4. `ba686d0` — **Patch objconshdlr.h: replace fprintf(stdout,...) with Rprintf**
   File: `src/objscip/objconshdlr.h`

5. `ddbd4a2` — **CRAN compliance: fix warnings in vendored sources**
   Compiler warning fixes in dejavu, nauty, lpi_spx, rational.cpp.
   Minor conflict in `src/dejavu/ds.h` and `src/dejavu/utility.h` (resolved).
   Files: `src/dejavu/ds.h`, `src/dejavu/ir.h`, `src/dejavu/utility.h`,
   `src/lpi/lpi_spx.cpp`, `src/nauty/nauty.c`, `src/scip/rational.cpp`,
   `src/scip/pub_message.h`, `src/scip/pub_fileio.h`, `src/scip/scip_message.h`,
   `src/scip/set.h`, `src/scip/stat.h`, `src/scip/presol_milp.cpp`,
   `src/scip/certificate.cpp`, `src/scip/reader_zpl.c`,
   `src/symmetry/compute_symmetry_sassy_nauty.cpp`

6. `f1fb6a9` — **Fix strerror_r variant detection on macOS with _GNU_SOURCE**
   File: `src/scip/misc.c` (strerror_r portability)

7. `6794840` — **Fix printf in tpi_openmp.c for CRAN compliance** (NEW for 10.0.2)
   `printf("err1")` → `Rprintf("err1")` + `#include "r_streams.h"`.
   **This was the Ubuntu `__printf_chk` culprit.** Only compiled when TPI=omp
   (Linux with OpenMP). Invisible on macOS where TPI=none. Found via
   `nm -A libscip.a | grep __printf_chk` on the Ubuntu-built archive.
   File: `src/tpi/tpi_openmp.c`

Not carried forward from 10.0.1 (dead with TPI=omp):

- `0003` — Static `githash.c`. CMake generates this now.
- `0007` — Prefix tinycthread C11 names. Pure tinycthread fix.
- `0009` — Guard tinycthread.h includes. Dead; `tpi_openmp.c` fix extracted above.

#### soplex-src: `bnaras/soplex-src` `r_pkg` branch (4 commits on `v8.0.2`)

Commits (in application order):

1. `a726531` — **R compatibility: redirect std::cerr/std::cout through R I/O**
   Files: `src/soplex/spxout.cpp`, `src/soplex/spxdefines.cpp`,
   `src/soplex/spxdefines.h`, `src/soplex.hpp`, `src/soplexmain.cpp`,
   `src/example.cpp`, `src/soplex_interface.cpp` + ~60 header files
   (replaces `std::cerr`/`std::cout` stream references throughout)

2. `3a7e0b6` — **CRAN compliance: disable fmt string_view, redirect I/O to R**
   Files: `src/soplex/external/fmt/core.h`, `src/soplex/external/fmt/format.h`,
   `src/soplex/spxout.cpp` (major R I/O redirection additions)

3. `574bd9b` — **Add r_streams.h include for R-compatible output declarations**
   Files: `src/soplex/didxset.cpp`, `src/soplex/idxset.cpp`,
   `src/soplex/nameset.cpp`, `src/soplex/spxdefines.cpp`

4. `624a418` — **Fix deprecated literal operator spacing in fmt/format.h**
   Upstream did not fix this in 8.0.2.
   File: `src/soplex/external/fmt/format.h`

Not carried forward from 10.0.1:

- `0003` — Static `git_hash.cpp`. CMake generates this now.

#### papilo-src: `bnaras/papilo-src` `r_pkg` branch (0 commits on `v3.0.0`)

No R-specific patches needed. Clean upstream tag.

### Fallback branches

| Branch | Content |
|--------|---------|
| `r_pkg` | Current (10.0.2 patches) |
| `r_pkg_v1` | Old 10.0.1 patches (9 scip / 5 soplex) |

Main repo tag `pre-10.0.2` points to the last commit before the upgrade.
To recover old patches: `git format-patch master..r_pkg_v1` from within
any submodule.
