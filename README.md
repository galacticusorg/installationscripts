# Galacticus Installation Scripts

Installation scripts for the [Galacticus](https://github.com/galacticusorg/galacticus) semi-analytic galaxy formation model.

This repo contains scripts which attempt to install Galacticus, together with all of the tools and libraries that it depends on. They are intended for use on Linux and macOS systems. Where a dependency is not already available (or is too old), the scripts will install it — either via the system package manager or by compiling it from source. See the [wiki](https://github.com/galacticusorg/installationscripts/wiki) for full details.

There are two scripts:

| Script                      | Platform | Notes                                                              |
| --------------------------- | -------- | ------------------------------------------------------------------ |
| `galacticusInstall.sh`      | Linux    | Highly configurable; can install as root or as a regular user.     |
| `galacticusInstallMacOS.sh` | macOS    | Uses [MacPorts](https://www.macports.org/) plus a prebuilt GCC 16. |

## Linux: `galacticusInstall.sh`

### Quick start

Run the script with no arguments and it will prompt you interactively for everything it needs:

```bash
./galacticusInstall.sh
```

Alternatively, supply any (or all) of the options below to run non-interactively — any option you omit will still be prompted for. This is the recommended way to drive the script in scripted/CI environments.

```bash
./galacticusInstall.sh \
    --toolPrefix=$HOME/Galacticus/Tools \
    --galacticusPrefix=$HOME/Galacticus/galacticus \
    --asRoot=no \
    --installLevel=minimal \
    --cores=4 \
    --packageManager=no \
    --setBash=yes \
    --setCShell=no
```

### Options

Options use the form `--option=value` (note the `=`; a space will not work). All are optional — anything not specified on the command line is requested interactively.

| Option                    | Values                     | Description                                                                                                                                  |
| ------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `--toolPrefix=PATH`       | path                       | Where to install supporting tools and libraries. Defaults to `/usr/local/galacticus` (root) or `$HOME/Galacticus/Tools` (regular user).     |
| `--galacticusPrefix=PATH` | path                       | Where to install Galacticus itself. Defaults to `$HOME/Galacticus/galacticus`.                                                              |
| `--asRoot=`               | `yes` \| `no`              | Install required libraries as root (needed to write to system locations or use the package manager).                                        |
| `--rootPwd=`              | password                   | The root/sudo password, used when `--asRoot=yes`. (Avoid passing this on shared systems — it may be visible in your shell history.)         |
| `--suMethod=`             | `su` \| `sudo`             | Which command to use to gain root for root installs.                                                                                        |
| `--packageManager=`       | `yes` \| `no`              | When installing as root, use the system package manager (`yum`/`apt`) where a suitable version is available, instead of building from source. |
| `--installLevel=`         | `binary` \| `minimal` \| `full` | How much to install (see below).                                                                                                       |
| `--cores=`                | integer                    | Number of CPU cores to use when compiling.                                                                                                  |
| `--setBash=`              | `yes` \| `no`              | Add a `galacticus` shell function to `~/.bashrc` that configures the environment (paths, flags) needed to build and run Galacticus.         |
| `--setCShell=`            | `yes` \| `no`              | As `--setBash`, but adds a `galacticus` alias to `~/.cshrc`.                                                                                |
| `--ignoreFailures=`       | `yes` \| `no`              | If a package cannot be installed from source, continue anyway (`yes`) rather than aborting (`no`). Continuing may lead to later errors.     |
| `--catLogOnError=`        | `yes` \| `no`              | On error, print the full install log to standard output. Useful in CI where the log file is otherwise inaccessible. Default `no`.           |
| `--cleanUp=`              | `yes` \| `no`              | After each successful install from source, remove the downloaded tarball (or cloned repo) and the unpacked source/build directories to reduce disk-space usage. Default `no` (keep them). |
| `--force-PACKAGE`         | (flag)                     | Force (re)installation of a specific package even if a suitable version is already present, e.g. `--force-hdf5`, `--force-gsl`, `--force-gcc`. |

### Install levels

* **`binary`** — Download the prebuilt `Galacticus.exe` static binary plus the datasets needed to run it. No compilation of Galacticus itself.
* **`minimal`** — Install just enough tools and libraries to compile and run Galacticus, then clone and build it from source.
* **`full`** — As `minimal`, plus additional optional libraries (e.g. FFTW3, ANN, QHull).

### What the script does

1. Creates a working directory, `galacticusInstallWork`, beneath the current directory and performs all downloads and source builds there.
2. Checks each required tool/library; if it is missing or out of the supported version range, installs it via the package manager (if enabled) or from source.
3. Clones Galacticus and its datasets, creates a Python virtual environment, and installs Galacticus' Python build dependencies (for non-`binary` installs).
4. Builds `Galacticus.exe` (for non-`binary` installs) and runs a short test case (`parameters/quickTest.xml`, ~1 minute) to verify the installation.

A log of the entire run is written to `galacticusInstall.log` in the directory from which you launched the script. Once finished, the `galacticusInstallWork` directory can be safely deleted.

If you opted in to `--setBash`/`--setCShell`, run `galacticus` in a new shell to configure the environment before using Galacticus.

## macOS: `galacticusInstallMacOS.sh`

This script takes no options — simply run it:

```bash
./galacticusInstallMacOS.sh
```

Notes:

* You will need `sudo` privileges and will be prompted for your password (possibly several times) during the installation.
* If prompted to make a choice during installation, accept the default (just press <kbd>Enter</kbd>).
* If a pop-up appears saying *“Terminal” would like to administer your computer*, approve it.
* It installs the Xcode command-line tools, [MacPorts](https://www.macports.org/), and a prebuilt GCC 16, then builds the remaining dependencies (HDF5, FoX, FFTW, ANN, …) from source before cloning and building Galacticus.

This script should be considered a **beta release**. If you run into problems, please report them on the [Galacticus discussion forum](https://github.com/galacticusorg/galacticus/discussions).
