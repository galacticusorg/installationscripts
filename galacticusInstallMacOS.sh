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

# Ensure that XCode developer tools are installed.
if [[ ! $(xcode-select -p) ]]; then
    xcode-select --install
fi
export PATH=$PATH:/opt/local/bin:/usr/local/bin

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
else
    echo Unknown MacOS version: ${os_ver}
    exit 1
fi

# Download and install MacPorts.
curl -L https://github.com/macports/macports-base/releases/download/v${macportsversion}/MacPorts-${macportsbase}.pkg --output MacPorts-${macportsbase}.pkg
sudo installer -pkg ./MacPorts-${macportsbase}.pkg -target /
rm ./MacPorts-${macportsbase}.pkg

# Install GCC v12 via MacPorts.
sudo port install gcc12

# Install guile v1.8 via MacPorts.
sudo port install guile18

# Install GSL via MacPorts.
sudo port install gsl

# Install libmatheval v1.1.12 from source.
curl -L https://github.com/galacticusorg/libmatheval/releases/download/latest/libmatheval-1.1.12.tar.gz --output libmatheval-1.1.12.tar.gz
tar xvfz libmatheval-1.1.12.tar.gz
cd libmatheval-1.1.12
# Patch following the approach used in MacPorts (https://github.com/macports/macports-ports/tree/master/math/libmatheval).
sed -E -i~ s/"#undef HAVE_SCM_T_BITS"/"#define HAVE_SCM_T_BITS 1"/ config.h.in
sed -E -i~ s/"-lguile"/"-lguile18"/ configure
sed -E -i~ s/"libguile.h"/"libguile18.h"/g configure tests/matheval.c
# Set guile paths following the approach used in MacPorts (https://github.com/macports/macports-ports/tree/master/math/libmatheval).
CC=gcc-mp-12 GUILE=/opt/local/bin/guile18 GUILE_CONFIG=/opt/local/bin/guile18-config GUILE_TOOLS=/opt/local/bin/guile18-tools ./configure --prefix=/usr/local
make -j${countCPUs}
sudo make install
cd ..
rm -rf libmatheval-1.1.12.tar.gz libmatheval-1.1.12

# Install qhull from source.
curl -L http://www.qhull.org/download/qhull-2020-src-8.0.2.tgz --output qhull-2020-src-8.0.2.tgz
tar xvfz qhull-2020-src-8.0.2.tgz
cd qhull-2020.2
make -j${countCPUs} CC=gcc-mp-12 CXX=g++-mp-12
sudo make install
cd ..
rm -rf qhull-2020-src-8.0.2.tgz qhull-2020.2

# Install hdf5 v1.8.20 from source.
curl -L https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8/hdf5-1.8.20/src/hdf5-1.8.20.tar.gz --output hdf5-1.8.20.tar.gz
tar -vxzf hdf5-1.8.20.tar.gz 
cd hdf5-1.8.20 
# Patch files to ensure we include sys/syslimits.h which defines PATH_MAX
sed -E -i~ 's/^(# *include +<limits\.h>.*)$/\1\n#include <sys\/syslimits.h>\n/' src/H5private.h src/H5public.h
if   [[ "${ver}" -ge 13 ]]; then
    # On MacOS 13 there is an issue with the linker no longer suppotring the '-commons' flag, so force use of the classic linker
    # (https://www.scivision.dev/xcode-ld_classic/).
    HDF5LDFLAGS="$LDFLAGS -Wl,-ld_classic"
elif [[ "${ver}" -ge 14 ]]; then
    HDF5CFLAGS=-I/Library/Developer/CommandLineTools/SDKs/MacOSX14.2.sdk/usr/include
    # On MacOS 14 the 'sys/cdefs.h' header file contains pre-processor code which is not parseable by GCC 12. As it is
    # Clang-specific, we just make a copy of this file and destroy the problematic code.
    mkdir sys
    cp /Library/Developer/CommandLineTools/SDKs/MacOSX14.sdk/usr/include/sys/cdefs.h sys/
    sed -E -i~ s/"clang::"/"clang"/ sys/cdefs.h
