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

### Upgrade 10.0.2 → 10.1.0 (2026-10-03)

**Upstream tags**: SCIP `v10.1.0` (`c8e5737a84`), SoPlex `v8.1.0`
(`a0061053`), PaPILO `v3.0.2` (`3f1ba692`) — the SCIP Optimization Suite
10.1.0, released 2026-09-18. R package version `1.10.1-1`.

**Branch layout for this upgrade.** Everything was done on new branches
so that the released state stays recoverable:

| Repo | Released 1.10.0-4 state lives on | Upgrade branch |
|------|----------------------------------|----------------|
| `scip` (parent) | `fix-libcxx23-transitive-includes` (`8d12ca8`) | `upgrade/scip-10.1.0` |
| `scip-src` | `fix-libcxx23-transitive-includes` (`2aafcef9b5`) | `r_pkg-10.1.0` |
| `soplex-src` | `fix-libcxx23-transitive-includes` (`a9d8ed31`) | `r_pkg-8.1.0` |
| `papilo-src` | `r_pkg` (`4cbdc327`) | `r_pkg-3.0.2` |

Note that `main` and the `r_pkg` branches were **never fast-forwarded** to
the 1.10.0-4 release (one libc++ commit each in scip-src and soplex-src,
two commits in the parent). The patch series below was therefore exported
from the `fix-libcxx23-transitive-includes` tips, not from `r_pkg`. Copies
of the exported `.patch` files are kept in the new_design repo under
`issues/scip_10.1.0/patches/`. When this upgrade is merged, move `r_pkg`
to the new tips (`r_pkg-*`) and keep the old ones as `r_pkg-10.0.2` /
`r_pkg-8.0.2`; `.gitmodules` still says `branch = r_pkg` and was left alone.

**Upstream API check.** The SCIP 10.1.0 release notes list no deleted or
changed API functions and no changed parameters; the 44 `SCIP*` calls in
`src/scip_wrapper.c` are all unchanged. New in 10.1.0 are cut-generation
helpers, solving-phase queries, IIS accessors and a few parameters, none
used here. Upstream did **not** adopt the libc++ 23 include fixes
(`basevectors.h` still lacks `<istream>`, `multiprecision.hpp` still lacks
`<cstdlib>`), so both patches are carried forward.

**Differential grep for new stdio/exit calls** (step 5 above, run as a set
difference between the patched 10.0.2 tree and the fresh 10.1.0 tree, so
only *new* sites show): SCIP 2 hits, SoPlex 0 hits.

