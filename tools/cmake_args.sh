#!/bin/sh
# Generate CMake arguments using R's toolchain
# Source this or call get_cmake_toolchain_args to get the flags

get_cmake_toolchain_args() {
    R_HOME=$("${R_HOME}/bin/R" RHOME 2>/dev/null || R RHOME)

    # Extract compiler and flag variables from R
    CC=$(${R_HOME}/bin/Rscript -e "cat(Sys.getenv('CC', unset=system2(file.path(R.home('bin'),'R'), c('CMD','config','CC'), stdout=TRUE)))")
    CXX17=$(${R_HOME}/bin/Rscript -e "cat(system2(file.path(R.home('bin'),'R'), c('CMD','config','CXX17'), stdout=TRUE))")
    CFLAGS=$(${R_HOME}/bin/Rscript -e "cat(system2(file.path(R.home('bin'),'R'), c('CMD','config','CFLAGS'), stdout=TRUE))")
    CXX17FLAGS=$(${R_HOME}/bin/Rscript -e "cat(system2(file.path(R.home('bin'),'R'), c('CMD','config','CXX17FLAGS'), stdout=TRUE))")
    CPICFLAGS=$(${R_HOME}/bin/Rscript -e "cat(system2(file.path(R.home('bin'),'R'), c('CMD','config','CPICFLAGS'), stdout=TRUE))")
    CXXPICFLAGS=$(${R_HOME}/bin/Rscript -e "cat(system2(file.path(R.home('bin'),'R'), c('CMD','config','CXX17PICFLAGS'), stdout=TRUE))")
    CPPFLAGS=$(${R_HOME}/bin/Rscript -e "cat(system2(file.path(R.home('bin'),'R'), c('CMD','config','CPPFLAGS'), stdout=TRUE))")
    LDFLAGS=$(${R_HOME}/bin/Rscript -e "cat(system2(file.path(R.home('bin'),'R'), c('CMD','config','LDFLAGS'), stdout=TRUE))")
    AR=$(${R_HOME}/bin/Rscript -e "cat(system2(file.path(R.home('bin'),'R'), c('CMD','config','AR'), stdout=TRUE))")
    RANLIB=$(${R_HOME}/bin/Rscript -e "cat(system2(file.path(R.home('bin'),'R'), c('CMD','config','RANLIB'), stdout=TRUE))")

    echo "-DCMAKE_C_COMPILER=${CC}" \
         "-DCMAKE_CXX_COMPILER=${CXX17}" \
         "-DCMAKE_C_FLAGS=${CFLAGS} ${CPICFLAGS} ${CPPFLAGS}" \
         "-DCMAKE_CXX_FLAGS=${CXX17FLAGS} ${CXXPICFLAGS} ${CPPFLAGS}" \
         "-DCMAKE_AR=${AR}" \
         "-DCMAKE_RANLIB=${RANLIB}" \
         "-DCMAKE_EXE_LINKER_FLAGS=${LDFLAGS}" \
         "-DCMAKE_SHARED_LINKER_FLAGS=${LDFLAGS}" \
         "-DCMAKE_BUILD_TYPE=Release"
}
