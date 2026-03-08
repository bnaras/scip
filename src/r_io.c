/*
 * Custom FILE* streams that redirect to R's Rprintf/REprintf.
 * Used to replace stdout/stderr in SCIP/SoPlex so that R CMD check
 * does not flag use of these globals.
 *
 * Uses funopen() on macOS/BSD, fopencookie() on Linux/glibc,
 * and a tmpfile fallback on Windows.
 */

/* Prevent r_remap.h from redefining stdout/stderr in this file */
#define R_REMAP_H

#include <R.h>
#include <Rinternals.h>
#include <stdio.h>
#include <string.h>

/* Declare funopen/fopencookie explicitly since _XOPEN_SOURCE may hide them */
#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)
extern FILE *funopen(const void *,
    int (*)(void *, char *, int),
    int (*)(void *, const char *, int),
    fpos_t (*)(void *, fpos_t, int),
    int (*)(void *));
#endif

/* --- Platform-specific custom FILE* creation --- */

#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)
/* BSD: funopen */

static int r_stdout_write(void *cookie, const char *buf, int len) {
    char tmp[len + 1];
    memcpy(tmp, buf, len);
    tmp[len] = '\0';
    Rprintf("%s", tmp);
    return len;
}

static int r_stderr_write(void *cookie, const char *buf, int len) {
    char tmp[len + 1];
    memcpy(tmp, buf, len);
    tmp[len] = '\0';
    REprintf("%s", tmp);
    return len;
}

static FILE *make_r_stdout(void) {
    return funopen(NULL, NULL, r_stdout_write, NULL, NULL);
}

static FILE *make_r_stderr(void) {
    return funopen(NULL, NULL, r_stderr_write, NULL, NULL);
}

#elif defined(__linux__) || defined(__GLIBC__)
/* Linux/glibc: fopencookie */

static ssize_t r_stdout_write(void *cookie, const char *buf, size_t len) {
    char tmp[len + 1];
    memcpy(tmp, buf, len);
    tmp[len] = '\0';
    Rprintf("%s", tmp);
    return (ssize_t)len;
}

static ssize_t r_stderr_write(void *cookie, const char *buf, size_t len) {
    char tmp[len + 1];
    memcpy(tmp, buf, len);
    tmp[len] = '\0';
    REprintf("%s", tmp);
    return (ssize_t)len;
}

static FILE *make_r_stdout(void) {
    cookie_io_functions_t funcs = {0};
    funcs.write = r_stdout_write;
    return fopencookie(NULL, "w", funcs);
}

static FILE *make_r_stderr(void) {
    cookie_io_functions_t funcs = {0};
    funcs.write = r_stderr_write;
    return fopencookie(NULL, "w", funcs);
}

#elif defined(_WIN32)
/* Windows: no custom FILE* mechanism, use tmpfile as sink */

static FILE *make_r_stdout(void) {
    FILE *f = tmpfile();
    return f ? f : fopen("NUL", "w");
}

static FILE *make_r_stderr(void) {
    FILE *f = tmpfile();
    return f ? f : fopen("NUL", "w");
}

#else
/* Unknown platform: /dev/null fallback */

static FILE *make_r_stdout(void) {
    return fopen("/dev/null", "w");
}

static FILE *make_r_stderr(void) {
    return fopen("/dev/null", "w");
}

#endif

/* --- Public API: cached FILE* singletons --- */

static FILE *s_r_stdout = NULL;
static FILE *s_r_stderr = NULL;

FILE *R_stdout_file(void) {
    if (s_r_stdout == NULL)
        s_r_stdout = make_r_stdout();
    return s_r_stdout;
}

FILE *R_stderr_file(void) {
    if (s_r_stderr == NULL)
        s_r_stderr = make_r_stderr();
    return s_r_stderr;
}
