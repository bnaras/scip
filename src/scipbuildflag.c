#include "scip/scipbuildflags.h"

const char* SCIPgetBuildFlags(void)
{
   return " BUILD=Release\n"
          " LPS=spx\n"
          " GMP=OFF\n"
          " ZIMPL=OFF\n"
          " ZLIB=OFF\n"
          " READLINE=OFF\n"
          " PAPILO=OFF\n"
          " SHARED=OFF\n"
          " VERSION=10.0.1\n"
          " API_VERSION=156\n";
}
