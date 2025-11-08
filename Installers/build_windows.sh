#!/bin/sh
set -e  # exit immediately on any command failure

echo
echo "============================================"
echo " Building Windows ReaClassical installer... "
echo "============================================"
echo
sleep 2
src="../ReaClassical"
zip_file="Resource_Folder_Base.zip"
win_dir="src/windows"
mkdir -p "$win_dir"

(
  cd "$src" || exit 1
  zip -rq "$OLDPWD/$win_dir/$zip_file" .
)

mkdir -p builds

GOOS=windows GOARCH=amd64 go build -C "$win_dir" -o "../../builds/ReaClassical_Win64.exe"
GOOS=windows GOARCH=386   go build -C "$win_dir" -o "../../builds/ReaClassical_Win32.exe"
GOOS=windows GOARCH=arm64 go build -C "$win_dir" -o "../../builds/ReaClassical_Win11_arm64ec_beta.exe"

echo "✅ All Windows installers built successfully!"
