#!/usr/bin/env bash

# Galacticus install script.
# Copyright Andrew Benson 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022

# Functions
function contains() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}

function logexec()
{
    echo \-\-\> "$@" >> $glcLogFile
    eval "$@" >> $glcLogFile 2>&1 
}

function logmessage()
{
    echo "$@"
    echo "$@" >>$glcLogFile 2>&1
}

# Define a log file.
glcLogFile=`pwd`"/galacticusInstall.log"

# Get arugments.
TEMP=`getopt -o t --long toolPrefix::,asRoot::,rootPwd::,suMethod::,installLevel::,packageManager::,cores::,galacticusPrefix::,setCShell::,setBash::,ignoreFailures::,catLogOnError:: -- "$@"`
eval set -- "$TEMP"
cmdToolPrefix=
cmdAsRoot=
cmdRootPwd=
cmdInstallLevel=
cmdPackageManager=
cmdCores=
cmdSuMethod=
cmdGalacticusPrefix=
cmdSetCShell=
cmdSetBash=
cmdIgnoreFailures=
cmdCatLogOnError=
while true; do
    case "$1" in
	--asRoot ) cmdAsRoot="$2"; shift 2 ;;
	--cores ) cmdCores="$2"; shift 2 ;;
	--galacticusPrefix ) cmdGalacticusPrefix="$2"; shift 2 ;;
	--installLevel ) cmdInstallLevel="$2"; shift 2 ;;
	--packageManager ) cmdPackageManager="$2"; shift 2 ;;
	--rootPwd ) cmdRootPwd="$2"; shift 2 ;;
	--setCShell ) cmdSetCShell="$2"; shift 2 ;;
	--setBash ) cmdSetBash="$2"; shift 2 ;;
	--ignoreFailures ) cmdIgnoreFailures="$2"; shift 2 ;;
	--catLogOnError ) cmdCatLogOnError="$2"; shift 2 ;;
	--suMethod ) cmdSuMethod="$2"; shift 2 ;;
	--toolPrefix ) cmdToolPrefix="$2"; shift 2 ;;
	-- ) shift; break ;;
	* ) break ;;
    esac
done

# Validate arguments.
if [ ! -z ${cmdAsRoot} ]; then
    if [[ ${cmdAsRoot} != "no" && ${cmdAsRoot} != "yes" ]]; then
	logmessage "asRoot option should be 'yes' or 'no'"
	exit 1
    fi
fi
if [ ! -z ${cmdSetCShell} ]; then
    if [[ ${cmdSetCShell} != "no" && ${cmdSetCShell} != "yes" ]]; then
	logmessage "setCShell option should be 'yes' or 'no'"
	exit 1
    fi
fi
if [ ! -z ${cmdSetBash} ]; then
    if [[ ${cmdSetBash} != "no" && ${cmdSetBash} != "yes" ]]; then
	logmessage "setBash option should be 'yes' or 'no'"
	exit 1
    fi
fi
if [ ! -z ${cmdIgnoreFailures} ]; then
    if [[ ${cmdIgnoreFailures} != "no" && ${cmdIgnoreFailures} != "yes" ]]; then
	logmessage "ignoreFailures option should be 'yes' or 'no'"
	exit 1
    fi
fi
if [ ! -z ${cmdCatLogOnError} ]; then
    if [[ ${cmdCatLogOnError} != "no" && ${cmdCatLogOnError} != "yes" ]]; then
	logmessage "catLogOnError option should be 'yes' or 'no'"
	exit 1
    fi
fi
if [ ! -z ${cmdSuMethod} ]; then
    if [[ ${cmdSuMethod} != "su" && ${cmdSuMethod} != "sudo" ]]; then
	logmessage "suMethod option should be 'su' or 'sudo'"
	exit 1
    fi
fi
if [ ! -z ${cmdPackageManager} ]; then
    if [[ ${cmdPackageManager} != "no" && ${cmdPackageManager} != "yes" ]]; then
	logmessage "packageManager option should be 'yes' or 'no'"
	exit 1
    fi
fi
if [ ! -z ${cmdInstallLevel} ]; then
    if [[ ${cmdInstallLevel} != "binary" && ${cmdInstallLevel} != "minimal" && ${cmdInstallLevel} != "full" ]]; then
	logmessage "installLevel option should be 'binary', 'minimal', or 'full'"
	exit 1
    fi
fi
if [ ! -z ${cmdCores} ]; then
    if [[ ! ${cmdCores} =~ ^[0-9]+$ ]]; then
	logmessage "cores option should be an integer"
	exit 1
    fi
fi

# Set defaults.
catLogOnError="no"
if [ ! -z ${cmdCatLogOnError} ]; then
    catLogOnError=$cmdCatLogOnError
fi

# Open the log file.
echo "Galacticus install log" > $glcLogFile

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
    if [ -z ${cmdToolPrefix} ]; then
	toolInstallPath=/usr/local/galacticus
	read -p "Path to install tools to as root [$toolInstallPath]: " RESPONSE
	if [ -n "$RESPONSE" ]; then
            toolInstallPath=$RESPONSE
	fi
    else
 	toolInstallPath=${cmdToolPrefix}
    fi 	
else
    installAsRoot=-1
    runningAsRoot=0
