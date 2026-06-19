#!/usr/bin/env bash

# Script to install all tools and libraries needed for Galacticus, and then build Galacticus itself on MacOS.
# Andrew Benson (09-April-2024)

# NOTE: You will require `sudo` priveleges to use this script, and will be prompted to enter your password (possibly multiple
#       times) during installation.

# NOTE: If you receive any prompt asking for a choice, go with the default (i.e. just press "enter").

# NOTE: If you see a pop-up saying ““Terminal” would like to administer your computer. Administration can include modifying
#       passwords, networking, and system settings.”, click to approve it.

# WARNING: This script should be considered to be a beta-release. If you experience problems using it, please report these at the
#          Galacticus discussion forum:
#
#              https://github.com/galacticusorg/galacticus/discussions

# Abort immediately if any command fails (including a failed download or a failure in a pipeline), so that problems such as
# a failed HDF5 download cause the script to exit with an error status right away, rather than surfacing much later as a
# confusing build failure.
set -eo pipefail

# Ensure that XCode developer tools are installed.
if [[ ! $(xcode-select -p) ]]; then
    xcode-select --install
fi
export PATH=$PATH:/opt/local/bin:/usr/local/bin

# Point GCC 16's Darwin driver at the active SDK. Without SDKROOT, GCC 16 fails to locate the system headers
# (e.g. <stdlib.h>, <limits.h>) and libraries, so even a trivial compile fails ("C compiler cannot create
# executables"). We resolve the SDK dynamically from the runner's own toolchain, so this tracks whatever SDK is
# current rather than pinning to a fixed version.
export SDKROOT="$(xcrun --show-sdk-path)"

# Determine number of CPUs available.
countCPUs=`sysctl -n hw.ncpu`

# Determine OS version.
os_ver=$(sw_vers -productVersion)
IFS='.' read -r -a ver <<< "$os_ver"

# Select appropriate MacPorts version based on the OS version.
if [[ "${ver}" -eq 11 ]]; then
    macportsversion=2.7.1
    macportsbase=2.7.1-11-BigSur
elif [[ "${ver}" -eq 12 ]]; then
    macportsversion=2.9.1
    macportsbase=2.9.1-12-Monterey
elif [[ "${ver}" -eq 13 ]]; then
    macportsversion=2.9.1
    macportsbase=2.9.1-13-Ventura
elif [[ "${ver}" -eq 14 ]]; then
    macportsversion=2.9.1
    macportsbase=2.9.1-14-Sonoma
elif [[ "${ver}" -eq 15 ]]; then
    macportsversion=2.11.6
    macportsbase=2.11.6-15-Sequoia
else
    echo Unknown MacOS version: ${os_ver}
    exit 1
fi

# Download and install MacPorts.
curl -fL --retry 3 https://github.com/macports/macports-base/releases/download/v${macportsversion}/MacPorts-${macportsbase}.pkg --output MacPorts-${macportsbase}.pkg
sudo installer -pkg ./MacPorts-${macportsbase}.pkg -target /
rm ./MacPorts-${macportsbase}.pkg

# Install GCC 16 via HomeBrew. The `gcc` formula now provides GCC 16, installing version-suffixed binaries
# (`gcc-16`, `g++-16`, `gfortran-16`) into the HomeBrew prefix, which is already on PATH. Because the bottle is
# built against the runner's own SDK, no SDK pinning or SDKROOT override is needed.
brew install gcc

# Install guile v3.0 via MacPorts.
sudo port install guile-3.0
sudo port select --set guile guile-3.0

# Install GSL via MacPorts.
sudo port install gsl

# Install libmatheval v1.1.13 from source.
curl -fL --retry 3 https://github.com/galacticusorg/libmatheval/releases/download/latest/libmatheval-1.1.13.tar.gz --output libmatheval-1.1.13.tar.gz
tar xvfz libmatheval-1.1.13.tar.gz
cd libmatheval-1.1.13
# Patch following the approach used in MacPorts (https://github.com/macports/macports-ports/tree/master/math/libmatheval).
sed -E -i~ s/"#undef HAVE_SCM_T_BITS"/"#define HAVE_SCM_T_BITS 1"/ config.h.in
# Set guile paths following the approach used in MacPorts (https://github.com/macports/macports-ports/tree/master/math/libmatheval).
CC=gcc-16 PKG_CONFIG=/opt/local/bin/pkg-config GUILE=/opt/local/bin/guile-3.0 GUILE_CONFIG=/opt/local/bin/guile-config-3.0 GUILE_TOOLS=/opt/local/bin/guile-tools-3.0 ./configure --prefix=/usr/local
make -j${countCPUs}
sudo make install
cd ..
rm -rf libmatheval-1.1.13.tar.gz libmatheval-1.1.13

# Install qhull from source.
curl -fL --retry 3 http://www.qhull.org/download/qhull-2020-src-8.0.2.tgz --output qhull-2020-src-8.0.2.tgz
tar xvfz qhull-2020-src-8.0.2.tgz
cd qhull-2020.2
make -j${countCPUs} CC=gcc-16 CXX=g++-16
sudo make install
cd ..
rm -rf qhull-2020-src-8.0.2.tgz qhull-2020.2

