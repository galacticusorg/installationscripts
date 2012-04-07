#!/usr/bin/env bash

# Galacticus install script.
# v0.9.1
# © Andrew Benson 2011

# Define a log file.
glcLogFile=`pwd`"/galacticusInstall.log"

# Open the log file.
echo "Galacticus v0.9.1 install log" > $glcLogFile

# Write some useful machine info to the log file if possible.
hash uname >& /dev/null
if [ $? -eq 0 ]; then
    uname -a >>$glcLogFile 2>&1
fi

# Create an install folder, and move into it.
mkdir -p galacticusInstallWork
cd galacticusInstallWork

# Do we want to install as root, or as a regular user?
if [[ $UID -eq 0 ]]; then
    echo "Script is being run as root."
    echo "Script is being run as root." >> $glcLogFile
    installAsRoot=1
    runningAsRoot=1
    # Set up a suitable install path.
    toolInstallPath=/usr/local/galacticus
    read -p "Path to install tools to as root [$toolInstallPath]: " RESPONSE
    if [ -n "$RESPONSE" ]; then
        toolInstallPath=$RESPONSE
    fi
else
    installAsRoot=-1
    runningAsRoot=0
fi
while [ $installAsRoot -eq -1 ]
do
    read -p "Install required libraries and Perl modules as root (requires root password)? [no/yes]: " RESPONSE
    
    if [ "$RESPONSE" = yes ] ; then
	# Installation will be done as root where possible.
        installAsRoot=1

	# Ask whether we should use "su" or "sudo" for root installs.
        suCommand="null"
        while [[ $suCommand == "null" ]]
        do
	    read -p "Use sudo or su for root installs:" suMethod
            if [[ $suMethod == "su" ]]; then
		suCommand="su -c \""
		suClose="\""
		pName="root"
            elif [[ $suMethod == "sudo" ]]; then
		suCommand="sudo -E -S -- "
		suClose=""
		pName="sudo"
            fi
        done

        # Get the root password.
        read -s -p "Please enter the $pName password:" rootPassword
	echo "$rootPassword" | eval $suCommand echo worked $suClose >& /dev/null
	echo
	if [ $? -ne 0 ] ; then
	    echo "$pName password was incorrect, exiting"
	    exit 1
	fi
	echo "Libraries and Perl modules will be installed as root"
	echo "Libraries and Perl modules will be installed as root" >> $glcLogFile

	# Set up a suitable install path.
        toolInstallPath=/usr/local/galacticus
        read -p "Path to install tools to as root [$toolInstallPath]: " RESPONSE
        if [ -n "$RESPONSE" ]; then
            toolInstallPath=$RESPONSE
        fi
    elif [ "$RESPONSE" = no ] ; then
	# Install as regular user.
        installAsRoot=0
	echo "Libraries and Perl modules will be installed as regular user"
	echo "Libraries and Perl modules will be installed as regular user" >> $glcLogFile

	# Set yp a suitable install path.
        toolInstallPath=$HOME/Galacticus/Tools
        read -p "Path to install tools to [$toolInstallPath]: " RESPONSE
        if [ -n "$RESPONSE" ]; then
            toolInstallPath=$RESPONSE
        fi
    else
	# Response invalid, try again.
	echo "Please enter 'yes' or 'no'"
    fi
done

# Export various environment variables with our install path prepended.
if [ -n "${PKG_CONFIG_PATH}" ]; then
    export PKG_CONFIG_PATH=$toolInstallPath/lib/pkgconfig:$PKG_CONFIG_PATH
else
    export PKG_CONFIG_PATH=$toolInstallPath/lib/pkgconfig
fi
if [ -n "${PATH}" ]; then
    export PATH=$toolInstallPath/bin:$PATH
else
    export PATH=$toolInstallPath/bin
fi
if [ -n "${LD_LIBRARY_PATH}" ]; then
    export LD_LIBRARY_PATH=$toolInstallPath/lib:$toolInstallPath/lib64:$LD_LIBRARY_PATH
else
    export LD_LIBRARY_PATH=$toolInstallPath/lib:$toolInstallPath/lib64
fi
if [ -n "${LD_RUN_PATH}" ]; then
    export LD_RUN_PATH=$toolInstallPath/lib:$toolInstallPath/lib64:$LD_RUN_PATH
else
    export LD_RUN_PATH=$toolInstallPath/lib:$toolInstallPath/lib64
fi
if [ -n "${LDFLAGS}" ]; then
    export LDFLAGS="-L$toolInstallPath/lib:$toolInstallPath/lib64:$LDFLAGS_PATH"
else
    export LDFLAGS="-L$toolInstallPath/lib:$toolInstallPath/lib64"
fi
if [ -n "${C_INCLUDE_PATH}" ]; then
    export C_INCLUDE_PATH=$toolInstallPath/include:$C_INCLUDE_PATH
else
    export C_INCLUDE_PATH=$toolInstallPath/include
fi
if [ -n "${PYTHONPATH}" ]; then
    export PYTHONPATH=$toolInstallPath/py-lib:$PATH
else
    export PYTHONPATH=$toolInstallPath/py-lib
fi
if [ -n "${PERLLIB}" ]; then
    export PERLLIB=$HOME/perl5/lib/perl5:$toolInstallPath/lib/perl5:$HOME/perl5/lib64/perl5:$toolInstallPath/lib64/perl5:$HOME/perl5/lib/perl5/site_perl:$toolInstallPath/lib/perl5/site_perl:$HOME/perl5/lib64/perl5/site_perl:$toolInstallPath/lib64/perl5/site_perl:$PERLLIB
else
    export PERLLIB=$HOME/perl5/lib/perl5:$toolInstallPath/lib/perl5:$HOME/perl5/lib64/perl5:$toolInstallPath/lib64/perl5:$HOME/perl5/lib/perl5/site_perl:$toolInstallPath/lib/perl5/site_perl:$HOME/perl5/lib64/perl5/site_perl:$toolInstallPath/lib64/perl5/site_perl
fi
if [ -n "${PERL5LIB}" ]; then
    export PERL5LIB=$HOME/perl5/lib/perl5:$toolInstallPath/lib/perl5:$HOME/perl5/lib64/perl5:$toolInstallPath/lib64/perl5:$HOME/perl5/lib/perl5/site_perl:$toolInstallPath/lib/perl5/site_perl:$HOME/perl5/lib64/perl5/site_perl:$toolInstallPath/lib64/perl5/site_perl:$PERL5LIB
else
    export PERL5LIB=$HOME/perl5/lib/perl5:$toolInstallPath/lib/perl5:$HOME/perl5/lib64/perl5:$toolInstallPath/lib64/perl5:$HOME/perl5/lib/perl5/site_perl:$toolInstallPath/lib/perl5/site_perl:$HOME/perl5/lib64/perl5/site_perl:$toolInstallPath/lib64/perl5/site_perl
fi

# Ensure that we use GNU compilers.
export CC=gcc
export CXX=g++
export FC=gfortran

# Minimal, typical or full install?
installLevel=-1
while [ $installLevel -eq -1 ]
do
    read -p "Minimal, typical or full install?: " RESPONSE
    
    if [ "$RESPONSE" = minimal ] ; then
        installLevel=0
	echo "Minimal install only (just enough to compile and run Galacticus)"
	echo "Minimal install only (just enough to compile and run Galacticus)" >> $glcLogFile
    elif [ "$RESPONSE" = typical ] ; then
        installLevel=1
	echo "Typical install (compile, run, make plots etc.)"
	echo "Typical install (compile, run, make plots etc.)" >> $glcLogFile
    elif [ "$RESPONSE" = full ]; then
        installLevel=2
        echo "Full install"
        echo "Full install" >> $glcLogFile
    else
	echo "Please enter 'minimal', 'typical' or 'full'"
    fi
done

# Use a package manager?
if [ $installAsRoot -eq 1 ]; then
    usePackageManager=-1
    while [ $usePackageManager -eq -1 ]
    do
	read -p "Use package manager for install (if available)?: " RESPONSE
        if [ "$RESPONSE" = yes ] ; then
            usePackageManager=1
	    echo "Package manager will be used for installs if possible"
	    echo "Package manager will be used for installs if possible" >> $glcLogFile
	elif [ "$RESPONSE" = no ] ; then
            usePackageManager=0
	    echo "Package manager will not be used for installs"
	    echo "Package manager will not be used for installs" >> $glcLogFile
	else
	    echo "Please enter 'yes' or 'no'"
	fi
    done
else
    usePackageManager=0
fi

# Figure out which install options are available to us.
installViaYum=0
if [[ $installAsRoot -eq 1 && $usePackageManager -eq 1 ]]; then
    if hash yum >& /dev/null; then
	installViaYum=1
    fi
fi
installViaApt=0
if [[ $installAsRoot -eq 1 && $usePackageManager -eq 1 ]]; then
    if hash apt-get >& /dev/null; then
	installViaApt=1
        echo "$rootPassword" | eval $suCommand apt-get update $suClose
    fi
fi
installViaCPAN=0
if hash perl >& /dev/null; then
    perl -e "use CPAN" >& /dev/null
    if [ $? -eq 0 ]; then
	installViaCPAN=1
    fi
fi

# Specify a list of paths to search for Fortran modules and libraries.
moduleDirs="-fintrinsic-modules-path $toolInstallPath/finclude -fintrinsic-modules-path $toolInstallPath/include -fintrinsic-modules-path $toolInstallPath/include/gfortran -fintrinsic-modules-path $toolInstallPath/lib/gfortran/modules -fintrinsic-modules-path /usr/local/finclude -fintrinsic-modules-path /usr/local/include/gfortran -fintrinsic-modules-path /usr/local/include -fintrinsic-modules-path /usr/lib/gfortran/modules -fintrinsic-modules-path /usr/include/gfortran -fintrinsic-modules-path /usr/include -fintrinsic-modules-path /usr/finclude -fintrinsic-modules-path /usr/lib64/gfortran/modules -L$toolInstallPath/lib -L$toolInstallPath/lib64"

# Specify a list of paths to search for library files.
libDirs="-L$toolInstallPath/lib -L$toolInstallPath/lib64"

# Define packages.
iPackage=-1
# sort
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="sort"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash sort && (echo 1.2.3 | sort --version-sort)"
      getVersion[$iPackage]="versionString=(\`sort --version\`); echo \${versionString[3]}"
      minVersion[$iPackage]="6.99"
      maxVersion[$iPackage]="9.99"
      yumInstall[$iPackage]="coreutils"
      aptInstall[$iPackage]="coreutils"
       sourceURL[$iPackage]="http://ftp.gnu.org/gnu/coreutils/coreutils-8.13.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]=""