fi
while [ $installAsRoot -eq -1 ]
do
    if [ -z ${cmdAsRoot} ]; then
	read -p "Install required libraries and Perl modules as root (requires root password)? [no/yes]: " RESPONSE
    else
	RESPONSE=${cmdAsRoot}
    fi
    if [ "$RESPONSE" = yes ] ; then
	# Installation will be done as root where possible.
        installAsRoot=1
	
	# Ask whether we should use "su" or "sudo" for root installs.
        suCommand="null"
        while [[ $suCommand == "null" ]]
        do
	    if [ -z ${cmdSuMethod} ]; then
		read -p "Use sudo or su for root installs:" suMethod
	    else
		suMethod=$cmdSuMethod
	    fi
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
	if [ -z ${cmdRootPwd} ]; then
            read -s -p "Please enter the $pName password:" rootPassword
	else
	    rootPassword=$cmdRootPwd
	fi
	echo "$rootPassword" | eval $suCommand echo worked $suClose >& /dev/null
	echo
	if [ $? -ne 0 ] ; then
	    echo "$pName password was incorrect, exiting"
	    exit 1
	fi
	echo "Libraries and Perl modules will be installed as root"
	echo "Libraries and Perl modules will be installed as root" >> $glcLogFile

	# Set up a suitable install path.
	if [ -z ${cmdToolPrefix} ]; then
	    toolInstallPath=/usr/local/galacticus
            read -p "Path to install tools to as root [$toolInstallPath]: " RESPONSE
            if [ -n "$RESPONSE" ]; then
		toolInstallPath=$RESPONSE
            fi
	else
 	    toolInstallPath=${cmdToolPrefix}
	fi
    elif [ "$RESPONSE" = no ] ; then
	# Install as regular user.
        installAsRoot=0
	echo "Libraries and Perl modules will be installed as regular user"
	echo "Libraries and Perl modules will be installed as regular user" >> $glcLogFile

	# Set yp a suitable install path.
	if [ -z ${cmdToolPrefix} ]; then
            toolInstallPath=$HOME/Galacticus/Tools
            read -p "Path to install tools to [$toolInstallPath]: " RESPONSE
            if [ -n "$RESPONSE" ]; then
		toolInstallPath=$RESPONSE
            fi
	else
 	    toolInstallPath=${cmdToolPrefix}
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

# Use a package manager?
if [ $installAsRoot -eq 1 ]; then
    usePackageManager=-1
    while [ $usePackageManager -eq -1 ]
    do
	if [ -z $cmdPackageManager ]; then
	    read -p "Use package manager for install (if available)?: " RESPONSE
	else
	    RESPONSE=$cmdPackageManager
	fi
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

# Binary, minimal, or full install?
installLevel=-2
while [ $installLevel -eq -2 ]
do
    if [ -z ${cmdInstallLevel} ]; then
	read -p "Binary, minimal, or full install?: " RESPONSE
    else
	RESPONSE=$cmdInstallLevel
    fi
    lcRESPONSE=${RESPONSE,,}
    if [ "$lcRESPONSE" = binary ] ; then
        installLevel=-1
	echo "Binary install only (plus anything required to run the binary)"
	echo "Binary install only (plus anything required to run the binary)" >> $glcLogFile
    elif [ "$lcRESPONSE" = minimal ] ; then
        installLevel=0
	echo "Minimal install only (just enough to compile and run Galacticus)"
	echo "Minimal install only (just enough to compile and run Galacticus)" >> $glcLogFile
    elif [ "$lcRESPONSE" = full ] ; then
        installLevel=1
        echo "Full install"
        echo "Full install" >> $glcLogFile
    else
	echo "Please enter 'binary', 'minimal' or 'full'"
    fi
done

# Use multiple cores to compile.
coresAvailable=`grep -c ^processor /proc/cpuinfo`
coreCount=-1
while [ $coreCount -eq -1 ]
do
    if [ -z ${cmdCores} ]; then
	read -p "How many cores should I use when compiling? ($coresAvailable available): " RESPONSE
    else
	RESPONSE=$cmdCores
    fi
    if ! [[ "$RESPONSE" =~ ^[0-9]+$ ]] ; then
	    echo "Please enter an integer"
    else
	if [ "$RESPONSE" > 0 ] ; then
            coreCount=$RESPONSE
	    echo "Will use $coreCount cores for compiling"
	    echo "Will use $coreCount cores for compiling" >> $glcLogFile
	else
	    echo "Please enter a number greater than 0"
	fi
    fi
done

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
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

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
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

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
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

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
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

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
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

# gcc (initial attempt - allow install via package manager only)
iPackage=$(expr $iPackage + 1)
            iGCC=$iPackage
	iGCCVMin="4.0.0"
         package[$iPackage]="gcc"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gcc"
      getVersion[$iPackage]="versionString=(\`gcc --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]=$iGCCVMin
      maxVersion[$iPackage]="19.9.9"
      yumInstall[$iPackage]="gcc"
      aptInstall[$iPackage]="gcc"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

# g++ (initial attempt - allow install via package manager only)
iPackage=$(expr $iPackage + 1)
            iGPP=$iPackage
	iGPPVMin="4.0.0"
         package[$iPackage]="g++"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash g++"
      getVersion[$iPackage]="versionString=(\`g++ --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]=$iGPPVMin
      maxVersion[$iPackage]="19.9.9"
      yumInstall[$iPackage]="gcc-g++"
      aptInstall[$iPackage]="g++"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

# GFortran (initial attempt - allow install via package manager only)
iPackage=$(expr $iPackage + 1)
        iFortran=$iPackage
    iFortranVMin="10.1.0"
         package[$iPackage]="gfortran"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gfortran"
      getVersion[$iPackage]="versionString=(\`gfortran --version\`); echo \${versionString[3]}"
      minVersion[$iPackage]=$iFortranVMin
      maxVersion[$iPackage]="19.9.9"
      yumInstall[$iPackage]="gcc-gfortran"
      aptInstall[$iPackage]="gfortran"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

# expat
iPackage=$(expr $iPackage + 1)
         package[$iPackage]="expat"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash xmlwf"
      getVersion[$iPackage]="echo 1.0.0"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99"
      yumInstall[$iPackage]="expat-devel"
      aptInstall[$iPackage]="libexpat-dev"
       sourceURL[$iPackage]="https://github.com/libexpat/libexpat/releases/download/R_2_5_0/expat-2.5.0.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

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
       sourceURL[$iPackage]="http://zlib.net/zlib-1.2.8.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

   # GMP (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
            iGMP=$iPackage
         package[$iPackage]="gmp"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"#include <gmp.h>\" > dummy.c; echo \"main() {}\" >> dummy.c; gcc dummy.c $libDirs -lgmp"
      getVersion[$iPackage]="echo \"#include <stdio.h>\" > dummy.c; echo \"#include <gmp.h>\" >> dummy.c; echo \"main() {printf(\\\"%d.%d.%d\\\\n\\\",__GNU_MP_VERSION,__GNU_MP_VERSION_MINOR,__GNU_MP_VERSION_PATCHLEVEL);}\" >> dummy.c; gcc dummy.c $libDirs -lgmp; ./a.out"
      minVersion[$iPackage]="4.3.2"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="gmp-devel"
      aptInstall[$iPackage]="libgmp3-dev"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

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
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# MPC (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
            iMPC=$iPackage
         package[$iPackage]="mpc"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"#include <mpc.h>\" > dummy.c; echo \"main() {}\" >> dummy.c; gcc dummy.c $libDirs -lmpc"
      getVersion[$iPackage]="echo \"#include <stdio.h>\" > dummy.c; echo \"#include <mpc.h>\" >> dummy.c; echo \"main() {printf(\\\"%s\\\\n\\\",MPC_VERSION_STRING);}\" >> dummy.c; gcc dummy.c $libDirs -lmpc; ./a.out"
      minVersion[$iPackage]="1.0.0"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="libmpc-devel"
      aptInstall[$iPackage]="libmpc-dev"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# bison