**Tarball-only build break (found by `R CMD check`, invisible to an in-tree
`R CMD INSTALL`).** SCIP 10.1.0 moved `add_subdirectory(doc EXCLUDE_FROM_ALL)`
out of the `if(BUILD_TESTING)` block (changelog 10.0.3: "doc target ... not
available when using -DBUILD_TESTING=OFF"). `.Rbuildignore` strips
`inst/scip/doc`, so the tarball's cmake configure died with
`add_subdirectory given source "doc" which is not an existing directory`.
Fix: `inst/build_scip.sh` now recreates `doc/CMakeLists.txt` as a stub when
the directory is missing, exactly like the existing SoPlex `check/` stub.
`doc/CMakeLists.txt` upstream only defines an optional doxygen target that
nothing else references. **Lesson: always gate on the tarball, never on the
in-tree install** — the two differ by everything in `.Rbuildignore`.

#### scip-src: `bnaras/scip-src` `r_pkg-10.1.0` branch (10 commits on `v10.1.0`)

All 9 patches from 10.0.2 re-applied with `git am --3way`. One conflict:

- `src/scip/scipshell.c` usage string — upstream added a `-t <threads>`
  option to the same `printf` the patch turns into `Rprintf`. Kept the
  upstream text with `Rprintf`.

One new patch:

10. `928a3404ec` — **Fix new bare printf in scipshell.c (SCIP 10.1.0)**
    The error path of the new `-t` option calls `printf()` directly;
    `scipshell.c` is compiled into `libscip`. The other new `printf`, in
    `src/scip/var.c`, is inside the `DEBUGUSES_VARNAME` block, which is
    commented out upstream and never compiled; left untouched.

#### soplex-src: `bnaras/soplex-src` `r_pkg-8.1.0` branch (4 commits on `v8.1.0`)

4 of 5 patches re-applied cleanly. Dropped:

- `624a418` — **Fix deprecated literal operator spacing in fmt/format.h**.
  Fixed upstream in 8.1.0 (`git am` reported "Patch already applied").

#### papilo-src: `bnaras/papilo-src` `r_pkg-3.0.2` branch (0 commits on `v3.0.2`)

Clean upstream tag, still not compiled (`PAPILO:bool=OFF`).

#### `.Rinstignore` replaces the `inst/doc` deletion heuristic (same release)

Lesson carried over from the R `highs` package (its 2026-07-14 `cran-shim`
work). `configure` and `configure.win` used to do
`if test -d inst/doc; then rm -rf inst/scip inst/soplex inst/config; fi`,
inferring "tarball install" from the presence of built vignettes. Two
measured problems: an in-tree install (`R CMD INSTALL .`, `devtools`,
`remotes` without a build step) copied **257 MB** of SCIP/SoPlex source
into the library (tarball install: 10.5 MB); and on a checkout where
`inst/doc` exists (e.g. after `devtools::build_vignettes()`) the same
command would delete the submodule working trees.

Now: top-level `.Rinstignore` with anchored patterns
`^inst/scip/`, `^inst/soplex/`, `^inst/config/`, `^inst/plan/`,
`^inst/build_scip[.]sh$`. R matches these (Perl, case-insensitive) against
the **full recursive paths** under `inst/` (`tools:::.install_packages`),
so they must be anchored — an unanchored `/scip` would also drop
`inst/doc/scip-examples.html`, i.e. the vignette. The `rm -rf` is gone
from both configure scripts.

Companion (also found empirically in highs): the old blanket `rm -rf` was
incidentally removing cmake's generated `build/` trees, whose Makefiles
trip `R CMD check`'s "GNU extensions in Makefiles" WARNING.
`inst/build_scip.sh` now removes `inst/scip/build` and `inst/soplex/build`
itself, after SCIP's library is copied out (SCIP's cmake step needs
SoPlex's build dir for `soplex-config.cmake`).

#### R package changes in the same release

- `scip_control()` gains `presolve_emphasis`, `separating_emphasis`
  (GitHub issue #2, Jeff Hanson / prioritizr) and the global `emphasis`;
  `src/scip_wrapper.c` applies them via `SCIPsetEmphasis`,
  `SCIPsetPresolving`, `SCIPsetHeuristics`, `SCIPsetSeparating`, in that
  order, before the individual `scip_params`.
- Docs regenerated with roxygen2 8.1.0 (which replaces `RoxygenNote` by
  `Config/roxygen2/version` in DESCRIPTION).

#### Verification

| Gate | Result |
|------|--------|
| `R CMD INSTALL --preclean` in-tree, macOS arm64, R 4.6.1 | OK, 3m39s; 36 warnings, all `-Wcast-align` in vendored `nauty/nausparse.c` (pre-existing) |
| tinytest suite on that install | All ok, 115 results |
| Emphasis settings observed in SCIP's log | `presolve_emphasis="off"` → 0 presolve rounds (default 3–11); `separating_emphasis="off"` → no cut-pool restarts; `emphasis="cpsolver"` → 640,919 nodes vs 1 (no LP); identical optimum throughout |
| `R CMD build` + `R CMD check --as-cran` on the tarball, macOS | **Status: OK, 0 NOTEs** (`_R_CHECK_CRAN_INCOMING_REMOTE_=false`); `checking compiled code ... OK`; vignette rebuild OK |
| CRAN clang-23 / libc++ Linux harness (`new_design/issues/c++23`, Fedora 44 x86_64, clang 23.1.0, R-devel r90448, TPI=omp), `R CMD check --as-cran --no-manual` on the same tarball | **Status: 1 NOTE** — `scipopt.org` HTTP 429 (rate limiting, same as the 1.10.0-4 submission); `checking compiled code ... OK` (the `nm` scan, with `tpi_openmp.c` compiled in); tests OK; vignette rebuild OK; 0 compile errors; 9m42s under Rosetta |
| `.Rinstignore` change, tarball path: `R CMD build` + `R CMD check --as-cran` | Status: OK; installed size 10.5 MB (unchanged); "GNU extensions in Makefiles" is INFO only (GNU make is a declared SystemRequirement); `inst/doc/scip-examples.{Rmd,R,html}` present in the installed package |
| `.Rinstignore` change, in-tree path: `R CMD INSTALL --preclean -l <lib> .` from the checkout | installed size **10 MB** (was 257 MB); no `scip/`, `soplex/`, `config/`, `plan/` or `build_scip.sh` in the library; `inst/scip/build` and `inst/soplex/build` removed; `git status` shows only the intended edits |
| **Final tarball (`4be2c4c`, SHA-256 `90efb790…`) on the clang-23 harness rebuilt with R-devel 2026-10-02 r90634** | **Status: 1 NOTE** (`scipopt.org` 429 only); `checking compiled code ... OK`; GNU extensions in Makefiles INFO only; installed size 10.2 MB; tests OK; vignette OK; 0 compile errors; 9m35s. `verify_harness.sh`: all required components present |
| win-builder | not run (user) |

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
| `r_pkg-10.1.0` / `r_pkg-8.1.0` / `r_pkg-3.0.2` | 10.1.0 upgrade (10 scip / 4 soplex / 0 papilo), unmerged |
| `fix-libcxx23-transitive-includes` | Released 1.10.0-4 state (9 scip / 5 soplex) |
| `r_pkg` | 10.0.2 patches minus the libc++ 23 commit (8 scip / 4 soplex) |
| `r_pkg_v1` | Old 10.0.1 patches (9 scip / 5 soplex) |

Main repo tag `pre-10.0.2` points to the last commit before the upgrade.
To recover old patches: `git format-patch master..r_pkg_v1` from within
any submodule.
