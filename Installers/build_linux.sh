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
expected_files=14
mkdir -p "$linux_dir"

(
  cd "$src" || exit 1
  zip -rq "$OLDPWD/$linux_dir/$zip_file" .
)

# Check that there are exactly 14 files in linux_dir
file_count=$(find "$linux_dir" -maxdepth 1 -type f | wc -l)
if [ "$file_count" -ne $expected_files ]; then
  echo "❌ Error: Expected $expected_files files in $linux_dir, but found $file_count."
  exit 1
fi

mkdir -p builds

makeself "$linux_dir" builds/ReaClassical_Linux_Install.run \
    "ReaClassical Linux Installer" ./install.sh

echo "✅ Linux Installer built successfully!"