iPackage=$(expr $iPackage + 1)
          iBison=$iPackage
         package[$iPackage]="bison"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash bison"
      getVersion[$iPackage]="echo 1.0.0"
      minVersion[$iPackage]="0.9.9"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="bison"
      aptInstall[$iPackage]="bison"
       sourceURL[$iPackage]="http://ftp.gnu.org/gnu/bison/bison-3.0.1.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# flex
iPackage=$(expr $iPackage + 1)
           iFlex=$iPackage
         package[$iPackage]="flex"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash flex"
      getVersion[$iPackage]="echo 1.0.0"
      minVersion[$iPackage]="0.9.9"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="flex"
      aptInstall[$iPackage]="flex"
       sourceURL[$iPackage]="http://downloads.sourceforge.net/project/flex/flex-2.5.37.tar.bz2"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
   #! <workaround>
   #!  <replaced>makeTest[$iPackage]="make check"</replaced>
   #!  <description>test suite currently fails due to unsupported directive</description>   
   #!  <url>http://lists.gnu.org/archive/html/bug-bison/2013-10/msg00008.html</url>
   #! </workaround>
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# gcc (second attempt - install from source)
iPackage=$(expr $iPackage + 1)
      iGCCsource=$iPackage
         package[$iPackage]="gcc"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gcc"
      getVersion[$iPackage]="versionString=(\`gcc --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]=$iGCCVMin
      maxVersion[$iPackage]="19.9.9"
      yumInstall[$iPackage]="null"
      aptInstall[$iPackage]="null"
       sourceURL[$iPackage]="git://gcc.gnu.org/git/gcc.git"
       gitBranch[$iPackage]="releases/gcc-12"
buildEnvironment[$iPackage]="cd ../\$dirName; ./contrib/download_prerequisites; cd -"
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]="--prefix=$toolInstallPath --enable-languages= --disable-multilib"
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# g++ (second attempt - install from source)
iPackage=$(expr $iPackage + 1)
      iGPPsource=$iPackage
         package[$iPackage]="g++"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash g++"
      getVersion[$iPackage]="versionString=(\`g++ --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]=$iGPPVMin
      maxVersion[$iPackage]="19.9.9"
      yumInstall[$iPackage]="null"
      aptInstall[$iPackage]="null"
       sourceURL[$iPackage]="git://gcc.gnu.org/git/gcc.git"
       gitBranch[$iPackage]="releases/gcc-12"
buildEnvironment[$iPackage]="cd ../\$dirName; ./contrib/download_prerequisites; cd -"
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]="--prefix=$toolInstallPath --enable-languages= --disable-multilib"
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# GFortran (second attempt - install from source)
iPackage=$(expr $iPackage + 1)
  iFortranSource=$iPackage
         package[$iPackage]="gfortran"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gfortran"
      getVersion[$iPackage]="versionString=(\`gfortran --version\`); echo \${versionString[3]}"
      minVersion[$iPackage]=$iFortranVMin
      maxVersion[$iPackage]="19.9.9"
      yumInstall[$iPackage]="null"
      aptInstall[$iPackage]="null"
       sourceURL[$iPackage]="git://gcc.gnu.org/git/gcc.git"
       gitBranch[$iPackage]="releases/gcc-12"
buildEnvironment[$iPackage]="cd ../\$dirName; ./contrib/download_prerequisites; cd -"
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]="--prefix=$toolInstallPath --enable-languages= --disable-multilib"
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# GSL
iPackage=$(expr $iPackage + 1)
            iGSL=$iPackage
         package[$iPackage]="gsl"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gsl-config && hash gsl-histogram"
      getVersion[$iPackage]="gsl-config --version"
      minVersion[$iPackage]="1.15"
      maxVersion[$iPackage]="2.6"
      yumInstall[$iPackage]="gsl-devel"
      aptInstall[$iPackage]="libgsl0-dev gsl-bin"
       sourceURL[$iPackage]="http://www.mirrorservice.org/sites/ftp.gnu.org/gnu/gsl/gsl-2.6.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

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
       sourceURL[$iPackage]="https://github.com/andreww/fox/archive/4.1.0.tar.gz"
buildEnvironment[$iPackage]="export FC=gfortran"
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

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
       sourceURL[$iPackage]="https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8/hdf5-1.8.20/src/hdf5-1.8.20.tar.gz"
buildEnvironment[$iPackage]="export F9X=gfortran"
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath --enable-fortran --enable-production"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# FFTW3
iPackage=$(expr $iPackage + 1)
          iFFTW3=$iPackage
         package[$iPackage]="fftw3"
  packageAtLevel[$iPackage]=1
    testPresence[$iPackage]="hash fftw-wisdom"
      getVersion[$iPackage]="versionString=(\`fftw-wisdom -V\`); echo \${versionString[5]}"
      minVersion[$iPackage]="3.3.0"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="fftw3-devel"
      aptInstall[$iPackage]="libfftw3-dev"
       sourceURL[$iPackage]="http://www.fftw.org/fftw-3.3.4.tar.gz"
buildEnvironment[$iPackage]="export F9X=gfortran"
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# blas
iPackage=$(expr $iPackage + 1)
   iBLAS=$iPackage
         package[$iPackage]="blas"
  packageAtLevel[$iPackage]=0
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
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

# bzip2
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
       sourceURL[$iPackage]="https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="skip"
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install PREFIX=$toolInstallPath"
   parallelBuild[$iPackage]=0

