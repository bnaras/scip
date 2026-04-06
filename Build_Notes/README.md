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

#### scip-src (7 patches applied)

From Build_Notes (carried forward from 10.0.1):

- `0005` — `r_streams.h` header declaring `Rprintf`/`REprintf`/`r_cout()`/`r_cerr()` wrappers.
  Minor conflict in dejavu/utility.h (upstream changed `<ostream>` to `<iostream>`
  in dejavu 2.1). Applied first since other patches depend on it.
- `0001` — Bulk stdio/abort replacements in SCIP core (message.c, misc.c, etc.)
- `0006` — More stdio/abort replacements (separate commit from 0001).
- `0008` — `objconshdlr.h`: `fprintf(stdout,...)` → `Rprintf`.
- `0002` — Compiler warning fixes in dejavu, nauty, lpi_spx, rational.cpp.
  Minor conflict in dejavu/ds.h and dejavu/utility.h (resolved).
- `0004` — macOS `strerror_r` variant detection with `_GNU_SOURCE`.

New for 10.0.2:

- `tpi_openmp.c` — `printf("err1")` → `Rprintf("err1")` + `#include "r_streams.h"`.
  **This was the Ubuntu `__printf_chk` culprit.** Only compiled when TPI=omp
  (Linux with OpenMP). Invisible on macOS where TPI=none. Found via
  `nm -A libscip.a | grep __printf_chk` on the Ubuntu-built archive.

Dropped (dead with TPI=omp):

- `0003` — Static `githash.c` for non-CMake builds. CMake generates this now.
- `0007` — Prefix tinycthread C11 names. Pure tinycthread fix.
- `0009` — Guard tinycthread.h includes. The `tpi_openmp.c` Rprintf fix
  was buried in this patch but we extracted it as a standalone fix above.

#### soplex-src (4 patches applied)

All carried forward from 10.0.1, applied cleanly:

- `0001` — Redirect `std::cerr`/`std::cout` through R I/O streams.
- `0002` — Disable `fmt` `string_view`, redirect fmt I/O to R.
- `0004` — `r_streams.h` header for R I/O wrappers.
- `0005` — Fix deprecated literal operator spacing in `fmt/format.h`.
  Upstream did not fix this in 8.0.2.

Dropped:

- `0003` — Static `git_hash.cpp`. CMake generates this now.

#### papilo-src

No R-specific patches needed. Clean `v3.0.0` tag used directly.

### Fallback branches

| Branch | Content |
|--------|---------|
| `r_pkg` | Current (10.0.2 patches) |
| `r_pkg_v1` | Old 10.0.1 patches (9 scip / 5 soplex) |

Main repo tag `pre-10.0.2` points to the last commit before the upgrade.

### Recovering old patches if needed

The `r_pkg_v1` branches on the submodule forks still contain the
10.0.1 patches. To export them: `git format-patch master..r_pkg_v1`.
