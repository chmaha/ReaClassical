#!/bin/sh
set -e  # exit immediately on any command failure

echo "Building ReaClassical installers..."

makeself "Makeself builds/linux" ReaClassical_Linux_Install.run \
    "ReaClassical Linux Installer" ./install.sh

makeself "Makeself builds/macos" ReaClassical_MacOS_Install.run \
    "ReaClassical MacOS Installer" ./install.sh


cd win_go_installer

GOOS=windows GOARCH=amd64 go build -o ../ReaClassical_Win64.exe .
GOOS=windows GOARCH=386 go build -o ../ReaClassical_Win32.exe .
GOOS=windows GOARCH=arm64 go build -o ../ReaClassical_Win11_arm64ec_beta.exe .

echo "✅ All installers built successfully!"
