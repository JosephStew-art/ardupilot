#!/bin/bash

# script to build cygwin binaries for using in MissionPlanner
# the contents of artifacts directory is uploaded to:
# https://firmware.ardupilot.org/Tools/MissionPlanner/sitl/

# the script assumes you start in the root of the ardupilot git tree

set -ex

echo "=== Cygwin Build Script Starting ==="
echo "Working directory: $(pwd)"
echo "User: $(whoami)"
echo "PATH: $PATH"

# TOOLCHAIN=i686-pc-cygwin
TOOLCHAIN=x86_64-pc-cygwin
GPP_COMPILER="${TOOLCHAIN}-g++"

echo "=== Checking Toolchain ==="
echo "TOOLCHAIN: $TOOLCHAIN"
echo "GPP_COMPILER: $GPP_COMPILER"

# Check if compiler exists
if ! command -v $GPP_COMPILER &> /dev/null; then
    echo "ERROR: Compiler $GPP_COMPILER not found"
    echo "Available compilers:"
    ls -la /usr/bin/*gcc* || echo "No GCC compilers found"
    exit 1
fi

echo "Compiler found: $(which $GPP_COMPILER)"
$GPP_COMPILER --version

SYS_ROOT=$($GPP_COMPILER -print-sysroot)
echo "SYS_ROOT=$SYS_ROOT"

echo "=== Git Configuration ==="
git config --global --add safe.directory /cygdrive/d/a/ardupilot/ardupilot
git config --global --add safe.directory '*'

echo "Git status:"
git status || echo "Git status failed"

# Initialize and update submodules
echo "=== Initializing git submodules ==="
echo "Current submodule status:"
git submodule status || echo "Submodule status failed"

echo "Updating submodules..."
if ! git submodule update --init --recursive --depth 1; then
    echo "ERROR: Submodule update failed"
    echo "Trying alternative submodule update..."
    git submodule update --init --recursive || exit 1
fi

echo "Submodule update completed"

rm -rf artifacts
mkdir artifacts

# Build with error checking
echo "Configuring build..."
if ! python ./waf --color yes --toolchain $TOOLCHAIN --board sitl configure 2>&1 | tee artifacts/build.txt; then
    echo "ERROR: Configuration failed"
    exit 1
fi

echo "Building ArduPlane..."
if ! python ./waf plane 2>&1 | tee -a artifacts/build.txt; then
    echo "ERROR: Build failed"
    exit 1
fi

# python ./waf copter 2>&1
# python ./waf heli 2>&1
# python ./waf rover 2>&1
# python ./waf sub 2>&1

# Check if build produced the expected binary
if [ ! -f "build/sitl/bin/arduplane" ]; then
    echo "ERROR: ArduPlane binary not found at build/sitl/bin/arduplane"
    echo "Build directory contents:"
    find build -name "arduplane*" -o -name "*.elf" -o -name "*.exe" 2>/dev/null || echo "No build files found"
    exit 1
fi

# copy both with exe and without to cope with differences
# between windows versions in CI
echo "Copying ArduPlane binaries..."
cp -v build/sitl/bin/arduplane artifacts/ArduPlane.elf.exe
cp -v build/sitl/bin/arduplane artifacts/ArduPlane.elf

# cp -v build/sitl/bin/arducopter artifacts/ArduCopter.elf.exe
# cp -v build/sitl/bin/arducopter-heli artifacts/ArduHeli.elf.exe
# cp -v build/sitl/bin/ardurover artifacts/ArduRover.elf.exe
# cp -v build/sitl/bin/ardusub artifacts/ArduSub.elf.exe

# cp -v build/sitl/bin/arducopter artifacts/ArduCopter.elf
# cp -v build/sitl/bin/arducopter-heli artifacts/ArduHeli.elf
# cp -v build/sitl/bin/ardurover artifacts/ArduRover.elf
# cp -v build/sitl/bin/ardusub artifacts/ArduSub.elf

# Find all cyg*.dll files returned by cygcheck for each exe in artifacts
# and copy them over
for exe in artifacts/*.exe; do 
    echo $exe
    cygcheck $exe | grep -oP 'cyg[^\s\\/]+\.dll' | while read -r line; do
      cp -v /usr/bin/$line artifacts/
    done
done

git log -1 > artifacts/git.txt
ls -l artifacts/