fi
CC=gcc-mp-12 CXX=g++-mp-12 FC=gfortran-mp-12 CFLAGS=${HDF5CFLAGS} LDFLAGS=${HDF5LDFLAGS} ./configure --prefix=/usr/local --enable-fortran --enable-production 
make -j${countCPUs}
sudo make install
cd ..
rm -rf hdf5-1.8.20 hdf5-1.8.20.tar.gz

# Install FoX v4.1.0 from source. 
curl -L https://github.com/andreww/fox/archive/refs/tags/4.1.0.tar.gz --output FoX-4.1.0.tar.gz
tar xvfz FoX-4.1.0.tar.gz
cd fox-4.1.0
FC=gfortran-mp-12 ./configure --prefix=/usr/local
make -j${countCPUs}
sudo make install
cd ..
rm -rf fox-4.1.0 FoX-4.1.0.tar.gz

# Install FFTW v3.3.4 from source.
curl -L ftp://ftp.fftw.org/pub/fftw/fftw-3.3.4.tar.gz --output fftw-3.3.4.tar.gz
tar xvfz fftw-3.3.4.tar.gz
cd fftw-3.3.4
F77=gfortran-mp-12 CC=gcc-mp-12 ./configure --prefix=/usr/local
make -j${countCPUs}
sudo make install
cd ..
rm -rf fftw-3.3.4 fftw-3.3.4.tar.gz