# Install hdf5 v1.14.5 from source.
curl -fL --retry 3 https://support.hdfgroup.org/releases/hdf5/v1_14/v1_14_5/downloads/hdf5-1.14.5.tar.gz --output hdf5-1.14.5.tar.gz
tar -vxzf hdf5-1.14.5.tar.gz
cd hdf5-1.14.5
# Patch files to ensure we include sys/syslimits.h which defines PATH_MAX
sed -E -i~ 's/^(# *include +<limits\.h>.*)$/\1\n#include <sys\/syslimits.h>\n/' src/H5private.h src/H5public.h
if   [[ "${ver}" -eq 13 ]]; then
    # On MacOS 13 there is an issue with the linker no longer suppotring the '-commons' flag, so force use of the classic linker
    # (https://www.scivision.dev/xcode-ld_classic/).
    HDF5LDFLAGS="$LDFLAGS -Wl,-ld_classic"
elif [[ "${ver}" -eq 14 ]]; then
    HDF5CFLAGS=-I/Library/Developer/CommandLineTools/SDKs/MacOSX14.2.sdk/usr/include
    # On MacOS 14 the 'sys/cdefs.h' header file contains pre-processor code which is not parseable by GCC. As it is
    # Clang-specific, we just make a copy of this file and destroy the problematic code.
    mkdir sys
    cp /Library/Developer/CommandLineTools/SDKs/MacOSX14.sdk/usr/include/sys/cdefs.h sys/
    sed -E -i~ s/"clang::"/"clang"/ sys/cdefs.h
    HDF5CFLAGS="-I`pwd` ${HDF5CFLAGS}"
fi
CC=gcc-16 CXX=g++-16 FC=gfortran-16 CFLAGS=${HDF5CFLAGS} LDFLAGS=${HDF5LDFLAGS} ./configure --prefix=/usr/local --enable-fortran --enable-build-mode=production
make -j${countCPUs}
sudo make install
cd ..
rm -rf hdf5-1.14.5 hdf5-1.14.5.tar.gz

# Install FoX v4.1.0 from source. 
curl -fL --retry 3 https://github.com/andreww/fox/archive/refs/tags/4.1.0.tar.gz --output FoX-4.1.0.tar.gz
tar xvfz FoX-4.1.0.tar.gz
cd fox-4.1.0
FC=gfortran-16 ./configure --prefix=/usr/local
make -j${countCPUs}
sudo make install
cd ..
rm -rf fox-4.1.0 FoX-4.1.0.tar.gz

# Install FFTW v3.3.4 from source.
curl -fL --retry 3 ftp://ftp.fftw.org/pub/fftw/fftw-3.3.4.tar.gz --output fftw-3.3.4.tar.gz
tar xvfz fftw-3.3.4.tar.gz
cd fftw-3.3.4
F77=gfortran-16 CC=gcc-16 ./configure --prefix=/usr/local
make -j${countCPUs}
sudo make install
cd ..
rm -rf fftw-3.3.4 fftw-3.3.4.tar.gz

# Install ANN from source.
curl -fL --retry 3 http://www.cs.umd.edu/~mount/ANN/Files/1.1.2/ann_1.1.2.tar.gz --output ann_1.1.2.tar.gz
tar xvfz ann_1.1.2.tar.gz
cd ann_1.1.2
sed -E -i~ s/"C\+\+ = g\+\+"/"C\+\+ = g\+\+\-16"/ Make-config
# ANN's ann_test.cpp uses an `istream >> char*` idiom that newer C++ standards no longer match against any operator>>
# overload — force -std=gnu++17 to keep it accepted. We pick gnu++17 over c++17 because the strict-ISO mode triggered
# by c++17 sets __STRICT_ANSI__, which causes the macOS SDK headers to hide non-strict declarations.
sed -E -i~ s,"CFLAGS = -O3","CFLAGS = -O3 -std=gnu++17", Make-config
make macosx-g++
if [ $? -ne 0 ]; then
    exit 1
fi
sudo cp bin/* /usr/local/bin/.
sudo cp lib/* /usr/local/lib/.
sudo cp -R include/* /usr/local/include/.

# Install Python 3 (with pip) via MacPorts. This is needed to install Galacticus' Python build dependencies.
sudo port install python312 py312-pip
sudo port select --set python3 python312
sudo port select --set pip3 pip312

# Clone the Galacticus repository.
git clone https://github.com/galacticusorg/galacticus.git

# Create a Python virtual environment and install Galacticus' Python build dependencies (declared in pyproject.toml).
/opt/local/bin/python3.12 -m venv galacticus/python-venv
source galacticus/python-venv/bin/activate
pip install -e galacticus

# Build Galacticus.
cd galacticus
export GALACTICUS_EXEC_PATH=`pwd`
export FCCOMPILER=gfortran-16
export CCOMPILER=gcc-16
export CPPCOMPILER=g++-16
export GALACTICUS_FCFLAGS="-fintrinsic-modules-path /usr/local/include -fintrinsic-modules-path /usr/local/finclude -L/usr/local/lib -L/opt/local/lib"
if [[ "${ver}" -eq 13 ]]; then
    export GALACTICUS_FCFLAGS="$GALACTICUS_FCFLAGS -Wl,-ld_classic"
fi
export GALACTICUS_CFLAGS="-I/usr/local/include -I/opt/local/include"
export GALACTICUS_CPPFLAGS="-I/usr/local/include -I/opt/local/include"
make -j${countCPUs} Galacticus.exe
