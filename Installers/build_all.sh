#!/bin/sh
set -e  # exit immediately on any command failure

( sh build_linux.sh )
( sh build_macos.sh )
( sh build_windows.sh )

echo
echo "============================================"
echo "......All Builds completed succesfully......"
echo "============================================"
echo