# git
iPackage=$(expr $iPackage + 1)
            iGIT=$iPackage
         package[$iPackage]="git"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash git"
      getVersion[$iPackage]="versionString=(\`git version\`); echo \${versionString[2]}"
      minVersion[$iPackage]="2.0.0"
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="git"
      aptInstall[$iPackage]="git-all"
       sourceURL[$iPackage]="https://github.com/git/git/archive/refs/tags/v2.40.0.tar.gz"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

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
        # Check if installation is to be forced for this package.
	test $(contains "$@" "--force-${package[$i]}") == "y"
	if [ $? -eq 0 ]; then
	    installPackage=1
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
				    logmessage "   ...failed"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
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
				    logmessage "   ...failed"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
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
		    abort="yes"
		    if [ -z ${cmdIgnoreFailures} ]; then
			abort=$cmdIgnoreFailures
		    fi
		    if [ "$abort" = yes ]; then
			logmessage "This installer can not currently install ${package[$i]} from source. Please install manually and then re-run this installer."
			if [ "$catLogOnError" = yes ]; then
			    cat $glcLogFile
			fi
			exit 1
		    else
			logmessage "This installer can not currently install ${package[$i]} from source. Ignoring and continuing, but errors may occur."
		    fi
		else
		    logmessage "   Installing from source"
		    if [[ ${sourceURL[$i]} =~ "git:" ]]; then
			logexec git clone checkout \"${sourceURL[$i]}\"
			if [ $? -ne 0 ]; then
			    logmessage "Trying git checkout again using http protocol instead"
			    baseName=`basename ${sourceURL[$i]}`
			    logexec rm -rf $baseName
			    logexec git clone "${sourceURL[$i]/git:/http:}"
			fi
		        if [ -z "${gitBranch[$i]}" ]; then
			    logexec git checkout ${gitBranch[$i]}
			fi
		    else
			logexec wget \"${sourceURL[$i]}\"
		    fi
		    if [ $? -ne 0 ]; then
			logmessage "Could not download ${package[$i]}"
			if [ "$catLogOnError" = yes ]; then
			    cat $glcLogFile
			fi
			exit 1
		    fi
		    baseName=`basename ${sourceURL[$i]}`
		    if [[ ${sourceURL[$i]} =~ "git:" ]]; then  
			dirName=`echo $baseName | sed s/"\.git"//`
		    else
			unpack=`echo $baseName | sed -e s/.*\.bz2/j/ -e s/.*\.gz/z/ -e s/.*\.tgz/z/ -e s/.*\.tar//`
			logexec tar xvf$unpack $baseName
			if [ $? -ne 0 ]; then
			    logmessage "Could not unpack ${package[$i]}"
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
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
		    # Hardwired magic.
		    # For HDF5, fix non-compliant comments (by simply removing such comment lines).
		    if [ $i -eq $iHDF5 ]; then
			find . -name "*.c" | xargs sed -r -i~ /"^\s*\/\/"/d
		    fi
     		    # Check for special package.
		    if [ -z "${buildEnvironment[$i]}" ]; then
			isPerl=0
			isCopy=0
		    else
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
		    if [ $isCopy -eq 1 ]; then
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
			    logmesage "Failed to patch make.inc in blas"
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
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
			    logmessage "Failed to patch Makefile in blas"
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
			    exit 1
			fi
			sed -i~ -r s/"@X@"/"\t"/g Makefile >>$glcLogFile 2>&1
			make libblas.so >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Failed to make libblas.so"
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
			    exit 1
			fi
			mkdir -p $toolInstallPath/lib/ >>$glcLogFile 2>&1
			cp -f libblas.so $toolInstallPath/lib/ >>$glcLogFile 2>&1
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
				wget http://ftp.gnu.org/gnu/m4/m4-1.4.17.tar.gz >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to download m4 source"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
				    exit 1
				fi
				tar xvfz m4-1.4.17.tar.gz >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to unpack m4 source"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
				    exit 1
				fi
				cd m4-1.4.17
				./configure --prefix=$toolInstallPath >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to configure m4 source"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
				    exit 1
				fi
				make >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to make m4"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
				    exit 1
				fi
				make check >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to check m4"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
				    exit 1
				fi
				make install >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to install m4"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
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
				if [ "$catLogOnError" = yes ]; then
				    cat $glcLogFile
				fi
				exit 1
			    fi
			    if [ $? -ne 0 ]; then
				echo "Could not build Makefile for ${package[$i]}"
				echo "Could not build Makefile for ${package[$i]}" >>$glcLogFile
				if [ "$catLogOnError" = yes ]; then
				    cat $glcLogFile
				fi
				exit 1
			    fi
			else
			    # Hardwired magic.
			    # For HDF5 on older kernel versions we need to reduce optimization to prevent bug HDFFV-7829 
			    # from occuring during testing.
			    preConfig=" "
			    if [ $i -eq $iHDF5 ]; then
				version=`uname -r`
				testLow=`echo "$version test:3.4.999:9.9.9" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
				testHigh=`echo "$version test:3.4.999:9.9.9" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
				if [[ "$testLow" == "test" ]]; then
				    preConfig="env CFLAGS=-O0 "
				fi
			    fi
			    eval ${buildEnvironment[$i]}
			    if [ -e ../$dirName/configure ]; then
				logexec $preConfig ../$dirName/configure ${configOptions[$i]}
			    elif [ -e ../$dirName/config ]; then
				logexec $preConfig ../$dirName/config ${configOptions[$i]}
			    elif [[ ${configOptions[$i]} -ne "skip" ]]; then
				echo "Can not locate configure script for ${package[$i]}"
				echo "Can not locate configure script for ${package[$i]}" >>$glcLogFile
				if [ "$catLogOnError" = yes ]; then
				    cat $glcLogFile
				fi
				exit 1
			    fi
			    if [ $? -ne 0 ]; then
				echo "Could not configure ${package[$i]}"
				echo "Could not configure ${package[$i]}" >>$glcLogFile
				if [ "$catLogOnError" = yes ]; then
				    cat $glcLogFile
				fi
				exit 1
			    fi
			fi
		        # Make the package.
			makeOptions=" "
			if [ ${parallelBuild[$i]} -eq 1 ]; then
			    makeOptions=" -j$coreCount"
			fi
			logexec make $makeOptions
			if [ $? -ne 0 ]; then
			    echo "Could not make ${package[$i]}"
			    echo "Could not make ${package[$i]}" >>$glcLogFile
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
			    exit 1
			fi
		        # Run any tests of the package.
			logexec make ${makeTest[$i]}
			if [ $? -ne 0 ]; then
			    logmessage "Testing ${package[$i]} failed"
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
			    exit 1
			fi
		        # Install the package.
			if [ $installAsRoot -eq 1 ]; then
			    echo "$rootPassword" | eval $suCommand make ${makeInstall[$i]} $suClose >>$glcLogFile 2>&1
			else
			    logexec make ${makeInstall[$i]}
			fi
			if [ $? -ne 0 ]; then
			    echo "Could not install ${package[$i]}"
			    echo "Could not install ${package[$i]}" >>$glcLogFile
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
			    exit 1
			fi
                        # Hardwired magic.
                        # For bzip2 we have to compile and install shared libraries manually......
			if [ $i -eq $iBZIP2 ]; then
 			    if [ $installAsRoot -eq 1 ]; then
				echo "$rootPassword" | eval $suCommand make clean $suClose >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 1"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
				    exit 1
				fi
				echo "$rootPassword" | eval $suCommand make -f Makefile-libbz2_so $suClose >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 2"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
				    exit 1
				fi
				echo "$rootPassword" | eval $suCommand cp libbz2.so* $toolInstallPath/lib/ $suClose >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 3"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
				    exit 1
				fi
				echo "$rootPassword" | eval $suCommand chmod a+r $toolInstallPath/lib/libbz2.so* $suClose >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 4"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
				    exit 1
				fi
			    else
				make clean >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 1"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
				    exit 1
				fi
				make -f Makefile-libbz2_so >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 2"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
				    exit 1
				fi
				cp libbz2.so* $toolInstallPath/lib/ >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 3"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
				    exit 1
				fi
				chmod a+r $toolInstallPath/lib/libbz2.so*  >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 4"
				    if [ "$catLogOnError" = yes ]; then
					cat $glcLogFile
				    fi
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
		    if [[ $i -eq $iMPFR || $i -eq $iMPC || $i -eq $iGMP ]]; then
			echo "      ignoring [will be installed with GCC]"
			echo "      ignoring [will be installed with GCC]" >>$glcLogFile
		    else
			if [ "$catLogOnError" = yes ]; then
			    cat $glcLogFile
			fi
			exit 1
		    fi
		fi
            fi
	fi
        # Hardwired magic.        
        # Check if GCC/G++/Fortran are installed - delist MPFR, GMP and MPC if so.
	if [ $i -eq $iFortran ]; then
	    eval ${testPresence[$iFortran]} | test $(contains "$@" "--force-gfortran") == "y" >& /dev/null
	    gotFortran=$?
	    eval ${testPresence[$iGCC]} | test $(contains "$@" "--force-gcc") == "y" >& /dev/null
	    gotGCC=$?
	    eval ${testPresence[$iGPP]} | test $(contains "$@" "--force-g++") == "y" >& /dev/null
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
		# We have all GNU Compiler Collection components, so we don't need GMP, MPFR, MPC, flex, or bison.
		packageAtLevel[$iGMP]=100
		packageAtLevel[$iMPFR]=100
		packageAtLevel[$iMPC]=100
		packageAtLevel[$iFlex]=100
		packageAtLevel[$iBison]=100
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
				logmessage "Failed to install gcc-multilib needed for compiling GNU Compiler Collection."
				if [ "$catLogOnError" = yes ]; then
				    cat $glcLogFile
				fi
				exit 1
			    fi
			else
			    echo "I need to compile some of the GNU Compiler Collection."
			    echo "That requires that gcc-multilib be installed which requires root access."
			    echo "Please do: sudo apt-get install gcc-multilib"
			    echo "or ask your sysadmin to install it for you if necessary, then run this script again."
			    echo "I need to compile some of the GNU Compiler Collection." >>$glcLogFile
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
	    fi
	fi
    fi
