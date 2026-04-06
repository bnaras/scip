# Saved R patches from SCIP 10.0.1 r_pkg branches

Exported 2026-04-06 before upgrading to SCIP 10.0.2.
These are `git format-patch` files that can be applied with `git am`.

## scip-src/ (9 patches)

### Likely still needed (not tinycthread-related)

- `0003-Add-githash.c-for-non-CMake-builds-R-package.patch`
  Static githash.c so R's non-CMake compile gets a version string.
- `0004-Fix-strerror_r-variant-detection-on-macOS-with-_GNU_.patch`
  macOS strerror_r portability fix.
- `0005-Add-r_streams.h-include-for-R-compatible-output-decl.patch`
  Header declaring Rprintf/REprintf wrappers.
- `0008-Patch-objconshdlr.h-replace-fprintf-stdout-.-with-Rp.patch`
  SCIP core fprintf(stdout,...) -> Rprintf (CRAN requirement).

### Probably dead with TPI=omp (tinycthread-related)

- `0001-R-compatibility-replace-exit-abort-fprintf-sprintf-w.patch`
  Bulk stdio/abort replacements — many were in tinycthread paths.
- `0002-CRAN-compliance-fix-warnings-in-vendored-sources.patch`
  Compiler warnings — check if upstream 10.0.2 fixed them.
- `0006-Replace-direct-stdio-abort-calls-with-R-API-equivale.patch`
  More stdio replacements — overlap with 0001, tinycthread-heavy.
- `0007-Prefix-tinycthread-C11-names-to-avoid-glibc-C23-coll.patch`
  Pure tinycthread fix — dead with TPI=omp.
- `0009-R-compatibility-guard-tinycthread-includes-and-fix-p.patch`
  Guard tinycthread.h includes + tpi_openmp.c Rprintf — the tpi_openmp
  part may still be needed but the tinycthread guards are moot.

## soplex-src/ (5 patches)

### Likely still needed

- `0003-Add-git_hash.cpp-for-non-CMake-builds.patch`
  Static git_hash.cpp for R's non-CMake compile.
- `0004-Add-r_streams.h-include-for-R-compatible-output-decl.patch`
  Header for R I/O wrappers.
- `0005-Fix-deprecated-literal-operator-spacing-in-fmt-forma.patch`
  C++11 literal operator fix — check if upstream 10.0.2 fixed it.

### May be partially dead

- `0001-R-compatibility-redirect-std-cerr-std-cout-through-R.patch`
  cerr/cout -> R streams. Still needed for CRAN (no stdout/stderr).
- `0002-CRAN-compliance-disable-fmt-string_view-redirect-I-O.patch`
  fmt library tweaks. Check if upstream updated fmt.
