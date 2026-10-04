## Submission

This release fixes the installation failure reported on
`r-devel-linux-x86_64-fedora-clang` after that check flavor moved to LLVM 23.1.0
on 2026-08-25.

LLVM 23's libc++ dropped a large number of transitive includes in all language
modes, exposing three headers in the bundled solvers that had relied on them:

* SoPlex `basevectors.h` and `mpsinput.cpp` use `std::basic_istream` but only
  `<ostream>` was reachable, giving
  `implicit instantiation of undefined template 'std::basic_istream<char>'`.
  Since `basevectors.h` is reached from `soplex.h`, this broke every translation
  unit that includes SoPlex, and the reported build died inside `libsoplex`.
* SCIP `multiprecision.hpp` calls `atof` without `<cstdlib>`. This one does not
  appear in the CRAN report: the build failed earlier, in SoPlex, so no SCIP
  translation unit was ever compiled.

All three now include the required header. There is no user-visible change and no
change to the R code or the package API.

To be sure the second wave was complete rather than merely absent from the report,
every header and C++ source in both bundled trees was compiled twice, with and
without libc++'s transitive includes, keeping only the regressions: 158 SoPlex
headers, 891 SCIP headers and 56 C++ sources, yielding the three sites above.

## Test environments

* Local reproduction of the reporting check flavor, in a container built to match
  it: Fedora 44, x86_64, clang 23.1.0 and flang 23.1.0 installed at
  `/usr/local/clang23`, R-devel (2026-08-25 r90448) configured from the published
  `config.site` for that flavor (`--without-lapack`), with the documented
  `_R_CHECK_*` environment set.

Before these changes `R CMD INSTALL` fails at `mpsinput.cpp:83`; after them SoPlex
and SCIP both build and link, and `R CMD check --as-cran` completes with no errors
or warnings. `checking compiled code` passes.

## R CMD check results

0 errors | 0 warnings | 2 notes

1. `checking CRAN incoming feasibility` reports two URLs as possibly invalid:

   ```
   https://scipopt.org/                                Status: 429
   https://www.scipopt.org/doc/html/PARAMETERS.php     Status: 429
   ```

   Both are correct and reachable. HTTP 429 is "Too Many Requests" — the SCIP
   project's web server rate-limits repeated automated requests. The URLs are
   unchanged from the previous release.

2. `checking HTML version of manual` reports that `tidy` and the `V8` package
   were unavailable in the container used for the check, so HTML validation and
   math rendering were skipped. It reflects the checking environment, not the
   package.

## Downstream dependencies

None on CRAN.