done

# Set environment path for HDF5 if we installed our own copy.
if [ -e $toolInstallPath/lib/libhdf5.so ]; then
    export HDF5_PATH=$toolInstallPath
fi

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

# Clone
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Clone"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Clone"
    modulesApt[$iPackage]="libcline-perl"
   interactive[$iPackage]=0

# Text::Table
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Text::Table"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Text-Table"
    modulesApt[$iPackage]="libtext-table-perl"
   interactive[$iPackage]=0

# Text::Template
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Text::Template"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Text-Template"
    modulesApt[$iPackage]="libtext-template-perl"
   interactive[$iPackage]=0

# NestedMap
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="NestedMap"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Regexp::Common
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Regexp::Common"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Regexp-Common"
    modulesApt[$iPackage]="libregexp-common-perl"
   interactive[$iPackage]=0

# LaTeX::Encode
#! <workaround>
#!  <description>Global symbols are not correctly imported with a modern Perl</description>
#!  <url>https://rt.cpan.org/Public/Bug/Display.html?id=87908</url>
#! </workaround>
iPackage=$(expr $iPackage + 1)
  iLaTeXEncode=$iPackage
       modules[$iPackage]="LaTeX::Encode"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
 modulesSource[$iPackage]="http://search.cpan.org/CPAN/authors/id/A/AN/ANDREWF/LaTeX-Encode-0.08.tar.gz"
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="liblatex-encode-perl"
   interactive[$iPackage]=0

# File::Copy
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Copy"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# XML::SAX
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="XML::SAX"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-XML-SAX"
    modulesApt[$iPackage]="libxml-sax-perl"
   interactive[$iPackage]=0

# XML::Simple
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="XML::Simple"
modulesAtLevel[$iPackage]=-1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-XML-Simple"
    modulesApt[$iPackage]="libxml-simple-perl"
   interactive[$iPackage]=0

# Cwd
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Cwd"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Data::Dumper
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Data::Dumper"
modulesAtLevel[$iPackage]=-1
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
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="libdatetime-perl"
   interactive[$iPackage]=0

# Exporter
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Exporter"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Fcntl
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Fcntl"
modulesAtLevel[$iPackage]=-1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# File::Slurp
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Slurp"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="libfile-slurp-perl"
   interactive[$iPackage]=0