# wget
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="wget"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash wget"
      getVersion[$iPackage]="versionString=(\`wget -V\`); echo \${versionString[2]}"
      minVersion[$iPackage]="0.0"
      maxVersion[$iPackage]="9.99"
      yumInstall[$iPackage]="wget"
      aptInstall[$iPackage]="wget"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# sed
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="sed"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash sed"
      getVersion[$iPackage]="versionString=(\`sed --version\`); echo \${versionString[3]}"
      minVersion[$iPackage]="0.0"
      maxVersion[$iPackage]="9.99"
      yumInstall[$iPackage]="sed"
      aptInstall[$iPackage]="sed"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# make
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="make"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash make"
      getVersion[$iPackage]="versionString=(\`make -v\`); echo \${versionString[2]}"
      minVersion[$iPackage]="0.0"
      maxVersion[$iPackage]="9.99"
      yumInstall[$iPackage]="make"
      aptInstall[$iPackage]="make"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# grep
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="grep"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash grep"
      getVersion[$iPackage]="versionString=(\`grep --version | sed -r s/\"[^0-9]*(([0-9]+\\.)+[0-9]+)\"/\"\\1\"/\`); echo \${versionString[0]}"
      minVersion[$iPackage]="0.0"
      maxVersion[$iPackage]="9.99"
      yumInstall[$iPackage]="grep"
      aptInstall[$iPackage]="grep"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# gcc (initial attempt - allow install via package manager only)
iPackage=$(expr $iPackage + 1)
            iGCC=$iPackage
         package[$iPackage]="gcc"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gcc"
      getVersion[$iPackage]="versionString=(\`gcc --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]="4.0.0"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="gcc"
      aptInstall[$iPackage]="gcc"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# g++ (initial attempt - allow install via package manager only)
iPackage=$(expr $iPackage + 1)
            iGPP=$iPackage
         package[$iPackage]="g++"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash g++"
      getVersion[$iPackage]="versionString=(\`g++ --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]="4.0.0"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="gcc-g++"
      aptInstall[$iPackage]="g++"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# GFortran (initial attempt - allow install via package manager only)
iPackage=$(expr $iPackage + 1)
        iFortran=$iPackage
         package[$iPackage]="gfortran"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gfortran"
      getVersion[$iPackage]="versionString=(\`gfortran --version\`); echo \${versionString[3]}"
      minVersion[$iPackage]="4.6.999"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="gcc-gfortran"
      aptInstall[$iPackage]="gfortran"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# SQLite (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
         iSQLite=$iPackage
         package[$iPackage]="sqlite"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash sqlite3"
      getVersion[$iPackage]="versionString=(\`sqlite3 -version\`); echo \${versionString[0]}"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="sqlite"
      aptInstall[$iPackage]="sqlite"
       sourceURL[$iPackage]="http://www.sqlite.org/sqlite-autoconf-3071100.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath --enable-threadsafe"
        makeTest[$iPackage]=""

# Apache Portable Runtime library (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
            iAPR=$iPackage
         package[$iPackage]="apr"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"main() {}\" > dummy.c; gcc dummy.c $libDirs -lapr"
      getVersion[$iPackage]="echo \"#include <apr_version.h>\" > dummy.c; echo \"main() {printf(\\\"%d.%d.%d\\\\n\\\",apr_version_t::major,apr_version_t::minor,apr_version_t::patch);}\" >> dummy.c; gcc dummy.c $libDirs -lapr; ./a.out"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="apr"
      aptInstall[$iPackage]="apr"
       sourceURL[$iPackage]="http://download.nextag.com/apache//apr/apr-1.4.6.tar.bz2"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="test"

# Apache Portable Runtime utility (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
        iAPRutil=$iPackage
         package[$iPackage]="apr-util"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"main() {}\" > dummy.c; gcc dummy.c $libDirs -lapu"
      getVersion[$iPackage]="echo \"#include <apr_version.h>\" > dummy.c; echo \"#include <apu.h>\" > dummy.c; echo \"main() {printf(\\\"%s\\\\n\\\",apu_version_string());}\" >> dummy.c; gcc dummy.c $libDirs -lapu; ./a.out"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="apr-util"
      aptInstall[$iPackage]="apr-util"
       sourceURL[$iPackage]="http://download.nextag.com/apache//apr/apr-util-1.4.1.tar.bz2"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="test"

# svn (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
            iSVN=$iPackage
         package[$iPackage]="svn"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash svn"
      getVersion[$iPackage]="svn --version --quiet"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="subversion"
      aptInstall[$iPackage]="subversion"
       sourceURL[$iPackage]="http://subversion.tigris.org/downloads/subversion-1.6.17.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"

# GMP (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
            iGMP=$iPackage
         package[$iPackage]="gmp"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"#include <gmp.h>\" > dummy.c; echo \"main() {}\" >> dummy.c; gcc dummy.c $libDirs -lgmp"
      getVersion[$iPackage]="echo \"#include <stdio.h>\" > dummy.c; echo \"#include <gmp.h>\" >> dummy.c; echo \"main() {printf(\\\"%d.%d.%d\\\\n\\\",__GNU_MP_VERSION,__GNU_MP_VERSION_MINOR,__GNU_MP_VERSION_PATCHLEVEL);}\" >> dummy.c; gcc dummy.c $libDirs -lgmp; ./a.out"
      minVersion[$iPackage]="4.3.1"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="gmp-devel"
      aptInstall[$iPackage]="libgmp3-dev"
       sourceURL[$iPackage]="ftp://ftp.gnu.org/gnu/gmp/gmp-5.0.2.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"

# MPFR (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
           iMPFR=$iPackage
         package[$iPackage]="mpfr"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"#include <mpfr.h>\" > dummy.c; echo \"main() {}\" >> dummy.c; gcc dummy.c $libDirs -lmpfr"
      getVersion[$iPackage]="echo \"#include <stdio.h>\" > dummy.c; echo \"#include <mpfr.h>\" >> dummy.c; echo \"main() {printf(\\\"%s\\\\n\\\",MPFR_VERSION_STRING);}\" >> dummy.c; gcc dummy.c $libDirs -lmpfr; ./a.out"
      minVersion[$iPackage]="2.3.0999"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="mpfr-devel"
      aptInstall[$iPackage]="libmpfr-dev"
       sourceURL[$iPackage]="http://www.mpfr.org/mpfr-3.1.0/mpfr-3.1.0.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"

# MPC (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
            iMPC=$iPackage
         package[$iPackage]="mpc"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"#include <mpc.h>\" > dummy.c; echo \"main() {}\" >> dummy.c; gcc dummy.c $libDirs -lmpc"
      getVersion[$iPackage]="echo \"#include <stdio.h>\" > dummy.c; echo \"#include <mpc.h>\" >> dummy.c; echo \"main() {printf(\\\"%s\\\\n\\\",MPC_VERSION_STRING);}\" >> dummy.c; gcc dummy.c $libDirs -lmpc; ./a.out"
      minVersion[$iPackage]="0.7.9999"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="libmpc-devel"
      aptInstall[$iPackage]="libmpc-dev"
       sourceURL[$iPackage]="http://www.multiprecision.org/mpc/download/mpc-0.9.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"

# gcc (second attempt - install from source)
iPackage=$(expr $iPackage + 1)
      iGCCsource=$iPackage
         package[$iPackage]="gcc"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gcc"
      getVersion[$iPackage]="versionString=(\`gcc --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]="4.0.0"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="null"
      aptInstall[$iPackage]="null"
       sourceURL[$iPackage]="svn://gcc.gnu.org/svn/gcc/trunk"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]="--prefix=$toolInstallPath --enable-languages= --disable-multilib"
        makeTest[$iPackage]=""

# g++ (second attempt - install from source)
iPackage=$(expr $iPackage + 1)
      iGPPsource=$iPackage
         package[$iPackage]="g++"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash g++"
      getVersion[$iPackage]="versionString=(\`g++ --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]="4.0.0"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="null"
      aptInstall[$iPackage]="null"
       sourceURL[$iPackage]="svn://gcc.gnu.org/svn/gcc/trunk"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]="--prefix=$toolInstallPath --enable-languages= --disable-multilib"
        makeTest[$iPackage]=""

# GFortran (second attempt - install from source)
iPackage=$(expr $iPackage + 1)
  iFortranSource=$iPackage
         package[$iPackage]="gfortran"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gfortran"
      getVersion[$iPackage]="versionString=(\`gfortran --version\`); echo \${versionString[3]}"
      minVersion[$iPackage]="4.6.999"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="null"
      aptInstall[$iPackage]="null"
       sourceURL[$iPackage]="svn://gcc.gnu.org/svn/gcc/trunk"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]="--prefix=$toolInstallPath --enable-languages= --disable-multilib"
        makeTest[$iPackage]=""

# GSL
iPackage=$(expr $iPackage + 1)
            iGSL=$iPackage
         package[$iPackage]="gsl"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gsl-config"
      getVersion[$iPackage]="gsl-config --version"
      minVersion[$iPackage]="1.13"
      maxVersion[$iPackage]="99.99"
      yumInstall[$iPackage]="gsl-devel"
      aptInstall[$iPackage]="libgsl0-dev gsl-bin"
       sourceURL[$iPackage]="http://www.mirrorservice.org/sites/ftp.gnu.org/gnu/gsl/gsl-1.15.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"

# FGSL
iPackage=$(expr $iPackage + 1)
           iFGSL=$iPackage
         package[$iPackage]="FGSL"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"program dummy; end program\" > dummy.F90; gfortran dummy.F90 $moduleDirs $libDirs -lfgsl_gfortran"
      getVersion[$iPackage]="echo \"program test; use fgsl; write (*,'(a)') fgsl_version; end program\" > dummy.F90; gfortran dummy.F90 $moduleDirs $libDirs -lfgsl_gfortran; ./a.out"
      minVersion[$iPackage]="0.9.2.999"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="null"
      aptInstall[$iPackage]="null"
       sourceURL[$iPackage]="http://www.lrz.de/services/software/mathematik/gsl/fortran/fgsl-0.9.4.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix $toolInstallPath --f90 gfortran"
        makeTest[$iPackage]="test"

# FoX
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="FoX"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"program dummy; end program\" > dummy.F90; gfortran dummy.F90 $moduleDirs $libDirs -lFoX_dom"
      getVersion[$iPackage]="echo \"program test; use FoX_common; write (*,'(a)') FoX_version; end program\" > dummy.F90; gfortran dummy.F90 $moduleDirs $libDirs -lFoX_dom; ./a.out"
      minVersion[$iPackage]="4.0.3.999"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="null"
      aptInstall[$iPackage]="null"
       sourceURL[$iPackage]="http://www1.gly.bris.ac.uk/~walker/FoX/source/FoX-4.1.2-full.tar.gz"
buildEnvironment[$iPackage]="export FC=gfortran"
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"

# Zlib
iPackage=$(expr $iPackage + 1)
           iZLIB=$iPackage
         package[$iPackage]="zlib"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"#include <zlib.h>\" > dummy.c; echo \"main() {}\" >> dummy.c; gcc dummy.c $libDirs -lz"
      getVersion[$iPackage]="echo \"#include <stdio.h>\" > dummy.c; echo \"#include <zlib.h>\" >> dummy.c; echo \"main() {printf(ZLIB_VERSION);printf(\\\"\\\\n\\\");}\" >> dummy.c; gcc dummy.c $libDirs -lz ;./a.out"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="zlib-devel"
      aptInstall[$iPackage]="zlib1g-dev"
       sourceURL[$iPackage]="http://zlib.net/zlib-1.2.5.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"

