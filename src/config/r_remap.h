#ifndef R_REMAP_H
#define R_REMAP_H

/*
 * Remap C standard I/O and exit functions to R equivalents.
 * Force-included via -include config/r_remap.h.
 *
 * Include system headers FIRST so their declarations are processed
 * before our macros shadow the function names.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#ifdef __cplusplus
#include <cstdio>
#include <cstdlib>
#include <cstring>
extern "C" {
#endif

extern void Rprintf(const char *, ...);
extern void REprintf(const char *, ...);
extern void Rf_error(const char *, ...) __attribute__((noreturn));

/* Returns a FILE* that writes through Rprintf (stdout replacement) */
extern FILE *R_stdout_file(void);
/* Returns a FILE* that writes through REprintf (stderr replacement) */
extern FILE *R_stderr_file(void);

#ifdef __cplusplus
}
#endif

/* C++ stream replacements for std::cout / std::cerr */
#ifdef __cplusplus
#include <ostream>
extern std::ostream& r_cout();
extern std::ostream& r_cerr();
#endif

/* Now safe to define: system headers already processed */
#undef printf
#define printf Rprintf
#undef vprintf
#define vprintf(fmt, ap) Rprintf(fmt, ap)
#undef puts
#define puts(s) Rprintf("%s\n", s)
#undef putchar
#define putchar(c) Rprintf("%c", c)
#undef abort
#ifdef __cplusplus
[[noreturn]] inline void r_abort() { Rf_error("SCIP internal error (abort)"); }
#else
static inline void r_abort(void) { Rf_error("SCIP internal error (abort)"); }
#endif
#define abort r_abort

/* Redirect stdout/stderr to R's I/O */
#undef stdout
#define stdout R_stdout_file()
#undef stderr
#define stderr R_stderr_file()

#endif