# Scalar::Util
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Scalar::Util"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# List::Uniq
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="List::Uniq"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# XML::Validator::Schema
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="XML::Validator::Schema"
modulesAtLevel[$iPackage]=0
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
	if [[ $module == "Inline::C" ]]; then
	    # Hardwired magic to test for Inline::C.
	    perl -e 'use Inline C=>q{void testpres(){printf("inline c present\n");}};testpres' >>$glcLogFile 2>&1
	else
	    perl -e "use $module" >>$glcLogFile 2>&1
	fi
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
			logmessage "   ...failed"
			if [ "$catLogOnError" = yes ]; then
			    cat $glcLogFile
			fi
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
		    logmessage "   ...failed"
		    if [ "$catLogOnError" = yes ]; then
			cat $glcLogFile
		    fi
		    exit 1
		fi
                installDone=1
            fi
	    # Try installing from source.
	    if [[ $installDone -eq 0 && ${modulesSource[$i]} != "" ]]; then
		echo "   Installing from source"
		echo "   Installing from source" >>$glcLogFile
		wget "${modulesSource[$i]}" >>$glcLogFile 2>&1
		if [ $? -ne 0 ]; then
		    echo "Could not download ${modules[$i]}"
		    echo "Could not download ${modules[$i]}" >>$glcLogFile
		    if [ "$catLogOnError" = yes ]; then
			cat $glcLogFile
		    fi
		    exit 1
		fi
		baseName=`basename ${modulesSource[$i]}`
		unpack=`echo $baseName | sed -e s/.*\.bz2/j/ -e s/.*\.gz/z/ -e s/.*\.tgz/z/ -e s/.*\.tar//`
		tar xvf$unpack $baseName >>$glcLogFile 2>&1
		if [ $? -ne 0 ]; then
		    echo "Could not unpack ${modules[$i]}"
		    echo "Could not unpack ${modules[$i]}" >>$glcLogFile
		    if [ "$catLogOnError" = yes ]; then
			cat $glcLogFile
		    fi
		    exit 1
		fi
		dirName=`tar tf$unpack $baseName | head -1 | sed s/"\/.*"//`
		cd $dirName
# Hardwired magic.
#! <workaround>
#!  <description>Global symbols are not correctly imported with a modern Perl</description>
#!  <url>https://rt.cpan.org/Public/Bug/Display.html?id=87908</url>
#! </workaround>
# Apply a patch to LaTeX::Encode to fix symbol import issues.
if [ $i -eq $iLaTeXEncode ]; then
cd lib/LaTeX
sed -i~ s/"use LaTeX::Encode::EncodingTable;"/"#use LaTeX::Encode::EncodingTable;"/ Encode.pm
sed -i~ s/"use base qw(Exporter);"/"use base qw(Exporter);\nuse LaTeX::Encode::EncodingTable;"/ Encode.pm
cd -
fi
		# Configure the source.
		if [ -e ../$dirName/Makefile.PL ]; then
		    if [ $installAsRoot -eq 1 ]; then
			perl ../$dirName/Makefile.PL >>$glcLogFile 2>&1
		    else
			perl -Mlocal::lib ../$dirName/Makefile.PL >>$glcLogFile 2>&1
		    fi
		else
		    echo "Can not locate Makefile.PL for ${modules[$i]}"
		    echo "Can not locate Makefile.PL for ${modules[$i]}" >>$glcLogFile
		    if [ "$catLogOnError" = yes ]; then
			cat $glcLogFile
		    fi
		    exit 1
		fi
		if [ $? -ne 0 ]; then
		    echo "Could not build Makefile for ${modules[$i]}"
		    echo "Could not build Makefile for ${modules[$i]}" >>$glcLogFile
		    if [ "$catLogOnError" = yes ]; then
			cat $glcLogFile
		    fi
		    exit 1
		fi
		# Make the package.
		make -j >>$glcLogFile 2>&1
		if [ $? -ne 0 ]; then
		    echo "Could not make ${modules[$i]}"
		    echo "Could not make ${modules[$i]}" >>$glcLogFile
		    if [ "$catLogOnError" = yes ]; then
			cat $glcLogFile
		    fi
		    exit 1
		fi
		# Run any tests of the package.
		make -j ${makeTest[$i]} >>$glcLogFile 2>&1
		if [ $? -ne 0 ]; then
		    logmessage "Testing ${modules[$i]} failed"
		    if [ "$catLogOnError" = yes ]; then
			cat $glcLogFile
		    fi
		    exit 1
		fi
		# Install the package.
		if [ $installAsRoot -eq 1 ]; then
		    echo "$rootPassword" | eval $suCommand make PATH=${PATH} install $suClose >>$glcLogFile 2>&1
		else
		    make install >>$glcLogFile 2>&1
		fi
		if [ $? -ne 0 ]; then
		    echo "Could not install ${modules[$i]}"
		    echo "Could not install ${modules[$i]}" >>$glcLogFile
		    if [ "$catLogOnError" = yes ]; then
			cat $glcLogFile
		    fi
		    exit 1
		fi
	    fi
	    # Try installing via CPAN.
	    if [[ $installDone -eq 0 &&  $installViaCPAN -eq 1 ]]; then
		logmessage "   Installing via CPAN"
		if [ ${modulesForce[$i]} -eq 1 ]; then
		    cpanInstall="force('install','${modules[$i]}')"
		else
		    cpanInstall="install ${modules[$i]}"
		fi
		if [ $installAsRoot -eq 1 ]; then
		    # Install as root.
                    export PERL_MM_USE_DEFAULT=1
		    if [ ${interactive[$i]} -eq 0 ]; then
			echo $suCommand perl -MCPAN -e "$cpanInstall" $suClose >>$glcLogFile 2>&1
			echo "$rootPassword" | eval $suCommand perl -MCPAN -e "$cpanInstall" $suClose >>$glcLogFile 2>&1
		    else
			echo $suCommand perl -MCPAN -e "$cpanInstall" $suClose >>$glcLogFile 2>&1
			echo "$rootPassword" | eval $suCommand perl -MCPAN -e "$cpanInstall" $suClose
		    fi
		else		    
                    # Check for local::lib.
		    logexec perl -e \"use local::lib\"
		    if [ $? -ne 0 ]; then
			wget https://cpan.metacpan.org/authors/id/H/HA/HAARG/local-lib-2.000029.tar.gz >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Failed to download local-lib-2.000029.tar.gz"
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
			    exit 1
			fi
			tar xvfz local-lib-2.000029.tar.gz >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Failed to unpack local-lib-2.000029.tar.gz"
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
			    exit 1
			fi
			cd local-lib-2.000029
			perl Makefile.PL --bootstrap >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Failed to bootstrap local-lib-2.000029"
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
			    exit 1
			fi
			make >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Failed to make local-lib-2.000029"
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
			    exit 1
			fi
			make test >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Tests of local-lib-2.000029 failed" >>$glcLogFile
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
			    exit 1
			fi
			make install >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Failed to install local-lib-2.000029"			    
			    if [ "$catLogOnError" = yes ]; then
				cat $glcLogFile
			    fi
			    exit 1
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
			logexec perl -Mlocal::lib -MCPAN -e \"$cpanInstall\"
		    else
			echo perl -Mlocal::lib -MCPAN -e "$cpanInstall" >>$glcLogFile
			perl -Mlocal::lib -MCPAN -e "$cpanInstall"
		    fi
		fi
		# Check that the module was installed successfully.
		logexec perl -e \"use $module\" >>/dev/null 2>&1
		if [ $? -ne 0 ]; then
		    logmessage "   ...failed"
		    if [ "$catLogOnError" = yes ]; then
			cat $glcLogFile
		    fi
		    exit 1
		fi
                installDone=1
	    fi
	    # We were unable to install the module by any method.
	    if [ $installDone -eq 0 ]; then
		echo "no method exists to install this module"
		echo "no method exists to install this module" >> $glcLogFile
		if [ "$catLogOnError" = yes ]; then
		    cat $glcLogFile
		fi
		exit 1;
	    fi
	fi
        # If we installed CPAN then make this an available method for future installs.
	if [[ $installViaCPAN -eq 0 && $module -eq "CPAN" ]]; then
	    installViaCPAN=1
	fi
    fi
    