# HDF5
iPackage=$(expr $iPackage + 1)
           iHDF5=$iPackage
         package[$iPackage]="hdf5"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"program test; use hdf5; end program test\" > dummy.F90; gfortran dummy.F90 $moduleDirs $libDirs -lhdf5"
      getVersion[$iPackage]="echo \"#include <stdio.h>\" > dummy.c; echo \"#include <H5public.h>\" >> dummy.c; echo \"main() {printf(\\\"%d.%d.%d.%d\\\\n\\\",H5_VERS_MAJOR,H5_VERS_MINOR,H5_VERS_RELEASE,H5_VERS_SUBRELEASE);}\" >> dummy.c; gcc dummy.c $libDirs -lhdf5 &> /dev/null;./a.out"
      minVersion[$iPackage]="1.8.0"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="hdf5-devel"
      aptInstall[$iPackage]="hdf5-tools"
       sourceURL[$iPackage]="http://www.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8.8/src/hdf5-1.8.8.tar.gz"
buildEnvironment[$iPackage]="export F9X=gfortran"
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath --enable-fortran --enable-production"
        makeTest[$iPackage]="check"

# GnuPlot
iPackage=$(expr $iPackage + 1)
        iGNUPLOT=$iPackage
         package[$iPackage]="gnuplot"
  packageAtLevel[$iPackage]=1
    testPresence[$iPackage]="hash gnuplot"
      getVersion[$iPackage]="versionString=(\`gnuplot -V\`); echo \${versionString[1]}"
      minVersion[$iPackage]="4.3.999"
      maxVersion[$iPackage]="99.99"
      yumInstall[$iPackage]="gnuplot"
      aptInstall[$iPackage]="gnuplot"
       sourceURL[$iPackage]="http://downloads.sourceforge.net/project/gnuplot/gnuplot/4.4.3/gnuplot-4.4.3.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"

# GraphViz
iPackage=$(expr $iPackage + 1)
       iGRAPHVIZ=$iPackage
         package[$iPackage]="graphviz"
  packageAtLevel[$iPackage]=2
    testPresence[$iPackage]="hash dot"
      getVersion[$iPackage]="versionString=(\`dot -V 2>&1\`); echo \${versionString[4]}"
      minVersion[$iPackage]="2.0.0"
      maxVersion[$iPackage]="99.99"
      yumInstall[$iPackage]="graphviz"
      aptInstall[$iPackage]="graphviz"
       sourceURL[$iPackage]="http://www.graphviz.org/pub/graphviz/stable/SOURCES/graphviz-2.28.0.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"

# ImageMagick
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="ImageMagick"
  packageAtLevel[$iPackage]=2
    testPresence[$iPackage]="hash convert"
      getVersion[$iPackage]="versionString=(\`convert -version 2>&1\`); echo \${versionString[2]}"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99"
      yumInstall[$iPackage]="ImageMagick"
      aptInstall[$iPackage]="imagemagick"
       sourceURL[$iPackage]="ftp://ftp.imagemagick.org/pub/ImageMagick/ImageMagick-6.7.6-1.tar.bz2"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"

# blas
iPackage=$(expr $iPackage + 1)
   iBLAS=$iPackage
         package[$iPackage]="blas"
  packageAtLevel[$iPackage]=2
    testPresence[$iPackage]="echo \"program dummy; end program\" > dummy.F90; gfortran dummy.F90 $moduleDirs $libDirs -lblas"
      getVersion[$iPackage]="echo 1.0.0"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99"
      yumInstall[$iPackage]="blas-devel"
      aptInstall[$iPackage]="libblas-dev"
       sourceURL[$iPackage]="http://netlib.org/blas/blas.tgz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# lapack
iPackage=$(expr $iPackage + 1)
 iLAPACK=$iPackage
         package[$iPackage]="lapack"
  packageAtLevel[$iPackage]=2
    testPresence[$iPackage]="echo \"program dummy; end program\" > dummy.F90; gfortran dummy.F90 $moduleDirs $libDirs -llapack"
      getVersion[$iPackage]="echo \"program dummy; integer major,minor,patch; call ilaver(major,minor,patch); write (*,'(i1,a1,i1,a1,i1)') major,'.',minor,'.',patch; end program\" > dummy.F90; gfortran dummy.F90 -ffree-line-length-none $moduleDirs $libDirs -llapack; ./a.out"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99"
      yumInstall[$iPackage]="lapack-devel"
      aptInstall[$iPackage]="liblapack-dev"
       sourceURL[$iPackage]="http://www.netlib.org/lapack/lapack-3.4.0.tgz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# OpenSSL (required for Bazaar)
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="OpenSSL"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"main() {}\" > dummy.c; gcc dummy.c $libDirs -lssl"
      getVersion[$iPackage]="echo 1.0.0"
      minVersion[$iPackage]="0.9.9"
      maxVersion[$iPackage]="1.0.1"
      yumInstall[$iPackage]="openssl openssl-devel"
      aptInstall[$iPackage]="openssl libssl-dev"
       sourceURL[$iPackage]="http://www.openssl.org/source/openssl-1.0.0d.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath shared"
        makeTest[$iPackage]=""

# bzip2 (required for Bazaar)
iPackage=$(expr $iPackage + 1)
              iBZIP2=$iPackage
         package[$iPackage]="bzip2"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"main() {}\" > dummy.c; gcc dummy.c $libDirs -lbz2"
      getVersion[$iPackage]="echo 1.0.0"
      minVersion[$iPackage]="0.9.9"
      maxVersion[$iPackage]="1.0.1"
      yumInstall[$iPackage]="bzip2 bzip2-devel bzip2-libs"
      aptInstall[$iPackage]="bzip2 libbz2-dev"
       sourceURL[$iPackage]="http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="skip"
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="PREFIX=$toolInstallPath"

# Python
iPackage=$(expr $iPackage + 1)
         iPYTHON=$iPackage
         package[$iPackage]="python"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash python && hash python-config"
      getVersion[$iPackage]="versionString=(\`python -V 2>&1\`); echo \${versionString[1]}"
      minVersion[$iPackage]="2.3.999"
      maxVersion[$iPackage]="99.99"
      yumInstall[$iPackage]="python"
      aptInstall[$iPackage]="python python-dev"
       sourceURL[$iPackage]="http://www.python.org/ftp/python/2.7.2/Python-2.7.2.tgz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="test"

# cElementTree (required for Bazaar)
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="cElementTree"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="python -c 'import xml.etree.cElementTree'"
      getVersion[$iPackage]="echo 1.0.0"
      minVersion[$iPackage]="0.9.9"
      maxVersion[$iPackage]="1.1.1"
      yumInstall[$iPackage]="python-celementtree"
      aptInstall[$iPackage]="null"
       sourceURL[$iPackage]="http://effbot.org/media/downloads/cElementTree-1.0.5-20051216.tar.gz"
buildEnvironment[$iPackage]="python"
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# Pyrex (required for Bazaar)
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="Pyrex"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="python -c 'import Pyrex'"
      getVersion[$iPackage]="echo 1.0.0"
      minVersion[$iPackage]="0.9.9"
      maxVersion[$iPackage]="1.1.1"
      yumInstall[$iPackage]="Pyrex"
      aptInstall[$iPackage]="python-pyrex"
       sourceURL[$iPackage]="http://www.cosc.canterbury.ac.nz/greg.ewing/python/Pyrex/Pyrex-0.9.9.tar.gz"
buildEnvironment[$iPackage]="python"
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# pycrypto (required for Bazaar)
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="pycrypto"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="python -c 'import Crypto'"
      getVersion[$iPackage]="echo 1.0.0"
      minVersion[$iPackage]="0.9.9"
      maxVersion[$iPackage]="1.1.1"
      yumInstall[$iPackage]="python-crypto"
      aptInstall[$iPackage]="python-crypto"
       sourceURL[$iPackage]="http://ftp.dlitz.net/pub/dlitz/crypto/pycrypto/pycrypto-2.3.tar.gz"
buildEnvironment[$iPackage]="python"
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# paramiko (required for Bazaar)
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="paramiko"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="python -c 'import paramiko'"
      getVersion[$iPackage]="echo 1.0.0"
      minVersion[$iPackage]="0.9.9"
      maxVersion[$iPackage]="1.1.1"
      yumInstall[$iPackage]="python-paramiko"
      aptInstall[$iPackage]="python-paramiko"
       sourceURL[$iPackage]="http://www.lag.net/paramiko/download/paramiko-1.7.7.1.tar.gz"
buildEnvironment[$iPackage]="python"
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# bzr
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="bzr"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash bzr"
      getVersion[$iPackage]="versionString=(\`bzr --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]="2.0.0"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="bzr"
      aptInstall[$iPackage]="bzr"
       sourceURL[$iPackage]="http://launchpad.net/bzr/2.4/2.4b5/+download/bzr-2.4b5.tar.gz"
buildEnvironment[$iPackage]="python"
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# bzrtools
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="bzrtools"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="bzr plugins | grep bzrtools"
      getVersion[$iPackage]="versionString=(\`bzr plugins | grep bzrtools\`); echo \${versionString[1]}"
      minVersion[$iPackage]="2.0.0"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="bzrtools"
      aptInstall[$iPackage]="bzrtools"
       sourceURL[$iPackage]="http://launchpad.net/bzrtools/stable/2.4.0/+download/bzrtools-2.4.0.tar.gz"
buildEnvironment[$iPackage]="python"
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# pdflatex
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="pdflatex"
  packageAtLevel[$iPackage]=1
    testPresence[$iPackage]="hash pdflatex"
      getVersion[$iPackage]="echo 1.0.0"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99"
      yumInstall[$iPackage]="texlive-latex"
      aptInstall[$iPackage]="texlive-latex-base"
       sourceURL[$iPackage]="fail:"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# pdfmerge
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="pdfmerge"
  packageAtLevel[$iPackage]=1
    testPresence[$iPackage]="hash pdfmerge"
      getVersion[$iPackage]="echo 1.0.0"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99"
      yumInstall[$iPackage]="pdfmerge"
      aptInstall[$iPackage]=""
       sourceURL[$iPackage]="http://dmaphy.github.com/pdfmerge/pdfmerge-1.0.4.tar.bz2"
buildEnvironment[$iPackage]="copy"
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""

# Install packages.
echo "Checking for required tools and libraries..." 
echo "Checking for required tools and libraries..." >> $glcLogFile

