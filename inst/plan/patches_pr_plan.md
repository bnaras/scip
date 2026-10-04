# Plan: Upstream PRs to Eliminate SCIP/SoPlex Fork Patches

## Status (2026-10-04) — read this first

- **2026-04-07** feeler issue opened on `scipopt/scip`.
- **2026-10-04** maintainers replied: contributions welcome; they note the
  *default message handler implementation* still uses standard functions;
  a redirect "in a compatible way without invasive impact" sounds promising.
- **2026-10-04** we replied proposing the staged sequence below. **Waiting for
  a yes before preparing any PR branch.**
- Fork state has moved on since this plan was written: the forks are now
  `r_pkg-10.1.0` (10 commits) and `r_pkg-8.1.0` (4 commits). The SoPlex fmt
  literal-operator fix (PR C below) is upstream in 8.1.0 and is no longer
  needed. New since April: `<cstdlib>` in `multiprecision.hpp`, `<istream>` in
  SoPlex `basevectors.h`/`mpsinput.cpp` (libc++ 23), `(void)` prototypes in
  `tpi_openmp.c`, and one more bare `printf` in `scipshell.c` (10.1.0).
  Current per-commit classification: `Build_Notes/README.md`, section
  "Toward eliminating patches".

### Revised sequencing (supersedes "PR Sequencing Strategy" below)

The maintainers' constraint rules out PR E as drafted (one ~150-site
migration including vendored code). Cut along layers instead:

| Tier | Content | Notes |
|------|---------|-------|
| 0 | Goodwill portability PRs: `strerror_r` (`misc.c`), `(void)` prototypes (`tpi_openmp.c`), `<cstdlib>` (`multiprecision.hpp`), SoPlex `<istream>` (`basevectors.h`, `mpsinput.cpp`), `%zu`/uninitialized fixes in cppad and nauty | Standalone bug fixes; send immediately. The cppad pragma comment-outs are CRAN-specific and stay as an R patch. |
| 1 | `scip/scip_io.h` + CMake option + default message handler (`message.c`, `message_default.c`) | The layer the maintainers named; ~50 lines on code they own. **Must keep the public `FILE* file` callback contract** — see below. |
| 2 | Handler-less SCIP-owned sub-libraries, one PR each: `blockmemshell/memory.c`, `xml/xmlparse.c`, `dijkstra/dijkstra.c`, `tpi/tpi_openmp.c`, `lpi/lpi_spx.cpp` exit paths, `objscip/objconshdlr.h`, `src/scip/*.c` stragglers, `pub_message.h` debug macros | Each sub-library needs its own `#include "scip/scip_io.h"` (none include `scip/def.h`). |
| 3 | Vendored nauty, cppad, dejavu | Ask first; they may prefer vendored code untouched. Fallback: keep as R patches or absorb with the downstream shim. |
| 4 | SoPlex (separate repo/issue): `SPX_MSG_ERROR` and `SPxOut` default streams supply the stream so call sites stop naming `std::cerr`/`std::cout`; `FMT_USE_STRING_VIEW` as a build option | Only layer with no downstream workaround (C++ streams are not macro-reachable). |

**The message handler contract.** The design below (and our fork's
`message.c` patch) passes `NULL` for "console" where SCIP passes `stdout`/
`stderr` as values and compares against them. That changes what third-party
handlers receive and cannot go upstream. Upstream shape: `SCIP_IO_STDOUT`/
`SCIP_IO_STDERR` tokens defaulting to `stdout`/`stderr`; `logMessage` and
`errorPrintingDefault` dispatch on them; in custom mode the embedder defines
them as sentinel `FILE*` values that are compared, never dereferenced.

**Open design point:** whether the embedder's `SCIP_IO_EXIT`/`SCIP_IO_ABORT`
may be `noreturn` (ours long-jumps via `Rf_error`). If so, the default should
carry `noreturn` too, or warnings differ between configurations.

**Downstream complement (independent of upstream):** a force-included shim
header plus a post-build `nm` gate in `build_scip.sh`, the R `highs` package's
`cran-shim` mechanism. Covers every C token site by construction; does not
reach `std::cout`/`std::cerr`. Pending user decision whether to build it now
or wait for upstream.

The sections below are the April 2026 design and remain the source for the
header text, the CMake wiring, and the PR descriptions.

