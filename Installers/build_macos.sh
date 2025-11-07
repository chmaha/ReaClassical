#!/bin/sh
set -e  # exit immediately on any command failure

echo
echo "============================================"
echo " Building MacOS ReaClassical installer... "
echo "============================================"
echo
sleep 2
src="../Resource_Folder"
zip_file="Resource_Folder_Base.zip"
macos_dir="src/macos"
mkdir -p "$macos_dir"

(
  cd "$src" || exit 1
  zip -rq "$OLDPWD/$macos_dir/$zip_file" .
)

mkdir -p builds

makeself "$macos_dir" builds/ReaClassical_MacOS_Install.run \
    "ReaClassical MacOS Installer" ./install.sh

echo "✅ MacOS Installer built successfully!"