done

# Retrieve Galacticus via Git.
if [[ $runningAsRoot -eq 1 ]]; then
    echo "Script is running as root - if you want to install Galacticus itself as a regular user, just quit (Ctrl-C) now."
fi
if [ -z ${cmdGalacticusPrefix} ]; then
    galacticusInstallPath=$HOME/Galacticus/galacticus
    read -p "Path to install Galacticus to [$galacticusInstallPath]: " RESPONSE
    if [ -n "$RESPONSE" ]; then
	galacticusInstallPath=$RESPONSE
    fi
else
    galacticusInstallPath=$cmdGalacticusPrefix
fi
if [ ! -e $galacticusInstallPath ]; then
    mkdir -p `dirname $galacticusInstallPath`
fi
if [[ $installLevel -eq -1 ]]; then
    logmessage "downloading Galacticus datasets tarball"
    cd `dirname $galacticusInstallPath`
    logexec wget https://github.com/galacticusorg/datasets/archive/masterRelease.tar.gz
    logexec tar xvfz masterRelease.tar.bz2
    mv datasets-masterRelease datasets
    cd -
else
    logmessage "cloning Galacticus"
    cd `dirname $galacticusInstallPath`
    logexec git clone https://github.com/galacticusorg/galacticus.git galacticus
    if [ $? -ne 0 ]; then
	logmessage "failed to download Galacticus"
	if [ "$catLogOnError" = yes ]; then
	    cat $glcLogFile
	fi
	exit 1
    fi
    logexec git clone https://github.com/galacticusorg/datasets.git datasets
    if [ $? -ne 0 ]; then
	logmessage "failed to download Galacticus datasets"
	if [ "$catLogOnError" = yes ]; then
	    cat $glcLogFile
	fi
	exit 1
    fi
    cd -
fi

# Add commands to .bashrc and/or .cshrc.
envSet=0
if [ -z ${cmdSetBash} ]; then
    read -p "Add a Galacticus environment alias to .bashrc? [no/yes]: " RESPONSE
else
    RESPONSE=$cmdSetBash
fi
if [ "$RESPONSE" = yes ] ; then
    envSet=1
    if [ -e $HOME/.bashrc ]; then
	awk 'BEGIN {inGLC=0} {if (index($0,"Alias to configure the environment to compile and run Galacticus) > 0) inGLC=1;if (inGLC == 0) print $0; if (inGLC == 1 && index($0,"'"'"'")) inGLC=0}' $HOME/.bashrc > $HOME/.bashrc.tmp
	mv -f $HOME/.bashrc.tmp $HOME/.bashrc
    fi
    echo "# Alias to configure the environment to compile and run Galacticus" >> $HOME/.bashrc
    echo "function galacticus() {" >> $HOME/.bashrc
    echo " if [ -n \"\${LD_LIBRARY_PATH}\" ]; then" >> $HOME/.bashrc
    echo "  export LD_LIBRARY_PATH=$toolInstallPath/lib:$toolInstallPath/lib64:\$LD_LIBRARY_PATH" >> $HOME/.bashrc
    echo " else" >> $HOME/.bashrc
    echo "  export LD_LIBRARY_PATH=$toolInstallPath/lib:$toolInstallPath/lib64" >> $HOME/.bashrc
    echo " fi" >> $HOME/.bashrc
    echo " if [ -n \"\${PATH}\" ]; then" >> $HOME/.bashrc
    echo "  export PATH=$toolInstallPath/bin:\$PATH" >> $HOME/.bashrc
    echo " else" >> $HOME/.bashrc
    echo "  export PATH=$toolInstallPath/bin" >> $HOME/.bashrc
    echo " fi" >> $HOME/.bashrc
    if [ -e $HOME/perl5/lib/perl5/local/lib.pm ]; then
	echo " eval \$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)" >> $HOME/.bashrc
    fi
    echo " export GALACTICUS_FCFLAGS=\"-fintrinsic-modules-path $toolInstallPath/finclude -fintrinsic-modules-path $toolInstallPath/include -fintrinsic-modules-path $toolInstallPath/include/gfortran -fintrinsic-modules-path $toolInstallPath/lib/gfortran/modules $libDirs\"" >> $HOME/.bashrc
    echo " export GALACTICUS_CFLAGS=\"$libDirs -I$toolInstallPath/include\"" >> $HOME/.bashrc
    echo " export GALACTICUS_EXEC_PATH=`dirname $galacticusInstallPath`/galacticus" >> $HOME/.bashrc
    echo " export GALACTICUS_DATA_PATH=`dirname $galacticusInstallPath`/datasets" >> $HOME/.bashrc
    echo "}" >> $HOME/.bashrc