for (( i = 0 ; i < ${#package[@]} ; i++ ))
do
    # Test if this module should be installed at this level.
    if [ ${packageAtLevel[$i]} -le $installLevel ]; then
        # Check if package is installed.
	echo " Testing presence of ${package[$i]}" >> $glcLogFile
        installPackage=1
        eval ${testPresence[$i]} >>$glcLogFile 2>&1
        if [ $? -eq 0 ]; then
            # Check installed version.
	    echo "  ${package[$i]} is present - testing version" >> $glcLogFile
            version=`eval ${getVersion[$i]}` >>$glcLogFile 2>&1
	    echo "  Found version $version of ${package[$i]}" >> $glcLogFile
	    testLow=`echo "$version test:${minVersion[$i]}:${maxVersion[$i]}" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
	    testHigh=`echo "$version test:${minVersion[$i]}:${maxVersion[$i]}" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
	    if [[ "$testLow" != "test" && "$testHigh" != "test" ]]; then
	        installPackage=0
	    fi
	    echo "  Test results for ${package[$i]}: $testLow $testHigh" >> $glcLogFile
        fi
        # Install package if necessary.
        if [ $installPackage -eq 0 ]; then
	    echo ${package[$i]} - found
	    echo ${package[$i]} - found >> $glcLogFile
        else
	    echo ${package[$i]} - not found - will be installed
	    echo ${package[$i]} - not found - will be installed >> $glcLogFile
	    installDone=0
	    # Try installing via yum.
	    if [[ $installDone -eq 0 && $installViaYum -eq 1 && ${yumInstall[$i]} != "null" ]]; then
                # Check for presence in yum repos.
		for yumPackage in ${yumInstall[$i]}
		do
		    if [ $installDone -eq 0 ]; then
			versionString=(`echo "$rootPassword" | eval $suCommand yum -q -y list $yumPackage $suClose | tail -1`)
			if [ $? -eq 0 ]; then
			    version=${versionString[1]}
			    testLow=`echo "$version test:${minVersion[$i]}:${maxVersion[$i]}" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
			    testHigh=`echo "$version test:${minVersion[$i]}:${maxVersion[$i]}" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
			    if [[ "$testLow" != "test" && "$testHigh" != "test" ]]; then
				echo "   Installing via yum"
				echo "   Installing via yum" >> $glcLogFile
				echo "$rootPassword" | eval $suCommand yum -y install $yumPackage $suClose >>$glcLogFile 2>&1
				if ! eval ${testPresence[$i]} >& /dev/null; then
				    echo "   ...failed"
				    exit 1
				fi
				installDone=1
			    fi
			fi
		    fi
		done
            fi 
	    # Try installing via apt-get.
	    if [[ $installDone -eq 0 &&  $installViaApt -eq 1 && ${aptInstall[$i]} != "null" ]]; then
                # Check for presence in apt repos.
		aptPackages=(${aptInstall[$i]})
		for aptPackage in ${aptInstall[$i]}
		do
		    if [ $installDone -eq 0 ]; then
                        packageInfo=`apt-cache show $aptPackage`
			if [ $? -eq 0 ]; then
			    versionString=(`apt-cache show $aptPackage | sed -n '/Version/p' | sed -r s/"[0-9]+:"//`)
			    version=${versionString[1]}
			    testLow=`echo "$version test:${minVersion[$i]}:${maxVersion[$i]}" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
			    testHigh=`echo "$version test:${minVersion[$i]}:${maxVersion[$i]}" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
			    if [[ "$testLow" != "test" && "$testHigh" != "test" ]]; then
				echo "   Installing via apt-get"
				echo "   Installing via apt-get" >> $glcLogFile
				echo "$rootPassword" | eval $suCommand apt-get -y install $aptPackage $suClose >>$glcLogFile 2>&1
				if ! eval ${testPresence[$i]} >& /dev/null; then
				    echo "   ...failed"
				    exit 1
				fi
				installDone=1
			    fi
			fi
		    fi
		done
	    fi
	    # Try installing via source.
	    if [[ $installDone -eq 0 && ${sourceURL[$i]} != "null" ]]; then
		if [[ ${sourceURL[$i]} =~ "fail:" ]]; then
		    echo "This installer can not currently install ${package[$i]} from source. Please install manually and then re-run this installer."
		    exit 1
		else
		    echo "   Installing from source"
		    echo "   Installing from source" >>$glcLogFile
		    if [[ ${sourceURL[$i]} =~ "svn:" ]]; then
			svn checkout "${sourceURL[$i]}" >>$glcLogFile 2>&1
		    else
			wget "${sourceURL[$i]}" >>$glcLogFile 2>&1
		    fi
		    if [ $? -ne 0 ]; then
			echo "Could not download ${package[$i]}"
			echo "Could not download ${package[$i]}" >>$glcLogFile
			exit 1
		    fi
		    baseName=`basename ${sourceURL[$i]}`
		    if [[ ${sourceURL[$i]} =~ "svn:" ]]; then  
			dirName=$baseName
		    else
			unpack=`echo $baseName | sed -e s/.*\.bz2/j/ -e s/.*\.gz/z/ -e s/.*\.tgz/z/ -e s/.*\.tar//`
			tar xvf$unpack $baseName >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    echo "Could not unpack ${package[$i]}"
			    echo "Could not unpack ${package[$i]}" >>$glcLogFile
			    exit 1
			fi
			dirName=`tar tf$unpack $baseName | head -1 | sed s/"\/.*"//`
		    fi
		    if [ ${buildInOwnDir[$i]} -eq 1 ]; then
			mkdir -p $dirName-build
			cd $dirName-build
		    else
			cd $dirName
		    fi
   		    # Check for Python package.
		    if [ -z "${buildEnvironment[$i]}" ]; then
			isPython=0
			isPerl=0
			isCopy=0
		    else
			if [ "${buildEnvironment[$i]}" = "python" ]; then
			    isPython=1
			else
			    isPython=0
			fi
			if [ "${buildEnvironment[$i]}" = "perl" ]; then
			    isPerl=1
			else
			    isPerl=0
			fi
			if [ "${buildEnvironment[$i]}" = "copy" ]; then
			    isCopy=1
			else
			    isCopy=0
			fi
		    fi
		    if [ $isPython -eq 1 ]; then
		        # This is a Python package.
			if [ $installAsRoot -eq 1 ]; then
			    # Install Python package as root.
			    echo "$rootPassword" | $suCommand python setup.py install $suClose >>$glcLogFile 2>&1
			else
                            # Check that we have a virtual Python install
			    if [ ! -e $toolInstallPath/bin/python ]; then
				wget http://peak.telecommunity.com/dist/virtual-python.py >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed to download virtual-python.py"
				    echo "Failed to download virtual-python.py" >>$glcLogFile
				    exit 1
				fi
                                # Check if there is a site-packages folder.
				virtualPythonOptions=" "
				pythonSitePackages=`python -c "import sys, os; py_version = 'python%s.%s' % (sys.version_info[0], sys.version_info[1]); print os.path.join(sys.prefix, 'lib', py_version,'site-packages')"`
				if [ ! -e $pythonSitePackages ]; then
				    virtualPythonOptions="$virtualPythonOptions --no-site-packages"
				    echo "No Python site-packages found - will run virtual-python.py with --no-site-packages options" >>$glcLogFile 2>&1
				fi
				python virtual-python.py --prefix $toolInstallPath $virtualPythonOptions >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed to install virtual-python.py"
				    echo "Failed to install virtual-python.py" >>$glcLogFile
				    exit 1
				fi
				wget http://peak.telecommunity.com/dist/ez_setup.py >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed to download ez_setup.py"
				    echo "Failed to download ez_setup.py" >>$glcLogFile
				    exit 1
				fi
				$toolInstallPath/bin/python ez_setup.py >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed to install ez_setup.py"
				    echo "Failed to install ez_setup.py" >>$glcLogFile
				    exit 1
				fi
			    fi
			    # Install Python package as regular user.
			    $toolInstallPath/bin/python setup.py install --prefix=$toolInstallPath >>$glcLogFile 2>&1
			fi
		        # Check that install succeeded.
			if [ $? -ne 0 ]; then
			    echo "Could not install ${package[$i]}"
			    echo "Could not install ${package[$i]}" >>$glcLogFile
			    exit 1
			fi
		    elif [ $isCopy -eq 1 ]; then
		        # This is a package that we simply copy.
			if [ $installAsRoot -eq 1 ]; then
			    # Copy executable as root.
			    echo "$rootPassword" | $suCommand cp ${package[$i]} $toolInstallPath/bin/ $suClose >>$glcLogFile 2>&1
			else
			    # Copy executable as regular user.
			    cp ${package[$i]} $toolInstallPath/bin/ >>$glcLogFile 2>&1
			fi
		    elif [[ $i -eq $iBLAS ]]; then
			patch -p1 <<EOF
*** BLAS/make.inc       2011-04-19 12:08:00.000000000 -0700
--- BLAS1/make.inc      2011-12-01 07:24:51.671999364 -0800
***************
*** 16,24 ****
  #  desired load options for your machine.
  #
  FORTRAN  = gfortran
! OPTS     = -O3
  DRVOPTS  = \$(OPTS)
! NOOPT    =
  LOADER   = gfortran
  LOADOPTS =
  #
--- 16,24 ----
  #  desired load options for your machine.
  #
  FORTRAN  = gfortran
! OPTS     = -O3 -fPIC
  DRVOPTS  = \$(OPTS)
! NOOPT    = -fPIC
  LOADER   = gfortran
  LOADOPTS =
  #
EOF
                        if [ $? -ne 0 ]; then
			    echo "Failed to patch make.inc in blas"
			    echo "Failed to patch make.inc in blas" >>$glcLogFile
			    exit 1
			fi
			patch -p1 <<EOF
*** BLAS/Makefile       2007-04-05 13:59:57.000000000 -0700
--- BLAS1/Makefile      2011-12-01 07:23:50.768481902 -0800
***************
*** 55,61 ****
  #
  #######################################################################
  
! all: \$(BLASLIB)
   
  #---------------------------------------------------------
  #  Comment out the next 6 definitions if you already have
--- 55,61 ----
  #
  #######################################################################
  
! all: \$(BLASLIB) libblas.so
   
  #---------------------------------------------------------
  #  Comment out the next 6 definitions if you already have
***************
*** 141,146 ****
--- 141,149 ----
        \$(ARCH) \$(ARCHFLAGS) \$@ \$(ALLOBJ)
        \$(RANLIB) \$@
  
+ libblas.so: \$(ALLOBJ)
+@X@cc -shared -Wl,-soname,libblas.so -o libblas.so \$(ALLOBJ)
+ 
  single: \$(SBLAS1) \$(ALLBLAS) \$(SBLAS2) \$(SBLAS3)
        \$(ARCH) \$(ARCHFLAGS) \$(BLASLIB) \$(SBLAS1) \$(ALLBLAS) \\
        \$(SBLAS2) \$(SBLAS3)
EOF
	                if [ $? -ne 0 ]; then
			    echo "Failed to patch Makefile in blas"
			    echo "Failed to patch Makefile in blas" >>$glcLogFile
			    exit 1
			fi
			sed -i~ -r s/"@X@"/"\t"/g Makefile >>$glcLogFile 2>&1
			make libblas.so >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    echo "Failed to make libblas.so"
			    echo "Failed to make libblas.so" >>$glcLogFile
			    exit 1
			fi
			mkdir -p $toolInstallPath/lib/ >>$glcLogFile 2>&1
			cp -f libblas.so $toolInstallPath/lib/ >>$glcLogFile 2>&1
		    elif [[ $i -eq $iLAPACK ]]; then
			if [ ! -e $toolInstallPath/lib/libblas.so ]; then
			    echo "Source install of lapack currently supported only if blas was also installed from source"
			    echo "Source install of lapack currently supported only if blas was also installed from source" >>$glcLogFile
			    exit 1
			fi
			cp make.inc.example make.inc >>$glcLogFile 2>&1
			patch -p1 <<EOF
*** lapack-3.4.0/make.inc       2011-12-01 07:47:04.696001005 -0800
--- lapack-3.4.0A/make.inc      2011-12-01 07:53:10.866744759 -0800
***************
*** 13,21 ****
  #  desired load options for your machine.
  #
  FORTRAN  = gfortran 
! OPTS     = -O2
  DRVOPTS  = \$(OPTS)
! NOOPT    = -O0
  LOADER   = gfortran
  LOADOPTS =
  #
--- 13,21 ----
  #  desired load options for your machine.
  #
  FORTRAN  = gfortran 
! OPTS     = -O2 -fPIC
  DRVOPTS  = \$(OPTS)
! NOOPT    = -O0 -fPIC
  LOADER   = gfortran
  LOADOPTS =
  #
***************
*** 53,58 ****
  #  machine-specific, optimized BLAS library should be used whenever
  #  possible.)
  #
! BLASLIB      = ../../librefblas.a
! LAPACKLIB    = liblapack.a
! TMGLIB       = libtmglib.a
--- 53,58 ----
  #  machine-specific, optimized BLAS library should be used whenever
  #  possible.)
  #
! BLASLIB      = ../../librefblas.so
! LAPACKLIB    = liblapack.so
! TMGLIB       = libtmglib.so
EOF
                       if [ $? -ne 0 ]; then
			   echo "Failed to patch make.inc in lapack"
			   echo "Failed to patch make.inc in lapack" >>$glcLogFile
			   exit 1
		       fi
		       echo s\#BLASLIB\\s*=\\s*..\\/..\\/librefblas.so\#BLASLIB = $toolInstallPath\\/lib\\/libblas.so\# > rule.sed
		       sed -i~ -r -f rule.sed make.inc >>$glcLogFile 2>&1
		       if [ $? -ne 0 ]; then
			   echo "Failed to modify blas path in make.inc in lapack"
			   echo "Failed to modify blas path in make.inc in lapack" >>$glcLogFile
			   exit 1
		       fi
		       rm -f rule.sed
		       make >>$glcLogFile 2>&1
		       if [ $? -ne 0 ]; then
			   echo "Failed to make lapack"
			   echo "Failed to make lapack" >>$glcLogFile
			   exit 1
		       fi
		       mkdir -p $toolInstallPath/lib/ >>$glcLogFile 2>&1
		       cp -f liblapack.so $toolInstallPath/lib/ >>$glcLogFile 2>&1
		       cp -f libtmglib.so $toolInstallPath/lib/ >>$glcLogFile 2>&1
		    else
                        # This is a regular (configure|make|make install) package.
                        # Test whether we have an m4 installed.
			hash m4 >& /dev/null
			if [ $? -ne 0 ]; then
			    echo "No m4 is present - will attempt to install prior to configuring"
			    echo "No m4 is present - will attempt to install prior to configuring" >>$glcLogFile
			    m4InstallDone=0
			    # Try installing via yum.
			    if [[ $m4InstallDone -eq 0 && $installViaYum -eq 1 ]]; then
				echo "$rootPassword" | $suCommand yum -y install m4 $suClose >>$glcLogFile 2>&1
				hash m4 >& /dev/null
				if [ $? -ne 0 ]; then
				    m4InstallDone=1
				fi
			    fi
			    # Try installing via apt-get.
			    if [[ $m4InstallDone -eq 0 && $installViaApt -eq 1 ]]; then
				echo "$rootPassword" | $suCommand apt-get -y install m4 $suClose >>$glcLogFile 2>&1
				hash m4 >& /dev/null
				if [ $? -ne 0 ]; then
				    m4InstallDone=1
				fi
			    fi
			    # Try installing from source.
			    if [[ $m4InstallDone -eq 0 ]]; then
				currentDir=`pwd`
				cd ..
				wget http://ftp.gnu.org/gnu/m4/m4-1.4.16.tar.gz >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed to download m4 source"
				    echo "Failed to download m4 source" >>$glcLogFile
				    exit 1
				fi
				tar xvfz m4-1.4.16.tar.gz >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed to unpack m4 source"
				    echo "Failed to unpack m4 source" >>$glcLogFile
				    exit 1
				fi
				cd m4-1.4.16
				./configure --prefix=$toolInstallPath >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed to configure m4 source"
				    echo "Failed to configure m4 source" >>$glcLogFile
				    exit 1
				fi
				make >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed to make m4"
				    echo "Failed to make m4" >>$glcLogFile
				    exit 1
				fi
				make check >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed to check m4"
				    echo "Failed to check m4" >>$glcLogFile
				    exit 1
				fi
				make install >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed to install m4"
				    echo "Failed to install m4" >>$glcLogFile
				    exit 1
				fi
				cd $currentDir
			    fi
			fi
		        # Configure the source.
			if [ $isPerl -eq 1 ]; then
			    if [ -e ../$dirName/Makefile.PL ]; then
				if [ $installAsRoot -eq 1 ]; then
				    perl ../$dirName/Makefile.PL >>$glcLogFile 2>&1
				else
				    perl ../$dirName/Makefile.PL PREFIX=$toolInstallPath >>$glcLogFile 2>&1
				fi
			    else
				echo "Can not locate Makefile.PL for ${package[$i]}"
				echo "Can not locate Makefile.PL for ${package[$i]}" >>$glcLogFile
				exit 1
			    fi
			    if [ $? -ne 0 ]; then
				echo "Could not build Makefile for ${package[$i]}"
				echo "Could not build Makefile for ${package[$i]}" >>$glcLogFile
				exit 1
			    fi
			else
			    eval ${buildEnvironment[$i]}
			    if [ -e ../$dirName/configure ]; then
				../$dirName/configure ${configOptions[$i]} >>$glcLogFile 2>&1
			    elif [ -e ../$dirName/config ]; then
				../$dirName/config ${configOptions[$i]} >>$glcLogFile 2>&1
			    elif [[ ${configOptions[$i]} -ne "skip" ]]; then
				echo "Can not locate configure script for ${package[$i]}"
				echo "Can not locate configure script for ${package[$i]}" >>$glcLogFile
				exit 1
			    fi
			    if [ $? -ne 0 ]; then
				echo "Could not configure ${package[$i]}"
				echo "Could not configure ${package[$i]}" >>$glcLogFile
				exit 1
			    fi
			fi
		        # Make the package.
			make >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    echo "Could not make ${package[$i]}"
			    echo "Could not make ${package[$i]}" >>$glcLogFile
			    exit 1
			fi
		        # Run any tests of the package.
			make ${makeTest[$i]} >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    echo "Testing ${package[$i]} failed"
			    echo "Testing ${package[$i]} failed" >>$glcLogFile
			    exit 1
			fi
		        # Install the package.
			if [ $installAsRoot -eq 1 ]; then
			    echo "$rootPassword" | eval $suCommand make install ${makeInstall[$i]} $suClose >>$glcLogFile 2>&1
			else
			    make install ${makeInstall[$i]} >>$glcLogFile 2>&1
			fi
			if [ $? -ne 0 ]; then
			    echo "Could not install ${package[$i]}"
			    echo "Could not install ${package[$i]}" >>$glcLogFile
			    exit 1
			fi
                        # Hardwired magic.
                        # For bzip2 we have to compile and install shared libraries manually......
			if [ $i -eq $iBZIP2 ]; then
 			    if [ $installAsRoot -eq 1 ]; then
				echo "$rootPassword" | eval $suCommand make clean $suClose >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed building shared libraries for ${package[$i]} at stage 1"
				    echo "Failed building shared libraries for ${package[$i]} at stage 1" >>$glcLogFile
				    exit 1
				fi
				echo "$rootPassword" | eval $suCommand make -f Makefile-libbz2_so $suClose >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed building shared libraries for ${package[$i]} at stage 2"
				    echo "Failed building shared libraries for ${package[$i]} at stage 2" >>$glcLogFile
				    exit 1
				fi
				echo "$rootPassword" | eval $suCommand cp libbz2.so* $toolInstallPath/lib/ $suClose >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed building shared libraries for ${package[$i]} at stage 3"
				    echo "Failed building shared libraries for ${package[$i]} at stage 3" >>$glcLogFile
				    exit 1
				fi
				echo "$rootPassword" | eval $suCommand chmod a+r $toolInstallPath/lib/libbz2.so* $suClose >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed building shared libraries for ${package[$i]} at stage 4"
				    echo "Failed building shared libraries for ${package[$i]} at stage 4" >>$glcLogFile
				    exit 1
				fi
			    else
				make clean >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed building shared libraries for ${package[$i]} at stage 1"
				    echo "Failed building shared libraries for ${package[$i]} at stage 1" >>$glcLogFile
				    exit 1
				fi
				make -f Makefile-libbz2_so >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed building shared libraries for ${package[$i]} at stage 2"
				    echo "Failed building shared libraries for ${package[$i]} at stage 2" >>$glcLogFile
				    exit 1
				fi
				cp libbz2.so* $toolInstallPath/lib/ >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed building shared libraries for ${package[$i]} at stage 3"
				    echo "Failed building shared libraries for ${package[$i]} at stage 3" >>$glcLogFile
				    exit 1
				fi
				chmod a+r $toolInstallPath/lib/libbz2.so*  >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    echo "Failed building shared libraries for ${package[$i]} at stage 4"
				    echo "Failed building shared libraries for ${package[$i]} at stage 4" >>$glcLogFile
				    exit 1
				fi
			    fi
			fi
		    fi
		fi
		cd ..
		# Re-export the PATH so that the newly installed executable gets picked up.
		export PATH=$PATH
		installDone=1
            fi
	    # No install methods worked - nothing else we can do (unless this was an
	    # initial attempt at installed a GNU compiler).
	    if [[ $installDone -eq 0 ]]; then
		echo "   no installation method exists"
		echo "   no installation method exists" >>$glcLogFile
		if [[ $i -eq $iFortran || $i -eq $iGCC || $i -eq $iGPP ]]; then
		    echo "      postponing"
		    echo "      postponing" >>$glcLogFile
		else
		    exit 1
		fi
            fi
	fi
        # Hardwired magic.        
	# If we installed (or already had) v1.13 or v1.14 of GSL then downgrade the version of FGSL that we want.
	if [ $i -eq $iGSL ]; then
	    gslVersion=`gsl-config --version`
	    if [ $gslVersion = "1.13" ]; then
		minVersion[$iFGSL]="0.9.1.9"
		maxVersion[$iFGSL]="0.9.2.1"
		sourceURL[$iFGSL]="http://www.lrz.de/services/software/mathematik/gsl/fortran/fgsl-0.9.2.tar.gz"
	    fi
	    if [ $gslVersion = "1.14" ]; then
		minVersion[$iFGSL]="0.9.2.9"
		maxVersion[$iFGSL]="0.9.3.1"
		sourceURL[$iFGSL]="http://www.lrz.de/services/software/mathematik/gsl/fortran/fgsl-0.9.3.tar.gz"
	    fi
	fi
	# Hardwired magic.
	# If we installed SQLite, force SVN to use it.
	if [ $i -eq $iSQLite ]; then
	    configOptions[$iSVN]="${configOptions[$iSVN]} --with-sqlite=$toolInstallPath"
	fi
        # Hardwired magic.        
        # Check if GCC/G++/Fortran are installed - delist MPFR, GMP and MPC if so.
	if [ $i -eq $iFortran ]; then
	    eval ${testPresence[$iFortran]} >& /dev/null
	    gotFortran=$?
	    eval ${testPresence[$iGCC]} >& /dev/null
	    gotGCC=$?
	    eval ${testPresence[$iGPP]} >& /dev/null
	    gotGPP=$?
	    if [[ $gotFortran -eq 0 && $gotGCC -eq 0 && $gotGPP -eq 0 ]]; then
                # Check installed versions.
		version=`eval ${getVersion[$iFortran]}`
		testLow=`echo "$version test:${minVersion[$iFortran]}:${maxVersion[$iFortran]}" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
		testHigh=`echo "$version test:${minVersion[$iFortran]}:${maxVersion[$iFortran]}" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
		if [[ "$testLow" = "test" || "$testHigh" = "test" ]]; then
		    gotFortran=1
		fi
		version=`eval ${getVersion[$iGCC]}`
		testLow=`echo "$version test:${minVersion[$iGCC]}:${maxVersion[$iGCC]}" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
		testHigh=`echo "$version test:${minVersion[$iGCC]}:${maxVersion[$iGCC]}" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
		if [[ "$testLow" = "test" || "$testHigh" = "test" ]]; then
		    gotGCC=1
		fi
		version=`eval ${getVersion[$iGPP]}`
		testLow=`echo "$version test:${minVersion[$iGPP]}:${maxVersion[$iGPP]}" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
		testHigh=`echo "$version test:${minVersion[$iGPP]}:${maxVersion[$iGPP]}" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
		if [[ "$testLow" = "test" || "$testHigh" = "test" ]]; then
		    gotGPP=1
		fi
	    fi
	    if [[ $gotFortran -eq 0 && $gotGCC -eq 0 && $gotGPP -eq 0 ]]; then
		# We have all GNU Compiler Collection components, so we don't need svn, GMP, MPFR or MPC.
		packageAtLevel[$iSQLite]=100
		packageAtLevel[$iAPR]=100
		packageAtLevel[$iAPRutil]=100
		packageAtLevel[$iSVN]=100
		packageAtLevel[$iGMP]=100
		packageAtLevel[$iMPFR]=100
		packageAtLevel[$iMPC]=100
	    else
		# We will need to install some GNU Compiler Collection components.
		# Select those components now.
		if [ $gotFortran -ne 0 ]; then
		    configOptions[$iFortranSource]=`echo ${configOptions[$iFortranSource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=fortran,"/ | sed -r s/", "/" "/`
		    configOptions[$iGCCsource]=`echo ${configOptions[$iGCCsource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=fortran,"/ | sed -r s/", "/" "/`
		    configOptions[$iGPPsource]=`echo ${configOptions[$iGPPsource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=fortran,"/ | sed -r s/", "/" "/`
		fi
		if [ $gotGCC -ne 0 ]; then
		    configOptions[$iFortranSource]=`echo ${configOptions[$iFortranSource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=c,"/ | sed -r s/", "/" "/`
		    configOptions[$iGCCsource]=`echo ${configOptions[$iGCCsource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=c,"/ | sed -r s/", "/" "/`
		    configOptions[$iGPPsource]=`echo ${configOptions[$iGPPsource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=c,"/ | sed -r s/", "/" "/`
		fi
		if [ $gotGPP -ne 0 ]; then
		    configOptions[$iFortranSource]=`echo ${configOptions[$iFortranSource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=c++,"/ | sed -r s/", "/" "/`
		    configOptions[$iGCCsource]=`echo ${configOptions[$iGCCsource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=c++,"/ | sed -r s/", "/" "/`
		    configOptions[$iGPPsource]=`echo ${configOptions[$iGPPsource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=c++,"/ | sed -r s/", "/" "/`
		fi
                # Hardwired magic.
                # On Ubuntu, we need to ensure that gcc-multilib is installed so that we can compile the gcc compilers.
		uname -v | grep -i ubuntu >& /dev/null
		if [ $? -eq 0 ]; then
		    if [ ! -e /usr/include/asm/errno.h ]; then
                        # gcc-multilib is not installed. If we don't have root access, we have a problem.
			if [ $installAsRoot -eq 1 ]; then
			    echo "$rootPassword" | eval $suCommand apt-get -y install gcc-multilib $suClose >>$glcLogFile 2>&1
			    if [ ! -e /usr/include/asm/errno.h ]; then
				echo "Failed to install gcc-multilib needed for compiling GNU Compiler Collection."
				echo "Failed to install gcc-multilib needed for compiling GNU Compiler Collection." >>$glcLogFile
				exit 1
			    fi
			else
			    echo "I need to compiler some of the GNU Compiler Collection."
			    echo "That requires that gcc-multilib be installed which requires root access."
			    echo "Please do: sudo apt-get install gcc-multilib"
			    echo "or ask your sysadmin to install it for you if necessary, then run this script again."
			    echo "I need to compiler some of the GNU Compiler Collection." >>$glcLogFile
			    echo "That requires that gcc-multilib be installed which requires root access." >>$glcLogFile
			    echo "Please do: sudo apt-get install gcc-multilib" >>$glcLogFile
			    echo "or ask your sysadmin to install it for you if necessary, then run this script again." >>$glcLogFile
			    exit 1
			fi
		    fi
		fi
		
	    fi
	fi
        # Hardwired magic.
        # If we installed GMP from source then let MPFR and the GNU Compiler Collection know about it.
	if [ $i -eq $iGMP ]; then
	    if [ -e $toolInstallPath/lib/libgmp.so ]; then
		configOptions[$iMPFR]="${configOptions[$iMPFR]} --with-gmp=$toolInstallPath"
		configOptions[$iMPC]="${configOptions[$iMPC]} --with-gmp=$toolInstallPath"
		configOptions[$iGCCsource]="${configOptions[$iGCCsource]} --with-gmp=$toolInstallPath"
		configOptions[$iGPPsource]="${configOptions[$iGPPsource]} --with-gmp=$toolInstallPath"
		configOptions[$iFortranSource]="${configOptions[$iFortranSource]} --with-gmp=$toolInstallPath"
	    fi
	fi
        # Hardwired magic.
        # If we installed MPFR from source then let the GNU Compiler Collection know about it.
	if [ $i -eq $iMPFR ]; then
	    if [ -e $toolInstallPath/lib/libmpfr.so ]; then
		configOptions[$iMPC]="${configOptions[$iMPC]} --with-mpfr=$toolInstallPath"
		configOptions[$iGCCsource]="${configOptions[$iGCCsource]} --with-mpfr=$toolInstallPath"
		configOptions[$iGPPsource]="${configOptions[$iGPPsource]} --with-mpfr=$toolInstallPath"
		configOptions[$iFortranSource]="${configOptions[$iFortranSource]} --with-mpfr=$toolInstallPath"
	    fi
	fi
        # Hardwired magic.
        # If we installed MPC from source then let the GNU Compiler Collection know about it.
	if [ $i -eq $iMPC ]; then
	    if [ -e $toolInstallPath/lib/libmpc.so ]; then
		configOptions[$iGCCsource]="${configOptions[$iGCCsource]} --with-mpc=$toolInstallPath"
		configOptions[$iGPPsource]="${configOptions[$iGPPsource]} --with-mpc=$toolInstallPath"
		configOptions[$iFortranSource]="${configOptions[$iFortranSource]} --with-mpc=$toolInstallPath"
	    fi
	fi
        # Hardwired magic.
        # If we installed GSL from source then set a suitable configure option for FGSL.
	if [ $i -eq $iGSL ]; then
	    if [ -e $toolInstallPath/lib/libgsl.so ]; then
		configOptions[$iFGSL]="${configOptions[$iFGSL]} --gsl $toolInstallPath" 
	    fi
	fi
        # Hardwired magic.
        # If we installed GFortran from source, don't allow HDF5 installs via yum or apt.
        # We need to build it from source to ensure we make the correct module version.
	if [ $i -eq $iFortran ]; then
	    if [ -e $toolInstallPath/bin/gfortran ]; then
		yumInstall[iHDF5]="null"
		aptInstall[iHDF5]="null"
	    fi
	fi
        # Hardwired magic.
        # If we installed GCC or G++ from source, don't allow other installs via yum or apt.
	if [ $i -eq $iFortran ]; then
	    if [[ -e $toolInstallPath/bin/gcc || -e $toolInstallPath/bin/g++ ]]; then
		yumInstall[iGSL]="null"
		aptInstall[iGSL]="null"
		yumInstall[iZLIB]="null"
		aptInstall[iZLIB]="null"
		yumInstall[iHDF5]="null"
		aptInstall[iHDF5]="null"
		yumInstall[iGNUPLOT]="null"
		aptInstall[iGNUPLOT]="null"
		yumInstall[iGRAPHVIZ]="null"
		aptInstall[iGRAPHVIZ]="null"
		yumInstall[iPYTHON]="null"
		aptInstall[iPYTHON]="null"
	    fi
	fi
    fi
done

# Specify the list of Perl modules and their requirements.
gotPerlLocalLibEnv=0
iPackage=-1
# CPAN
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="CPAN"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-CPAN"
    modulesApt[$iPackage]="perl-modules"
   interactive[$iPackage]=0

# Text::Table
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Text::Table"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Text-Table"
    modulesApt[$iPackage]="libtext-table-perl"
   interactive[$iPackage]=0

# Text::Wrap
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Text::Wrap"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]=""
    modulesApt[$iPackage]=""
   interactive[$iPackage]=0

# Sort::Topological
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Sort::Topological"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# LaTeX::Encode
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="LaTeX::Encode"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="liblatex-encode-perl"
   interactive[$iPackage]=0

# File::Find
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Find"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# File::Which
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Which"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-File-Which"
    modulesApt[$iPackage]="libfile-which-perl"
   interactive[$iPackage]=0

# File::Copy
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Copy"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# IO::Compress::Bzip2
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="IO::Compress::Bzip2"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Compress-Bzip2"
    modulesApt[$iPackage]="libcompress-bzip2-perl"
   interactive[$iPackage]=0

# Term::ReadKey
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Term::ReadKey"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-TermReadKey"
    modulesApt[$iPackage]="libterm-readkey-perl"
   interactive[$iPackage]=0

# Math::SigFigs
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Math::SigFigs"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Switch
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Switch"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# MIME::Lite
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="MIME::Lite"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-MIME-Lite"
    modulesApt[$iPackage]="libmime-lite-perl"
   interactive[$iPackage]=1

# PDL
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="PDL"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-PDL"
    modulesApt[$iPackage]="pdl"
   interactive[$iPackage]=0

# Astro::Cosmology
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Astro::Cosmology"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=1
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# XML::Simple
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="XML::Simple"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-XML-Simple"
    modulesApt[$iPackage]="libxml-simple-perl"
   interactive[$iPackage]=0

# GraphViz
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="GraphViz"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-GraphViz"
    modulesApt[$iPackage]="libgraphviz-perl"
   interactive[$iPackage]=0

# Image::Magick
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Image::Magick"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="ImageMagick-perl"
    modulesApt[$iPackage]="libimage-magick-perl"
   interactive[$iPackage]=0

# Carp
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Carp"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Cwd
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Cwd"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Data::Compare
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Data::Compare"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Data-Compare"
    modulesApt[$iPackage]="libdata-compare-perl"
   interactive[$iPackage]=0

# Data::Dumper
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Data::Dumper"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Data-Dump"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# DateTime
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="DateTime"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-DateTime"
    modulesApt[$iPackage]="libdatetime-perl"
   interactive[$iPackage]=0

# Date::Format
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Date::Format"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="libdatetime-perl"
   interactive[$iPackage]=0

# Date::Parse
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Date::Parse"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Exporter
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Exporter"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Fcntl
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Fcntl"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# File::Compare
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Compare"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# File::Copy
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Copy"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# File::Find
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Find"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# File::Slurp
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Slurp"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="libfile-slurp-perl"
   interactive[$iPackage]=0

# File::Spec
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Spec"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Graphics::GnuplotIF
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Graphics::GnuplotIF"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="libgraphics-gnuplotif-perl"
   interactive[$iPackage]=0

# threads
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="threads"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-threads"
    modulesApt[$iPackage]="libthreads-perl"
   interactive[$iPackage]=0

# Text::Balanced
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Text::Balanced"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Net::DBus
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Net::DBus"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Net-DBus"
    modulesApt[$iPackage]="libnet-dbus-perl"
   interactive[$iPackage]=0

# IO::Socket::SSL
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="IO::Socket::SSL"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-IO-Socket-SSL"
    modulesApt[$iPackage]="libio-socket-ssl-perl"
   interactive[$iPackage]=0

# Net::SMTP::SSL
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Net::SMTP::SSL"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Net-SMTP-SSL"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Scalar::Util
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Scalar::Util"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Sys::CPU
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Sys::CPU"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Sys-CPU"
    modulesApt[$iPackage]="libsys-cpu-perl"
   interactive[$iPackage]=0

# PDL::LinearAlgebra
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="PDL::LinearAlgebra"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=1
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# PDL::MatrixOps
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="PDL::MatrixOps"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# PDL::NiceSlice
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="PDL::NiceSlice"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# PDL::Ufunc
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="PDL::Ufunc"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# POSIX
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="POSIX"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# List::MoreUtils
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="List::MoreUtils"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-List-MoreUtils"
    modulesApt[$iPackage]="liblist-moreutils-perl"
   interactive[$iPackage]=0

# Install required Perl modules.
echo "Checking for Perl modules..." 
echo "Checking for Perl modules..." >> $glcLogFile

for (( i = 0 ; i < ${#modules[@]} ; i++ ))
do
    # Test if this module should be installed at this level.
    if [ ${modulesAtLevel[$i]} -le $installLevel ]; then
        # Get the name of the module.
	module=${modules[$i]}
        # Test if the module is already present.
	echo "Testing for Perl module $module" >>$glcLogFile
	perl -e "use $module" >>$glcLogFile 2>&1
	if [ $? -eq 0 ]; then
	    # Module already exists.
	    echo $module - found
	    echo $module - found >> $glcLogFile
	else
	    # Module must be installed.
	    echo $module - not found - will be installed
	    echo $module - not found - will be installed >> $glcLogFile
            installDone=0
	    # Try installing via yum.
	    if [[ $installDone -eq 0 && $installViaYum -eq 1 && ${modulesYum[$i]} != "null" ]]; then
                # Check for presence in yum repos.
                echo "$rootPassword" | eval $suCommand yum -y list ${modulesYum[$i]} $suClose >& /dev/null
                if [ $? -eq 0 ]; then
		    echo "   Installing via yum"
		    echo "   Installing via yum" >> $glcLogFile
		    echo "$rootPassword" | eval $suCommand yum -y install ${modulesYum[$i]} $suClose >>$glcLogFile 2>&1
		    perl -e "use $module" >& /dev/null
		    if [ $? -ne 0 ]; then
			echo "   ...failed"
			exit 1
		    fi
                    installDone=1
                fi
            fi 
	    # Try installing via apt.
	    if [[ $installDone -eq 0 &&  $installViaApt -eq 1 && ${modulesApt[$i]} != "null" ]]; then
		echo "   Installing via apt-get"
		echo "   Installing via apt-get" >> $glcLogFile
		echo "$rootPassword" | eval $suCommand apt-get -y install ${modulesApt[$i]} $suClose >>$glcLogFile 2>&1
		perl -e "use $module" >& /dev/null
		if [ $? -ne 0 ]; then
		    echo "   ...failed"
		    exit 1
		fi
                installDone=1
            fi
	    # Try installing via CPAN.
	    if [[ $installDone -eq 0 &&  $installViaCPAN -eq 1 ]]; then
		echo "   Installing via CPAN"
		echo "   Installing via CPAN" >> $glcLogFile
		if [ ${modulesForce[$i]} -eq 1 ]; then
		    cpanInstall="force('install','${modules[$i]}')"
		else
		    cpanInstall="install ${modules[$i]}"
		fi
		if [ $installAsRoot -eq 1 ]; then
		    # Install as root.
                    export PERL_MM_USE_DEFAULT=1
		    if [ ${interactive[$i]} -eq 0 ]; then
			echo "$rootPassword" | eval $suCommand perl -MCPAN -e "$cpanInstall" $suClose >>$glcLogFile 2>&1
		    else
			echo "$rootPassword" | eval $suCommand perl -MCPAN -e "$cpanInstall" $suClose
		    fi
		else		    
                    # Check for local::lib.
		    perl -e "use local::lib" >& /dev/null
		    if [ $? -ne 0 ]; then
			wget http://search.cpan.org/CPAN/authors/id/A/AP/APEIRON/local-lib-1.008004.tar.gz >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    echo "Failed to download local-lib-1.008004.tar.gz"
			    echo "Failed to download local-lib-1.008004.tar.gz" >>$glcLogFile
			    exit
			fi
			tar xvfz local-lib-1.008004.tar.gz >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    echo "Failed to unpack local-lib-1.008004.tar.gz"
			    echo "Failed to unpack local-lib-1.008004.tar.gz" >>$glcLogFile
			    exit
			fi
			cd local-lib-1.008004
			perl Makefile.PL --bootstrap >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    echo "Failed to bootstrap local-lib-1.008004"
			    echo "Failed to bootstrap local-lib-1.008004" >>$glcLogFile
			    exit
			fi
			make >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    echo "Failed to make local-lib-1.008004"
			    echo "Failed to make local-lib-1.008004" >>$glcLogFile
			    exit
			fi
			make test >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    echo ""
			    echo "Tests of local-lib-1.008004 failed" >>$glcLogFile
			    exit
			fi
			make install >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    echo "Failed to install local-lib-1.008004"
			    echo "Failed to install local-lib-1.008004" >>$glcLogFile
			    exit
			fi
		    fi
		    # Ensure that we're using the local::lib environment.
		    if [ $gotPerlLocalLibEnv -eq 0 ]; then
			eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)
			gotPerlLocalLibEnv=1
		    fi
		    # Install as regular user.
		    export PERL_MM_USE_DEFAULT=1
		    if [ ${interactive[$i]} -eq 0 ]; then
			perl -Mlocal::lib -MCPAN -e "$cpanInstall" >>$glcLogFile 2>&1
		    else
			perl -Mlocal::lib -MCPAN -e "$cpanInstall"
		    fi
		fi
		# Check that the module was installed successfully.
		perl -e "use $module" >>/dev/null 2>&1
		if [ $? -ne 0 ]; then
		    echo "   ...failed"
		    exit 1
		fi
                installDone=1
	    fi
	    # We were unable to install the module by any method.
	    if [ $installDone -eq 0 ]; then
		echo "no method exists to install this module"
		echo "no method exists to install this module" >> $glcLogFile
		exit 1;
	    fi
	fi
        # If we installed CPAN then make this an available method for future installs.
	if [[ $installViaCPAN -eq 0 && $module -eq "CPAN" ]]; then
	    installViaCPAN=1
	fi
    fi
    
done

# Install PDL::IO::HDF5
# Installed here because we use a custom version and so install from source
# rather than installing from CPAN.
# Test if this module should be installed at this level.
if [ 1 -le $installLevel ]; then
    # Check if package is installed.
    echo Testing presence of PDL::IO::HDF5 >> $glcLogFile
    installPackage=1
    perl -e "use PDL::IO::HDF5" >& /dev/null
    if [ $? -eq 0 ]; then
        # Check installed version.
	echo "  PDL::IO::HDF5 is present - testing version" >> $glcLogFile
        version=`perl -e "eval 'require PDL::IO::HDF5'; print PDL::IO::HDF5->VERSION"`
	echo "  Found version $version of PDL::IO::HDF5" >> $glcLogFile
	if [[ "$version" != "0.63_glc" ]]; then
	    installPackage=0
	fi
    fi
    # Install package if necessary.
    if [ $installPackage -eq 0 ]; then
	echo PDL::IO::HDF5 - found
	echo PDL::IO::HDF5 - found >> $glcLogFile
    else
	echo PDL::IO::HDF5 - not found - will be installed
	echo PDL::IO::HDF5 - not found - will be installed >> $glcLogFile
	echo "   Installing from source"
	echo "   Installing from source" >>$glcLogFile
	wget "http://www.ctcp.caltech.edu/galacticus/tools/PDL-IO-HDF5-0.6.tar.gz" >>$glcLogFile 2>&1
	if [ $? -ne 0 ]; then
	    echo "Could not download PDL::IO::HDF5"
	    echo "Could not download PDL::IO::HDF5" >>$glcLogFile
	    exit 1
	fi
	baseName="PDL-IO-HDF5-0.6.tar.gz"
	unpack=`echo $baseName | sed -e s/.*\.bz2/j/ -e s/.*\.gz/z/ -e s/.*\.tar//`
	tar xvf$unpack $baseName >>$glcLogFile 2>&1
	if [ $? -ne 0 ]; then
	    echo "Could not unpack PDL::IO::HDF5"
	    echo "Could not unpack PDL::IO::HDF5" >>$glcLogFile
	    exit 1
	fi
	dirName=`tar tf$unpack $baseName | head -1 | sed s/"\/.*"//`
	cd $dirName
	# Detect local HDF5 install.
	if [ -e $toolInstallPath."/include/hdf5.mod" ]; then
	    export HDF5_PATH=$toolInstallPath
	fi
        # Configure the source.
	if [ -e ../$dirName/Makefile.PL ]; then
	    if [ $installAsRoot -eq 1 ]; then
		perl ../$dirName/Makefile.PL >>$glcLogFile 2>&1
	    else
		perl -Mlocal::lib ../$dirName/Makefile.PL >>$glcLogFile 2>&1
	    fi
	else
	    echo "Can not locate Makefile.PL for PDL::IO::HDF5"
	    echo "Can not locate Makefile.PL for PDL::IO::HDF5" >>$glcLogFile
	    exit 1
	fi
	if [ $? -ne 0 ]; then
	    echo "Could not build Makefile for PDL::IO::HDF5"
	    echo "Could not build Makefile for PDL::IO::HDF5" >>$glcLogFile
	    exit 1
	fi
        # Make the package.
	make -j >>$glcLogFile 2>&1
	if [ $? -ne 0 ]; then
	    echo "Could not make PDL::IO::HDF5"
	    echo "Could not make PDL::IO::HDF5" >>$glcLogFile
	    exit 1
	fi
        # Run any tests of the package.
	make -j ${makeTest[$i]} >>$glcLogFile 2>&1
	if [ $? -ne 0 ]; then
	    echo "Testing PDL::IO::HDF5 failed"
	    echo "Testing PDL::IO::HDF5 failed" >>$glcLogFile
	    exit 1
	fi
        # Install the package.
	if [ $installAsRoot -eq 1 ]; then
	    echo "$rootPassword" | eval $suCommand make install ${makeInstall[$i]} $suClose >>$glcLogFile 2>&1
	else
	    make install ${makeInstall[$i]} >>$glcLogFile 2>&1
	fi
	if [ $? -ne 0 ]; then
	    echo "Could not install PDL::IO::HDF5"
	    echo "Could not install PDL::IO::HDF5" >>$glcLogFile
	    exit 1
	fi
    fi
fi

# Retrieve Galacticus via Bazaar.
if [[ $runningAsRoot -eq 1 ]]; then
    echo "Script is running as root - if you want to install Galacticus itself as a regular user, just quit (Ctrl-C) now."
fi
galacticusInstallPath=$HOME/Galacticus/v0.9.1
read -p "Path to install Galacticus to [$galacticusInstallPath]: " RESPONSE
if [ -n "$RESPONSE" ]; then
    galacticusInstallPath=$RESPONSE
fi
if [ ! -e $galacticusInstallPath ]; then
    mkdir -p `dirname $galacticusInstallPath`
    bzr branch --stacked lp:galacticus/v0.9.1 $galacticusInstallPath
    if [ $? -ne 0 ]; then
	echo "failed to download Galacticus"
	echo "failed to download Galacticus" >> $glcLogFile
	exit 1
    fi
fi

# Hardwired magic.
# Figure out which libstdc++ we should use. This is necessary because some
# distributions (Ubuntu.....) don't find -lstdc++ when linking using gfortran.
echo "main() {}" > dummy.c
gcc dummy.c -lstdc++ >>$glcLogFile 2>&1
if [ $? -eq 0 ]; then
    stdcppLibInfo=(`ldd a.out | grep libstdc++`)
    stdcppLib=${stdcppLibInfo[2]}
    if [ ! -e $toolInstallPath/lib/lidstdc++.so ]; then
	if [ $installAsRoot -eq 1 ]; then
	    echo "$rootPassword" | eval $suCommand ln -sf $stdcppLib $toolInstallPath/lib/lidstdc++.so >>$glcLogFile 2>&1
	else
	    ln -sf $stdcppLib $toolInstallPath/lib/libstdc++.so
	fi
    fi
fi

# Add commands to .bashrc and/or .cshrc.
envSet=0
read -p "Add a Galacticus environment alias to .bashrc? [no/yes]: " RESPONSE
if [ "$RESPONSE" = yes ] ; then
    envSet=1
    if [ -e $HOME/.bashrc ]; then
	awk 'BEGIN {inGLC=0} {if (index($0,"Alias to configure the environment to compile and run Galacticus v0.9.1") > 0) inGLC=1;if (inGLC == 0) print $0; if (inGLC == 1 && index($0,"'"'"'")) inGLC=0}' $HOME/.bashrc > $HOME/.bashrc.tmp
	mv -f $HOME/.bashrc.tmp $HOME/.bashrc
    fi
    echo "# Alias to configure the environment to compile and run Galacticus v0.9.1" >> $HOME/.bashrc
    echo "alias galacticus090='" >> $HOME/.bashrc
    echo "if [ -n \"\${LD_LIBRARY_PATH}\" ]; then" >> $HOME/.bashrc
    echo " export LD_LIBRARY_PATH=$toolInstallPath/lib:$toolInstallPath/lib64:\$LD_LIBRARY_PATH" >> $HOME/.bashrc
    echo "else" >> $HOME/.bashrc
    echo " export LD_LIBRARY_PATH=$toolInstallPath/lib:$toolInstallPath/lib64" >> $HOME/.bashrc
    echo "fi" >> $HOME/.bashrc
    echo "if [ -n \"\${PATH}\" ]; then" >> $HOME/.bashrc
    echo " export PATH=$toolInstallPath/bin:\$PATH" >> $HOME/.bashrc
    echo "else" >> $HOME/.bashrc
    echo " export PATH=$toolInstallPath/bin" >> $HOME/.bashrc
    echo "fi" >> $HOME/.bashrc
    echo "if [ -n \"\${PYTHONPATH}\" ]; then" >> $HOME/.bashrc
    echo " export PYTHONPATH=$toolInstallPath/py-lib:\$PATH" >> $HOME/.bashrc
    echo "else" >> $HOME/.bashrc
    echo " export PYTHONPATH=$toolInstallPath/py-lib" >> $HOME/.bashrc
    echo "fi" >> $HOME/.bashrc
    echo "eval \$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)" >> $HOME/.bashrc
    echo "export GALACTICUS_FCFLAGS=\"-fintrinsic-modules-path $toolInstallPath/finclude -fintrinsic-modules-path $toolInstallPath/include -fintrinsic-modules-path $toolInstallPath/include/gfortran -fintrinsic-modules-path $toolInstallPath/lib/gfortran/modules $libDirs\"" >> $HOME/.bashrc
    echo "'" >> $HOME/.bashrc
fi
read -p "Add a Galacticus environment alias to .cshrc? [no/yes]: " RESPONSE
if [ "$RESPONSE" = yes ] ; then
    envSet=1
    if [ -e $HOME/.cshrc ]; then
	awk 'BEGIN {inGLC=0} {if (index($0,"Alias to configure the environment to compile and run Galacticus v0.9.1") > 0) inGLC=1;if (inGLC == 0) print $0; if (inGLC == 1 && index($0,"'"'"'")) inGLC=0}' $HOME/.cshrc > $HOME/.cshrc.tmp
	mv -f $HOME/.cshrc.tmp $HOME/.cshrc
    fi
    echo "# Alias to configure the environment to compile and run Galacticus v0.9.1" >> $HOME/.cshrc
    echo "alias galacticus091 'if ( \$?LD_LIBRARY_PATH ) then \\" >> $HOME/.cshrc
    echo " setenv LD_LIBRARY_PATH $toolInstallPath/lib:$toolInstallPath/lib64:\$LD_LIBRARY_PATH \\" >> $HOME/.cshrc
    echo "else \\" >> $HOME/.cshrc
    echo " setenv LD_LIBRARY_PATH $toolInstallPath/lib:$toolInstallPath/lib64 \\" >> $HOME/.cshrc
    echo "endif \\" >> $HOME/.cshrc
    echo "if ( \$?PATH ) then \\" >> $HOME/.cshrc
    echo " setenv PATH $toolInstallPath/bin:\$PATH \\" >> $HOME/.cshrc
    echo "else \\" >> $HOME/.cshrc
    echo " setenv PATH $toolInstallPath/bin \\" >> $HOME/.cshrc
    echo "endif \\" >> $HOME/.cshrc
    echo "if ( \$?PYTHONPATH ) then \\" >> $HOME/.cshrc
    echo " setenv PYTHONPATH $toolInstallPath/py-lib:\$PATH \\" >> $HOME/.cshrc
    echo "else \\" >> $HOME/.cshrc
    echo " setenv PYTHONPATH $toolInstallPath/py-lib \\" >> $HOME/.cshrc
    echo "endif \\" >> $HOME/.cshrc
    echo "eval \`perl -I$HOME/perl5/lib/perl5 -Mlocal::lib\` \\" >> $HOME/.cshrc
    if [ -n "${gfortranAlias:-x}" ]; then
	echo "alias gfortran $gfortranAlias" >> $HOME/.bashrc
    fi 
    echo "setenv GALACTICUS_FCFLAGS \"-fintrinsic-modules-path $toolInstallPath/finclude -fintrinsic-modules-path $toolInstallPath/include -fintrinsic-modules-path $toolInstallPath/include/gfortran -fintrinsic-modules-path $toolInstallPath/lib/gfortran/modules $libDirs\"'" >> $HOME/.cshrc
fi

# Build Galacticus.
cd $galacticusInstallPath
if [ ! -e Galacticus.exe ]; then
    export GALACTICUS_FCFLAGS=$moduleDirs
    make Galacticus.exe >>$glcLogFile 2>&1
    if [ $? -ne 0 ]; then
	echo "failed to build Galacticus"
	echo "failed to build Galacticus" >> $glcLogFile
	exit 1
    fi
fi

# Run a test case.
./Galacticus.exe parameters.xml >>$glcLogFile 2>&1
if [ $? -ne 0 ]; then
    echo "failed to run Galacticus"
    echo "failed to run Galacticus" >> $glcLogFile
    exit 1
fi
cd -

# Write a final message.
echo "Completed successfully"
echo "Completed successfully" >> $glcLogFile
echo
echo "You can delete the \"galacticusInstallWork\" folder if you want"
echo "You can delete the \"galacticusInstallWork\" folder if you want" >> $glcLogFile
echo
if [ $envSet -eq 1 ]; then
    echo "You should execute the command \"galacticus091\" before attempting to use Galacticus to configure all environment variables, library paths etc."
    echo "You should execute the command \"galacticus091\" before attempting to use Galacticus to configure all environment variables, library paths etc." >> $glcLogFile
else
    if [ $installAsRoot -eq 1 ]; then
	echo "If you install Galacticus libraries and tools in a non-standard location you may need to set environment variables appropriately to find them."
	echo "If you install Galacticus libraries and tools in a non-standard location you may need to set environment variables appropriately to find them." >> $glcLogFile
    else
	echo "You may need to set environment variables to permit libraries and tools installed to be found."
	echo "You may need to set environment variables to permit libraries and tools installed to be found." >> $glcLogFile
    fi
fi
exit 0
