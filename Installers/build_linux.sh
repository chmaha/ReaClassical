#!/bin/sh
set -e  # exit immediately on any command failure

echo "============================================"
echo " Building Linux ReaClassical installer... "
echo "============================================"
echo
sleep 2
src="../ReaClassical"
zip_file="Resource_Folder_Base.zip"
linux_dir="src/linux"
mkdir -p "$linux_dir"

(
  cd "$src" || exit 1
  zip -rq "$OLDPWD/$linux_dir/$zip_file" .
)

mkdir -p builds

makeself "$linux_dir" builds/ReaClassical_Linux_Install.run \
    "ReaClassical Linux Installer" ./install.sh

echo "✅ Linux Installer built successfully!"