fi
if [ -z ${cmdSetCShell} ]; then
    read -p "Add a Galacticus environment alias to .cshrc? [no/yes]: " RESPONSE
else
    RESPONSE=$cmdSetCShell
fi
if [ "$RESPONSE" = yes ] ; then
    envSet=1
    if [ -e $HOME/.cshrc ]; then
	awk 'BEGIN {inGLC=0} {if (index($0,"Alias to configure the environment to compile and run Galacticus") > 0) inGLC=1;if (inGLC == 0) print $0; if (inGLC == 1 && index($0,"'"'"'")) inGLC=0}' $HOME/.cshrc > $HOME/.cshrc.tmp
	mv -f $HOME/.cshrc.tmp $HOME/.cshrc
    fi
    echo "# Alias to configure the environment to compile and run Galacticus" >> $HOME/.cshrc
    echo "alias galacticus 'if ( \$?LD_LIBRARY_PATH ) then \\" >> $HOME/.cshrc
    echo " setenv LD_LIBRARY_PATH $toolInstallPath/lib:$toolInstallPath/lib64:\$LD_LIBRARY_PATH \\" >> $HOME/.cshrc
    echo "else \\" >> $HOME/.cshrc
    echo " setenv LD_LIBRARY_PATH $toolInstallPath/lib:$toolInstallPath/lib64 \\" >> $HOME/.cshrc
    echo "endif \\" >> $HOME/.cshrc
    echo "if ( \$?PATH ) then \\" >> $HOME/.cshrc
    echo " setenv PATH $toolInstallPath/bin:\$PATH \\" >> $HOME/.cshrc
    echo "else \\" >> $HOME/.cshrc
    echo " setenv PATH $toolInstallPath/bin \\" >> $HOME/.cshrc
    echo "endif \\" >> $HOME/.cshrc
    if [ -e $HOME/perl5/lib/perl5/local/lib.pm ]; then
	echo "eval \`perl -I$HOME/perl5/lib/perl5 -Mlocal::lib\` \\" >> $HOME/.cshrc
    fi
    echo "setenv GALACTICUS_FCFLAGS \"-fintrinsic-modules-path $toolInstallPath/finclude -fintrinsic-modules-path $toolInstallPath/include -fintrinsic-modules-path $toolInstallPath/include/gfortran -fintrinsic-modules-path $toolInstallPath/lib/gfortran/modules $libDirs\"" >> $HOME/.cshrc
    echo "setenv GALACTICUS_CFLAGS \"$libDirs -I$toolInstallPath/include\"" >> $HOME/.cshrc
    echo "setenv GALACTICUS_EXEC_PATH `dirname $galacticusInstallPath`/galacticus" >> $HOME/.cshrc
    echo "setenv GALACTICUS_DATA_PATH `dirname $galacticusInstallPath`/datasets'" >> $HOME/.cshrc
fi

# Determine if we want to install from source, or use the static binary.
cd $galacticusInstallPath
if [[ $installLevel -eq -1 ]]; then
    # Install the binary executable.
    logexec wget https://github.com/galacticusorg/galacticus/releases/download/masterRelease/galacticus.exe -O $galacticusInstallPath/Galacticus.exe
    logexec chmod u+rx $galacticusInstallPath/Galacticus.exe
else
    
    # Hardwired magic.
    # Figure out which libstdc++ we should use. This is necessary because some
    # distributions (Ubuntu.....) don't find -lstdc++ when linking using gfortran.
    echo "main() {}" > dummy.c
    logexec gcc dummy.c -lstdc++
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
    
    # Build Galacticus.
    if [ ! -e Galacticus.exe ]; then
	export GALACTICUS_FCFLAGS=$moduleDirs
	export GALACTICUS_CFLAGS=$libDirs -I$toolInstallPath/include
	logexec make -j$coreCount Galacticus.exe
	if [ $? -ne 0 ]; then
	    logmessage "failed to build Galacticus"
	    if [ "$catLogOnError" = yes ]; then
		cat $glcLogFile
	    fi
	    exit 1
	fi
    fi
fi

# Run a test case.
echo "Running a quick test of Galacticus - should take around 1 minute on a single core (less time if you have multiple cores)"
echo "Running a quick test of Galacticus - should take around 1 minute on a single core (less time if you have multiple cores)" >> $glcLogFile
export GALACTICUS_EXEC_PATH=`dirname $galacticusInstallPath`/galacticus
export GALACTICUS_DATA_PATH=`dirname $galacticusInstallPath`/datasets
logexec ./Galacticus.exe parameters/quickTest.xml
if [ $? -ne 0 ]; then
    logmessage "failed to run Galacticus"
    if [ "$catLogOnError" = yes ]; then
	cat $glcLogFile
    fi
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
    echo "You should execute the command \"galacticus\" before attempting to use Galacticus to configure all environment variables, library paths etc."
    echo "You should execute the command \"galacticus\" before attempting to use Galacticus to configure all environment variables, library paths etc." >> $glcLogFile
else
    if [ $installAsRoot -eq 1 ]; then
	echo "If you installed Galacticus libraries and tools in a non-standard location you may need to set environment variables appropriately to find them. You will also need to set appropriate -fintrinsic-modules-path and -L options in the GALACTICUS_FCFLAGS variable of Galacticus' Makefile so that it know where to find installed modules and libraries."
	echo "If you installed Galacticus libraries and tools in a non-standard location you may need to set environment variables appropriately to find them. You will also need to set appropriate -fintrinsic-modules-path and -L options in the GALACTICUS_FCFLAGS variable of Galacticus' Makefile so that it know where to find installed modules and libraries." >> $glcLogFile
    else
	echo "You may need to set environment variables to permit libraries and tools installed to be found. You will also need to set appropriate -fintrinsic-modules-path and -L options in the GALACTICUS_FCFLAGS variable of Galacticus' Makefile so that it know where to find installed modules and libraries."
	echo "You may need to set environment variables to permit libraries and tools installed to be found. You will also need to set appropriate -fintrinsic-modules-path and -L options in the GALACTICUS_FCFLAGS variable of Galacticus' Makefile so that it know where to find installed modules and libraries." >> $glcLogFile
    fi
fi
exit 0