## Context

The R package `scip` at `~/GitHub/scip` vendors SCIP, SoPlex, and PaPILO as git submodules. CRAN forbids compiled code from calling `printf`, `fprintf(stderr,...)`, `exit()`, `abort()`, `std::cout`, `std::cerr`. Currently we maintain **7 SCIP patches + 4 SoPlex patches** on forked `r_pkg` branches, touching ~298 locations across ~96 files. Every upstream release requires re-applying these patches — a fragile, error-prone process (the `tpi_openmp.c` printf that's invisible on macOS but fails on Ubuntu being the poster child).

The goal: propose upstream PRs that add a **generic compile-time I/O abstraction** so that ANY embedder (R, Python, Julia, WASM) can redirect output and error handling without source patches.

## Analysis: What the 11 Patches Actually Do

### Patch Categories

| Category | SCIP files | SoPlex files | Macro-abstractable? |
|----------|-----------|-------------|-------------------|
| `printf(...)` → `Rprintf(...)` | ~14 locations | ~30 | YES |
| `fprintf(stderr,...)` → `REprintf(...)` | ~19 | ~10 | YES |
| `exit(code)` → `Rf_error(...)` | ~23 | 0 | YES |
| `abort()` → `Rf_error(...)` | ~6 | 0 | YES |
| `std::cout <<` → `r_cout() <<` | 0 | ~80 | YES |
| `std::cerr <<` → `r_cerr() <<` | 0 | ~100 | YES |
| `fflush(stdout)` → no-op | ~2 | 0 | YES |
| `fputs(msg, file)` → `Rprintf/REprintf` | ~5 (message_default.c) | 0 | NO (see below) |
| `format(printf,...)` → `format(__printf__,...)` | 7 attrs | 0 | Separate fix |
| Compiler warning fixes | ~15 files | 2 files | Separate fix |
| `strerror_r` variant detection | 1 file | 0 | Separate fix |

### Two Distinct Layers of Output in SCIP

**Layer 1 — Message Handler (already abstracted):** SCIP has a sophisticated `SCIP_MESSAGEHDLR` callback system. `SCIPmessagePrintInfo()`, `SCIPwarningMessage()`, etc. route through user-installed handlers. R already installs custom handlers via `SCIPmessagehdlrCreate()`. PySCIPOpt does the same. **This layer needs no upstream change.**

**Layer 2 — Direct I/O in low-level subsystems (NOT abstracted):** Code that operates below or outside a SCIP instance uses bare `printf`/`exit`/`abort`. This is where ALL our patches live:

- `blockmemshell/memory.c` — memory allocator (no SCIP instance available)
- `dijkstra/dijkstra.c` — standalone graph algorithm
- `tclique/tclique_def.h` — standalone graph algorithm
- `xml/xmlparse.c`, `xml/xmldef.h` — standalone XML parser
- `nauty/*.c` — vendored graph automorphism library
- `dejavu/*.cpp` — vendored graph library
- `tpi/tpi_openmp.c` — thread pool interface
- `lpi/lpi_spx.cpp` — LP interface (`exit()` in CPLEX check macros)
- `objscip/objconshdlr.h` — C++ wrapper (`fprintf(stdout,...)`)
- `pub_message.h` — debug/statistic macros (`SCIPdebugMessage` expands to bare `printf`)
- Various `src/scip/*.c` — dialog, display, interrupt, matrix, etc.

## Proposed Solution

### Core Idea: `scip_io.h` / `spx_io.h` — Compile-Time I/O Macro Abstraction

A single new header per project that provides macros defaulting to standard C/C++ I/O. When `-DSCIP_CUSTOM_IO` is defined at compile time, the macros are supplied by an embedder-provided header instead.

**Design principles:**
1. **Zero overhead in default mode** — macros expand to the same code as today
2. **Compile-time, not runtime** — critical for memory allocator performance
3. **Generic** — not R-specific, not Python-specific
4. **Backward-compatible** — standalone builds are completely unchanged
5. **Minimal invasion** — mechanical find-and-replace in source files

### SCIP: `src/scip/scip_io.h`

```c
#ifndef SCIP_IO_H
#define SCIP_IO_H

/**@file   scip_io.h
 * @brief  Portable I/O abstraction for embedded builds
 *
 * Low-level SCIP subsystems (memory allocator, graph algorithms,
 * vendored libraries) use direct printf/exit/abort calls.
 * When SCIP is embedded in another system (R, Python, WASM, etc.),
 * these may be forbidden or inappropriate.
 *
 * This header provides macros that default to standard C I/O but
 * can be overridden by defining SCIP_CUSTOM_IO at compile time.
 * The embedder must then provide <scip_custom_io.h> on the include
 * path, defining all SCIP_IO_* macros.
 *
 * High-level SCIP output should continue to use the message handler
 * API (SCIPmessagePrintInfo, SCIPwarningMessage, etc.).
 * This header is for code that operates BELOW or OUTSIDE a SCIP
 * instance and cannot access a message handler.
 *
 * Required macros in <scip_custom_io.h>:
 *   SCIP_IO_PRINTF(fmt, ...)   — stdout output  (replaces printf)
 *   SCIP_IO_EPRINTF(fmt, ...)  — stderr output  (replaces fprintf(stderr,...))
 *   SCIP_IO_EXIT(code)         — fatal exit      (replaces exit, must not return)
 *   SCIP_IO_ABORT()            — fatal abort     (replaces abort, must not return)
 *   SCIP_IO_FLUSH()            — flush stdout    (replaces fflush(stdout))
 */

#ifdef SCIP_CUSTOM_IO
#include <scip_custom_io.h>
#else

#include <stdio.h>
#include <stdlib.h>

#define SCIP_IO_PRINTF(...)    printf(__VA_ARGS__)
#define SCIP_IO_EPRINTF(...)   fprintf(stderr, __VA_ARGS__)
#define SCIP_IO_EXIT(code)     exit(code)
#define SCIP_IO_ABORT()        abort()
#define SCIP_IO_FLUSH()        fflush(stdout)

#endif /* SCIP_CUSTOM_IO */
#endif /* SCIP_IO_H */
```

**R embedder would provide `scip_custom_io.h`:**

```c
#ifndef SCIP_CUSTOM_IO_H
#define SCIP_CUSTOM_IO_H

#include <R_ext/Print.h>
#include <R_ext/Error.h>

#define SCIP_IO_PRINTF(...)    Rprintf(__VA_ARGS__)
#define SCIP_IO_EPRINTF(...)   REprintf(__VA_ARGS__)
#define SCIP_IO_EXIT(code)     Rf_error("SCIP exit with code %d", code)
#define SCIP_IO_ABORT()        Rf_error("SCIP internal error (abort)")
#define SCIP_IO_FLUSH()        /* no-op in R */

#endif
```

**Python embedder would provide:**
```c
#define SCIP_IO_PRINTF(...)    PySys_WriteStdout(__VA_ARGS__)
#define SCIP_IO_EPRINTF(...)   PySys_WriteStderr(__VA_ARGS__)
#define SCIP_IO_EXIT(code)     /* raise SystemExit via C-API */
#define SCIP_IO_ABORT()        /* raise RuntimeError via C-API */
#define SCIP_IO_FLUSH()        /* no-op or PySys_FlushStdout() */
```

### Source Migration (SCIP)

Replace all direct calls with macros. The changes are mechanical:

| Before | After |
|--------|-------|
| `printf(fmt, ...)` | `SCIP_IO_PRINTF(fmt, ...)` |
| `fprintf(stderr, fmt, ...)` | `SCIP_IO_EPRINTF(fmt, ...)` |
| `exit(1)` | `SCIP_IO_EXIT(1)` |
| `abort()` | `SCIP_IO_ABORT()` |
| `fflush(stdout)` | `SCIP_IO_FLUSH()` |

**In `pub_message.h`** — the debug/statistic macros:
```c
/* Before */
#define SCIPdebugMessage   printf("[%s:%d] debug: ", __FILENAME__, __LINE__), printf
#define SCIPdebugPrintf    printf
#define SCIPstatisticMessage  printf("[%s:%d] statistic: ", ...), printf
#define SCIPstatisticPrintf   printf

/* After */
#define SCIPdebugMessage   SCIP_IO_PRINTF("[%s:%d] debug: ", __FILENAME__, __LINE__), SCIP_IO_PRINTF
#define SCIPdebugPrintf    SCIP_IO_PRINTF
#define SCIPstatisticMessage  SCIP_IO_PRINTF("[%s:%d] statistic: ", ...), SCIP_IO_PRINTF
#define SCIPstatisticPrintf   SCIP_IO_PRINTF
```

**In `blockmemshell/memory.c`** — the fallback macros:
```c
/* Before (when SCIPdebugMessage not defined) */
#define debugMessage   while( FALSE ) printf
#define errorMessage   printf
#define printInfo      printf

/* After */
#include "scip/scip_io.h"
#define debugMessage   while( FALSE ) SCIP_IO_PRINTF
#define errorMessage   SCIP_IO_PRINTF
#define printInfo      SCIP_IO_PRINTF
```

**Vendored libraries (nauty, dejavu):**
```c
/* nauty/nautil.c — Before */
fprintf(ERRFILE, "Error: WORDSIZE mismatch\n");
exit(1);

/* After */
#include "scip/scip_io.h"
SCIP_IO_EPRINTF("Error: WORDSIZE mismatch\n");
SCIP_IO_EXIT(1);
```

### CMake Integration (SCIP)

```cmake
# In CMakeLists.txt, near other options (line ~100):
option(CUSTOMIO "Use custom I/O for embedded builds (R, Python, etc.)" OFF)

# Later, when setting up targets:
if(CUSTOMIO)
    target_compile_definitions(libscip PRIVATE SCIP_CUSTOM_IO)
    # Embedder must add their header's directory to the include path
    # via CMAKE_INCLUDE_PATH or target_include_directories()
endif()
```

### SoPlex: `src/soplex/spx_io.h`

SoPlex needs both C-level macros (for any printf/exit) AND C++ stream redirection:

```cpp
#ifndef SPX_IO_H
#define SPX_IO_H

/**@file   spx_io.h
 * @brief  Portable I/O abstraction for embedded SoPlex builds
 *
 * When SOPLEX_CUSTOM_IO is defined, the embedder provides
 * <soplex_custom_io.h> with stream and function replacements.
 */

#ifdef SOPLEX_CUSTOM_IO
#include <soplex_custom_io.h>
#else

#include <iostream>

/** @brief stdout stream (default: std::cout) */
#define SPX_IO_COUT  std::cout

/** @brief stderr stream (default: std::cerr) */
#define SPX_IO_CERR  std::cerr

#endif /* SOPLEX_CUSTOM_IO */
#endif /* SPX_IO_H */
```

**R embedder provides `soplex_custom_io.h`:**
```cpp
#ifndef SOPLEX_CUSTOM_IO_H
#define SOPLEX_CUSTOM_IO_H

#include <ostream>

// Defined in r_streams.cpp — custom ostream backed by RStreamBuf
std::ostream& r_cout();
std::ostream& r_cerr();

#define SPX_IO_COUT  r_cout()
#define SPX_IO_CERR  r_cerr()

#endif
```

### Source Migration (SoPlex)

All ~180 replacements become:

| Before | After |
|--------|-------|
| `std::cout << ...` | `SPX_IO_COUT << ...` |
| `std::cerr << ...` | `SPX_IO_CERR << ...` |

**In `spxout.cpp`** — default stream initialization:
```cpp
// Before
m_streams[VERB_ERROR] = m_streams[VERB_WARNING] = &std::cerr;
for (int i = VERB_DEBUG; i <= VERB_INFO3; ++i)
    m_streams[i] = &std::cout;

// After
m_streams[VERB_ERROR] = m_streams[VERB_WARNING] = &SPX_IO_CERR;
for (int i = VERB_DEBUG; i <= VERB_INFO3; ++i)
    m_streams[i] = &SPX_IO_COUT;
```

Note: `SPX_IO_COUT`/`SPX_IO_CERR` must evaluate to `std::ostream&` since they're used as `&SPX_IO_COUT` (address-of). This works because both `std::cout` and `r_cout()` return `std::ostream&`.

**In `spxdefines.h`** — ASSERT_WARN macro:
```cpp
// Before
std::cerr << prefix << " failed assertion..."

// After
SPX_IO_CERR << prefix << " failed assertion..."
```

### CMake Integration (SoPlex)

```cmake
option(CUSTOMIO "Use custom I/O for embedded builds" OFF)

if(CUSTOMIO)
    target_compile_definitions(libsoplex PRIVATE SOPLEX_CUSTOM_IO)
endif()
```

## PR Sequencing Strategy (April 2026 — superseded by "Revised sequencing" above)

Submit in this order — small fixes first to build credibility, then the main proposal:

### Phase 1: Small Bug Fix PRs (low risk, builds goodwill)

**PR A — SCIP: `format(printf,...)` → `format(__printf__,...)`**
- 7 attribute changes in `pub_message.h`, `scip_message.h`, etc.
- Fixes real GCC warning when `_FORTIFY_SOURCE` is enabled
- Non-controversial portability improvement
- Affects: `src/scip/pub_message.h`, `src/scip/scip_message.h`, `src/scip/pub_fileio.h`, `src/scip/set.h`, `src/scip/stat.h`

**PR B — SCIP: NULL guard in `message_default.c:logMessage()`**
- `fputs(msg, NULL)` segfaults if file is NULL
- Add `if (file != NULL)` guard
- Genuine defensive bug fix, not R-specific
- Affects: `src/scip/message_default.c`

**PR C — SoPlex: Fix deprecated literal operator spacing in fmt**
- `""_a` → `"" _a` in `external/fmt/format.h`
- Fixes C++23 deprecation warning
- Trivial, non-controversial
- Affects: `src/soplex/external/fmt/format.h`

**PR D — SCIP: Fix `strerror_r` variant detection on macOS**
- `_GNU_SOURCE` affects which variant is selected
- Platform portability fix
- Affects: `src/scip/misc.c`

### Phase 2: Main I/O Abstraction PRs

**PR E — SCIP: Add portable I/O abstraction (`scip_io.h`)**
- New file: `src/scip/scip_io.h`
- CMake option: `CUSTOMIO`
- Migrate all direct printf/fprintf(stderr)/exit/abort calls (~50+ locations)
- Update debug/statistic macros in `pub_message.h`
- Includes vendored code: nauty, dejavu, dijkstra, tclique, xml, blockmemshell, tpi, lpi, objscip
- Does NOT change message handler subsystem (message.c, message_default.c)

**PR F — SoPlex: Add portable I/O abstraction (`spx_io.h`)**
- New file: `src/soplex/spx_io.h`
- CMake option: `CUSTOMIO`
- Migrate all std::cout/std::cerr references (~180+ locations)
- Update SPxOut default stream initialization

### Phase 3: What This Eliminates from the R Package

After upstream merges PRs E and F, the R package's patch burden drops from **11 commits / ~298 locations** to:

| Current patch | Status after upstream |
|---|---|
| r_streams.h includes (SCIP commit 1) | **ELIMINATED** — handled by scip_io.h |
| exit/abort/fprintf replacements (SCIP commits 2-3) | **ELIMINATED** — handled by scip_io.h |
| objconshdlr.h fprintf fix (SCIP commit 4) | **ELIMINATED** — handled by scip_io.h |
| Compiler warning fixes (SCIP commit 5) | **ELIMINATED** (if PR phase 1 lands) |
| strerror_r fix (SCIP commit 6) | **ELIMINATED** (if PR D lands) |
| tpi_openmp.c printf (SCIP commit 7) | **ELIMINATED** — handled by scip_io.h |
| SoPlex std::cout/cerr redirect (SoPlex commits 1-2) | **ELIMINATED** — handled by spx_io.h |
| SoPlex r_streams.h includes (SoPlex commit 3) | **ELIMINATED** — handled by spx_io.h |
| SoPlex fmt literal fix (SoPlex commit 4) | **ELIMINATED** (if PR C lands) |

**Result: Zero fork patches needed.** The R package would:
1. Build SCIP with `-DCUSTOMIO=ON` + include path to `scip_custom_io.h`
2. Build SoPlex with `-DCUSTOMIO=ON` + include path to `soplex_custom_io.h`
3. Provide 2 small header files + `r_streams.cpp` (already have these)
4. Point submodules at upstream tags directly (no `r_pkg` branch)

## What the R Package Changes Would Look Like

### `inst/config/scip_custom_io.h` (new, replaces r_streams.h for SCIP)

```c
#ifndef SCIP_CUSTOM_IO_H
#define SCIP_CUSTOM_IO_H
#include <R_ext/Print.h>
#include <R_ext/Error.h>
#define SCIP_IO_PRINTF(...)    Rprintf(__VA_ARGS__)
#define SCIP_IO_EPRINTF(...)   REprintf(__VA_ARGS__)
#define SCIP_IO_EXIT(code)     Rf_error("SCIP exit with code %d", code)
#define SCIP_IO_ABORT()        Rf_error("SCIP internal error (abort)")
#define SCIP_IO_FLUSH()        /* no-op */
#endif
```

### `inst/config/soplex_custom_io.h` (new, replaces r_streams.h for SoPlex)

```cpp
#ifndef SOPLEX_CUSTOM_IO_H
#define SOPLEX_CUSTOM_IO_H
#include <ostream>
std::ostream& r_cout();
std::ostream& r_cerr();
#define SPX_IO_COUT  r_cout()
#define SPX_IO_CERR  r_cerr()
#endif
```

### `inst/build_scip.sh` changes

```bash
# SoPlex build — add CUSTOMIO
cmake ... -DCUSTOMIO:bool=ON ...

# SCIP build — add CUSTOMIO
cmake ... -DCUSTOMIO:bool=ON ...

# Include path already has -I${CONFIG_DIR}, so the custom headers are found
```

### Deleted from R package

- All `r_pkg` branches in fork repos → submodules point to upstream tags
- `r_streams.h` mostly unchanged (still needed for `r_cout()`/`r_cerr()` C++ declarations and the SoPlex custom header)
- `r_streams.cpp` unchanged (still needed for RStreamBuf implementation)
- No more `git format-patch` / `git am` upgrade workflow

## Arguments for Upstream Acceptance

1. **Benefits multiple downstream projects** — R, Python (PySCIPOpt), Julia, WASM targets all face the same issue. PySCIPOpt uses runtime message handlers for high-level output, but low-level printf/exit remain problematic for any embedding.

2. **Zero impact on existing builds** — default behavior is identical to today. The macros expand to the same `printf`/`exit`/`abort` calls. Only activated when embedder opts in via `-DCUSTOMIO=ON`.

3. **Follows SCIP's own pattern** — `pub_message.h` already defines macros (`SCIPdebugMessage`, `SCIPstatisticMessage`) that wrap `printf`. Extending this pattern to ALL low-level output is natural.

4. **Mechanical, reviewable change** — every replacement is a trivial `printf` → `SCIP_IO_PRINTF` substitution. No behavioral changes, no new logic, no architectural changes.

5. **Reduces maintenance burden for SCIP team** — currently, every downstream embedder independently patches the same files. When SCIP adds a new `printf` in a release (e.g., `tpi_openmp.c` in 10.0.2), every embedder has to discover and fix it. With the abstraction, new code naturally uses the macros.

6. **Precedent in similar projects** — HiGHS provides callback-based output. Clarabel/Rust has trait-based output. SQLite has `SQLITE_OMIT_*` compile flags. The macro approach is the lightest-weight option.

7. **Small, self-contained PR** — one new header file + mechanical replacements. No changes to SCIP's algorithms, data structures, or public API.

## Testing & Verification

### For the upstream PRs

1. **Default build must be unchanged:**
   ```bash
   cmake -B build && cmake --build build
   # All SCIP tests must pass identically
   ```

2. **CUSTOMIO build with trivial header:**
   ```bash
   # Create test_io.h that just wraps back to standard I/O with a marker:
   echo '#define SCIP_IO_PRINTF(...) printf("[CUSTOM] " __VA_ARGS__)' > test_custom_io.h
   # ... (other macros)
   cmake -B build -DCUSTOMIO=ON -DCMAKE_INCLUDE_PATH=. && cmake --build build
   # Verify output is prefixed with [CUSTOM]
   ```

3. **R package build:**
   ```bash
   cd ~/GitHub/scip
   # Switch submodules to upstream+PR branches
   R CMD build scip && R CMD check scip_*.tar.gz --no-manual
   # Must pass: "checking compiled code ... OK"
   # Must pass on BOTH macOS (TPI=none) AND Linux (TPI=omp)
   ```

### For the R package after upstream merges

1. `R CMD build scip && R CMD check scip_*.tar.gz --as-cran` — clean
2. `nm -A src/sciplib/lib/libscip.a | grep -E 'printf|exit|abort'` — no forbidden symbols
3. Same check on `libsoplex.a`
4. Run full test suite
5. Test on both macOS and Ubuntu (the TPI=omp difference)

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Upstream rejects the approach | Phase 1 PRs build goodwill first; proposal cites multiple downstream beneficiaries |
| Upstream prefers callback API over macros | Offer both: macros for low-level, callbacks exist for high-level. They serve different layers |
| New upstream code uses bare `printf` in future | CI check: `grep -rn '[^A-Z_]printf\s*(' src/ \| grep -v SCIP_IO_PRINTF` catches violations |
| Naming conflicts (`SCIP_IO_PRINTF` clashes) | Prefix is project-specific (`SCIP_IO_`), unlikely to clash |
| `&SPX_IO_COUT` address-of requirement | Documented: macro must evaluate to `std::ostream&` lvalue |
| Macro expansion breaks format-string checking | GCC checks the expanded call's format attribute (works with Rprintf, which has the attribute) |

## Files to Create/Modify

### Upstream SCIP PR
- **NEW**: `src/scip/scip_io.h`
- **MODIFY**: `CMakeLists.txt` (add CUSTOMIO option)
- **MODIFY**: `src/scip/pub_message.h` (debug/statistic macros)
- **MODIFY**: `src/blockmemshell/memory.c`
- **MODIFY**: `src/dijkstra/dijkstra.c`
- **MODIFY**: `src/tclique/tclique_def.h`
- **MODIFY**: `src/xml/xmlparse.c`, `src/xml/xmldef.h`
- **MODIFY**: `src/nauty/nautil.c`, `src/nauty/nausparse.c`, `src/nauty/nauty.c`, `src/nauty/schreier.c`
- **MODIFY**: `src/dejavu/utility.h`, `src/dejavu/dejavu.cpp`, `src/dejavu/graph.h`, `src/dejavu/bfs.h`
- **MODIFY**: `src/tpi/tpi_openmp.c`
- **MODIFY**: `src/lpi/lpi_spx.cpp`
- **MODIFY**: `src/objscip/objconshdlr.h`
- **MODIFY**: `src/scip/dialog.c`, `src/scip/dialog_default.c`
- **MODIFY**: `src/scip/disp.c`, `src/scip/expr.c`, `src/scip/interrupt.c`
- **MODIFY**: `src/scip/matrix.c`, `src/scip/stat.c`
- **MODIFY**: `src/scip/nlp.c`, `src/scip/nlpioracle.c`
- **MODIFY**: `src/scip/reader_gms.c`, `src/scip/reader_opb.c`
- **MODIFY**: `src/scip/rational.cpp`, `src/scip/scipshell.c`
- **MODIFY**: `src/scip/cons_nonlinear.c` (sprintf→snprintf, include scip_io.h)
- **MODIFY**: CppAD headers (replace exit/abort in error handlers)

### Upstream SoPlex PR
- **NEW**: `src/soplex/spx_io.h`
- **MODIFY**: `CMakeLists.txt` (add CUSTOMIO option)
- **MODIFY**: `src/soplex/spxout.cpp` (default stream init)
- **MODIFY**: `src/soplex/spxdefines.h` (ASSERT_WARN macro, include change)
- **MODIFY**: `src/soplex/spxdefines.cpp`
- **MODIFY**: ~60 `.hpp` header files (std::cout→SPX_IO_COUT, std::cerr→SPX_IO_CERR)
- **MODIFY**: `src/soplexmain.cpp`, `src/example.cpp`, `src/soplex_interface.cpp`

### R Package (after upstream merge)
- **NEW**: `inst/config/scip_custom_io.h`
- **NEW**: `inst/config/soplex_custom_io.h`
- **MODIFY**: `inst/build_scip.sh` (add `-DCUSTOMIO:bool=ON`)
- **KEEP**: `src/r_streams.cpp` (RStreamBuf implementation, unchanged)
- **MODIFY**: `inst/config/r_streams.h` (simplify: only C++ stream declarations needed now)
- **DELETE**: Fork repos' `r_pkg` branches (submodules point to upstream tags)