# Install ANN from source.
curl -L http://www.cs.umd.edu/~mount/ANN/Files/1.1.2/ann_1.1.2.tar.gz --output ann_1.1.2.tar.gz
tar xvfz ann_1.1.2.tar.gz
cd ann_1.1.2
sed -E -i~ s/"C\+\+ = g\+\+"/"C\+\+ = g\+\+\-mp\-12"/ Make-config
make macosx-g++
sudo cp bin/* /usr/local/bin/.
sudo cp lib/* /usr/local/lib/.
sudo cp -R include/* /usr/local/include/.

# Install packages needed for CPAN install.
## Net::SSLeay
if [[ "${ver}" -ge 14 ]]; then
    # For OS version 14 and above install OpenSSL and specify the exact version to use.
    sudo port install openssl11
    export OPENSSL_PREFIX=/opt/local/libexec/openssl11
fi
curl -L https://cpan.metacpan.org/authors/id/C/CH/CHRISN/Net-SSLeay-1.90.tar.gz --output Net-SSLeay-1.90.tar.gz
tar xvfz Net-SSLeay-1.90.tar.gz
cd Net-SSLeay-1.90
perl Makefile.PL
make -j${countCPUs}
sudo make install
cd ..
rm -rf Net-SSLeay-1.90.tar.gz Net-SSLeay-1.90
## IO::Socket::SSL
curl -L https://cpan.metacpan.org/authors/id/S/SU/SULLR/IO-Socket-SSL-1.966.tar.gz --output IO-Socket-SSL-1.966.tar.gz
tar xvfz IO-Socket-SSL-1.966.tar.gz
cd IO-Socket-SSL-1.966
perl Makefile.PL
make -j${countCPUs}
sudo make install
cd ..
rm -rf IO-Socket-SSL-1.966.tar.gz IO-Socket-SSL-1.966
## Sys::CPU
curl -L https://cpan.metacpan.org/authors/id/M/MK/MKODERER/Sys-CPU-0.52.tar.gz --output Sys-CPU-0.52.tar.gz
tar xvfz Sys-CPU-0.52.tar.gz
cd Sys-CPU-0.52
perl Makefile.PL CCFLAGS=-Wno-error=implicit-function-declaration
make -j${countCPUs}
sudo make install
cd ..
rm -rf Sys-CPU-0.52.tar.gz Sys-CPU-0.52

# Install CPAN.
sudo perl -MCPAN -e 'install Bundle::CPAN'

# Install all required Perl modules.
if [[ "${ver}" -eq 14 ]]; then
    PERLCFLAGS=-I/Library/Developer/CommandLineTools/SDKs/MacOSX14.2.sdk/System/Library/Perl/5.30/darwin-thread-multi-2level/CORE perl -MCPAN -e 'force("install","Alien::Base::Wrapper")'
else
    PERLCFLAGS=
fi
sudo perl -MCPAN -e 'force("install","NestedMap")'
sudo perl -MCPAN -e 'force("install","Scalar::Util")'
sudo perl -MCPAN -e 'force("install","Term::ANSIColor")'
sudo perl -MCPAN -e 'force("install","Text::Table")'
sudo perl -MCPAN -e 'force("install","ExtUtils::ParseXS")'
sudo perl -MCPAN -e 'force("install","Path::Tiny")'
sudo perl -MCPAN -e 'force("install","PkgConfig")'
sudo CFLAGS=${PERLCFLAGS} perl -MCPAN -e 'force("install","Alien::Base::Wrapper")'
sudo perl -MCPAN -e 'force("install","Alien::Libxml2")'
sudo perl -MCPAN -e 'force("install","XML::LibXML::SAX")'
sudo perl -MCPAN -e 'force("install","XML::LibXML::SAX::Parser")'
if [[ "${ver}" -ge 12 ]]; then
    # For OS versions 12 and above we need to ensure that the ParserDetails.ini is set up.
    sudo perl -MXML::SAX -e "XML::SAX->add_parser('XML::SAX::PurePerl')->save_parsers()" || true
    sudo perl -MXML::SAX -e "XML::SAX->add_parser('XML::LibXML::SAX::Parser')->save_parsers()" 
    sudo perl -MXML::SAX -e "XML::SAX->add_parser('XML::LibXML::SAX')->save_parsers()" 
fi
sudo perl -MCPAN -e 'force("install","XML::SAX::ParserFactory")'
sudo perl -MCPAN -e 'force("install","XML::Validator::Schema")'
sudo perl -MCPAN -e 'force("install","Text::Template")'
sudo perl -MCPAN -e 'force("install","List::Uniq")'
sudo perl -MCPAN -e 'force("install","IO::Util")'
sudo perl -MCPAN -e 'force("install","Class::Util")'
sudo perl -MCPAN -e 'force("install","CGI::Builder")'
sudo perl -MCPAN -e 'force("install","Simple")'
sudo perl -MCPAN -e 'force("install","Readonly")'
sudo perl -MCPAN -e 'force("install","File::Slurp")'
sudo perl -MCPAN -e 'force("install","XML::Simple")'
sudo CFLAGS=${PERLCFLAGS} perl -MCPAN -e 'force("install","List::MoreUtils")'
sudo perl -MCPAN -e 'force("install","Clone")'
sudo perl -MCPAN -e 'force("install","IO::Scalar")'
sudo perl -MCPAN -e 'force("install","Regexp::Common")'
sudo perl -MCPAN -e 'force("install","LaTeX::Encode")'
sudo perl -MCPAN -e 'force("install","Sub::Identify")'

# Clone the Galacticus repository.
git clone https://github.com/galacticusorg/galacticus.git

# Build Galacticus.
cd galacticus
export GALACTICUS_EXEC_PATH=`pwd`
export FCCOMPILER=gfortran-mp-12
export CCOMPILER=gcc-mp-12
export CPPCOMPILER=g++-mp-12
export GALACTICUS_FCFLAGS="-fintrinsic-modules-path /usr/local/include -fintrinsic-modules-path /usr/local/finclude -L/usr/local/lib -L/opt/local/lib"
export GALACTICUS_CFLAGS="-I/usr/local/include -I/opt/local/include"
export GALACTICUS_CPPFLAGS="-I/usr/local/include -I/opt/local/include"
make -j${countCPUs} Galacticus.exe
