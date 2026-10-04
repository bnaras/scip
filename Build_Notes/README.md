# SCIP R Package — Build Notes & Upstream Patch History

## Submodule / Branch Architecture

The R package vendors three upstream libraries as git submodules, each
pointing to our forks. Each fork carries a branch of R-specific patches
on top of the upstream release tag, one branch per upstream version:

| Submodule | Upstream | Our fork | Current branch |
|-----------|----------|----------|----------------|
| `inst/scip` | [scipopt/scip](https://github.com/scipopt/scip) | [bnaras/scip-src](https://github.com/bnaras/scip-src) | `r_pkg-10.1.0` |
| `inst/soplex` | [scipopt/soplex](https://github.com/scipopt/soplex) | [bnaras/soplex-src](https://github.com/bnaras/soplex-src) | `r_pkg-8.1.0` |
| `src/papilo` | [scipopt/papilo](https://github.com/scipopt/papilo) | [bnaras/papilo-src](https://github.com/bnaras/papilo-src) | `r_pkg-3.0.2` |

PaPILO is not compiled (`PAPILO:bool=OFF`) and its fork carries no
patches; the submodule is kept so the tree matches upstream's layout.
`.gitmodules` still says `branch = r_pkg`; the parent repo pins exact
commits, so this only affects `git submodule update --remote`. Older
branches are listed under "Fallback branches" at the end.

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

This is the procedure as actually run for 10.0.2 → 10.1.0. Everything
happens on new branches; nothing on `main` or an existing `r_pkg-*`
branch is rewritten.

1. **Branch the R package**: `git checkout -b upgrade/scip-X.Y.Z` from
   the commit that is on CRAN.

2. **Export the current patch series** from each fork as a safety net
   and as the input to the next step:
   ```
   cd inst/scip      # likewise inst/soplex
   git fetch upstream --tags
   git format-patch vOLD..r_pkg-OLD -o <somewhere outside the repo>/scip-src/
   ```
   The exported `.patch` files are also kept with the release notes
   (for 10.1.0: `new_design/issues/scip_10.1.0/patches/`).

3. **Start a new branch from the new upstream tag** and re-apply in
   order (the `r_streams.h` include patch is first in the series):
   ```
   git checkout -b r_pkg-NEW vNEW
   git am --3way <patches>/*.patch
   ```
   Resolve conflicts, drop patches upstream has absorbed (`git am`
   says "Patch already applied"), and note both in this file.

4. **Differential grep for new bare stdio/exit calls.** Grep the fresh
   tag and the patched old branch with the same pattern and take the set
   difference, so only sites *new* in this release show:
   ```
   grep -rn '[^a-zA-Z_]printf\s*(' src/ --include='*.c' --include='*.cpp' \
     | grep -v '//.*printf' \
     | grep -v 'Rprintf\|snprintf\|sprintf\|fprintf\|vprintf' \
     | grep -v '#define\|while.*FALSE'
   ```
   Pay special attention to `src/tpi/tpi_openmp.c`, compiled only with
   TPI=omp on Linux and therefore invisible on macOS.

5. **Point the submodules at the new tips, build, test, check** from
   the R package. Gate on the **tarball**, never on an in-tree install:
   `.Rbuildignore` strips directories the tarball build has to survive
   without (the 10.1.0 `doc/` break was invisible in-tree).
   ```
   R CMD build scip && R CMD check --as-cran scip_*.tar.gz
   ```
   `checking compiled code ... OK` is the gate that matters. Run it on
   macOS **and** on Linux with TPI=omp; the CRAN clang-23/libc++ clone in
   `new_design/issues/c++23/` (`check_pkg.sh check <tarball>`) is the
   Linux gate. If it reports `__printf_chk` or similar:
   ```
   nm -A src/sciplib/lib/libscip.a | grep '__printf_chk'
   ```
   names the object file to fix.

6. **Push the branches, open a PR against `main`** so CI runs on all
   five platforms. Merge, fast-forward `main`, and move `r_pkg` only
   after CRAN has accepted the release.

7. **Document** in this file: tags, branches, patches applied/dropped
   and why, anything that broke, and the verification table.

## Toward eliminating patches: upstream I/O abstraction

All our patches exist because SCIP/SoPlex assume a standalone
executable context (stdout/stderr/exit are fine). For an embedded
library context (R, Python, etc.), these need to be redirected.
The long-term fix is a compile-time I/O indirection *upstream*, so
that the submodules can point at plain release tags.

### Status of the upstream conversation

| Date | Event |
|------|-------|
| 2026-04-07 | Feeler issue opened on `scipopt/scip` proposing a compile-time I/O abstraction (`scip_io.h`, CMake option). Detailed proposal text and PR plan: `inst/plan/patches_pr_plan.md`. |
| 2026-10-04 | Maintainers replied: "In general we welcome any useful contributions. SCIP already has a message handler system but this does not prevent us from using standard functions in the default handler implementation. So if there is a way to redirect it in a compatible way without invasive impact, this sounds promising." |
| 2026-10-04 | Replied proposing the staged sequence below and asking whether it works for them. **Waiting for a yes before preparing PRs.** |

### What the forks carry today (SCIP 10.1.0 / SoPlex 8.1.0)

Counted from the `r_pkg-10.1.0` and `r_pkg-8.1.0` patch series
(`git format-patch v10.1.0..r_pkg-10.1.0`, same for SoPlex):

| Fork | Commits | I/O for CRAN | Portability / warnings |
|------|---------|--------------|------------------------|
| scip-src | 10 | 6 — about 125 printf-family calls, 50 `exit`/`abort`, 20 `std::cout` across ~35 files; plus `objconshdlr.h`, `tpi_openmp.c`, `scipshell.c`, and the `r_streams.h` include | 4 one-hunk fixes: cppad pragma/`%zu`/uninitialized warnings, `strerror_r` on macOS, `(void)` prototypes in `tpi_openmp.c`, `<cstdlib>` in `multiprecision.hpp` |
| soplex-src | 4 | 3 — about 105 `std::cerr` and 60 `std::cout` across ~60 template headers (almost all inside `SPX_MSG_ERROR(...)` arguments), the `spxout.cpp` redirect, the `r_streams.h` include | 1: `<istream>` for libc++ 23 |

Every I/O site is a mechanical token swap (`printf` → `Rprintf`,
`fprintf(stderr, ...)` → `REprintf`, `exit`/`abort` → `Rf_error`,
`std::cout`/`std::cerr` → `r_cout()`/`r_cerr()`). The portability
hunks never conflict at a bump; all the re-patching cost is the I/O
sites.

### What "compatible, without invasive impact" rules in and out

- **Default build must be unchanged.** The macros expand to the
  original libc tokens unless the embedder opts in, so the
  preprocessed default sources are byte-identical. Worth demonstrating
  in the PR (`-E` diff) rather than asserting.
- **No public header or ABI change.** This has a concrete consequence
  for the message handler layer. The handler callbacks
  (`SCIP_DECL_MESSAGEINFO` etc.) receive a `FILE* file`, and SCIP's
  core passes `stdout`/`stderr` as *values* and compares against them
  (`message.c`: `file == stdout`). Our fork replaces those with `NULL`
  meaning "console" — fine for us, but it changes a public contract and
  cannot go upstream as is. The upstream shape has to keep the
  contract: `SCIP_IO_STDOUT`/`SCIP_IO_STDERR` tokens that default to
  `stdout`/`stderr`, and a default-handler sink (`logMessage`,
  `errorPrintingDefault`) that dispatches on them. In the custom
  configuration the embedder defines them as sentinel `FILE*` values
  that are compared but never dereferenced (the same device the R
  `highs` package's compliance shim uses).
- **Small PRs.** The April plan's single "migrate everything" PR
  (~150 sites, including vendored nauty/cppad/dejavu) is what the
  maintainers will read as invasive. Cut it along the layers below.

### Staged sequence (proposed to the maintainers 2026-10-04)

0. **Goodwill portability PRs, all standalone bug fixes:** `strerror_r`
   on macOS (`misc.c`), `(void)` prototypes in `tpi_openmp.c`,
   `<cstdlib>` in `multiprecision.hpp`, `<istream>` in SoPlex
   `basevectors.h`/`mpsinput.cpp`, the `%zu`/uninitialized fixes in
   cppad and nauty. Four fork commits disappear outright. The cppad
   *pragma comment-outs* are CRAN-specific and stay as an R patch.
1. **`scip/scip_io.h` + CMake option + the default message handler**
   (`message.c`, `message_default.c`): the layer the maintainers named,
   about 50 lines, on code they own. Establishes the pattern.
2. **Handler-less SCIP-owned sub-libraries, one PR each:**
   `blockmemshell/memory.c`, `xml/xmlparse.c`, `dijkstra/dijkstra.c`,
   `tpi/tpi_openmp.c`, the `exit()` paths in `lpi/lpi_spx.cpp`,
   `objscip/objconshdlr.h`, the stragglers in `src/scip/*.c` (dialog,
   disp, expr, interrupt, matrix, nlp, nlpioracle, rational.cpp,
   reader_gms, reader_opb, scipshell, stat, cons_nonlinear), and the
   `SCIPdebugMessage`/`SCIPstatisticPrintf` macros in `pub_message.h`.
   None of the standalone sub-libraries include `scip/def.h`, so each
   needs its own `#include "scip/scip_io.h"`.
3. **Vendored nauty, cppad, dejavu: ask first.** They may prefer vendored
   code untouched. If so, those sites stay as R patches (few, stable)
   or are absorbed by the downstream shim below.
4. **SoPlex, separate repo, separate issue.** The problem is `std::cerr`
   named inside `SPX_MSG_ERROR(...)` arguments in template headers. The
   non-invasive fix is for the macro (and `SPxOut`'s default streams in
   `spxout.cpp`) to supply the stream, so call sites stop naming the
   global. Plus the `FMT_USE_STRING_VIEW` define as a build option.

Design point to settle before writing the header: whether the
embedder's `exit`/`abort` replacement may be `noreturn`. Ours is (it
long-jumps via `Rf_error`). If SCIP code after an `exit()` relies on
nothing following, the default macro should carry `noreturn` too, or
compiler warnings differ between configurations.

### Downstream complement: force-included shim + symbol gate

Independent of upstream progress, the R `highs` package's mechanism
(branch `cran-shim`, 2026-07) applies here for the C side:
`build_scip.sh` already exports `CFLAGS`/`CXXFLAGS` into both cmake
runs, so one force-included header (`-include r_shim.h`) with
function-like macros for `printf`, `fprintf`, `vfprintf`, `puts`,
`putchar`, `fputs`, `fflush`, `exit`, `abort` and sentinel
`stdout`/`stderr` covers every C translation unit by construction,
including the next bare `printf("err1")` nobody noticed. A post-build
`nm` gate over `libscip.a`/`libsoplex.a` (and the final `.so`, for LTO)
replaces the manual grep in step 5 of the upgrade workflow above.

Limits: `std::cout`/`std::cerr` are qualified names and not macro
reachable (declaring into `namespace std` is undefined behavior), so
SoPlex and the ~20 C++ sites in SCIP still need upstream or patches;
the two `sprintf` sites stay hand-patched. The shim would retire the
five heavy SCIP I/O commits on its own.

Decision pending (user): build the `nm` gate now (cheap, catches drift
either way) and the shim after the maintainers answer, or wait for
upstream entirely.

### What stays as an R patch regardless

- cppad diagnostic-pragma comment-outs (CRAN flags the pragmas; not an
  upstream concern).
- Anything the maintainers decline.

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
`<cstdlib>`), so both patches are carried forward. They were added for
1.10.0-4 (2026-08-27) when CRAN's `r-devel-linux-x86_64-fedora-clang`
moved to LLVM 23; the CRAN clone used to reproduce and verify that lives
in `new_design/issues/c++23/` and is the Linux gate in the workflow above.

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
| `.Rinstignore` change, tarball path: `R CMD build` + `R CMD check --as-cran` | Status: OK; installed size 10.5 MB (unchanged); "GNU extensions in Makefiles" is INFO only (GNU make is a declared SystemRequirement); `inst/doc/scip-examples.{Rmd,R,html}` present in the installed package |
| `.Rinstignore` change, in-tree path: `R CMD INSTALL --preclean -l <lib> .` from the checkout | installed size **10 MB** (was 257 MB); no `scip/`, `soplex/`, `config/`, `plan/` or `build_scip.sh` in the library; `inst/scip/build` and `inst/soplex/build` removed; `git status` shows only the intended edits |
| **Final tarball (`4be2c4c`, SHA-256 `90efb790…`) on the clang-23 harness rebuilt with R-devel 2026-10-02 r90634** | **Status: 1 NOTE** (`scipopt.org` 429 only); `checking compiled code ... OK`; GNU extensions in Makefiles INFO only; installed size 10.2 MB; tests OK; vignette OK; 0 compile errors; 9m35s. `verify_harness.sh`: all required components present |
| win-builder | not run (user) |

### Fallback branches

| Branch (in each fork) | Content |
|-----------------------|---------|
| `r_pkg-10.1.0` / `r_pkg-8.1.0` / `r_pkg-3.0.2` | This upgrade (10 scip / 4 soplex / 0 papilo), unmerged |
| `fix-libcxx23-transitive-includes` | The state on CRAN as 1.10.0-4 (9 scip / 5 soplex) |

Older branches (`r_pkg`, `r_pkg_v1`) and the parent tag `pre-10.0.2`
predate the libc++ 23 fix and the 10.1.0 upgrade; the earlier patch
history is in `git log` on those branches and in `NEWS.md`.
