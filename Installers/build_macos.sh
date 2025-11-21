#!/bin/sh
set -e  # exit immediately on any command failure

echo
echo "============================================"
echo " Building MacOS ReaClassical installer... "
echo "============================================"
echo
sleep 2
src="../ReaClassical"
zip_file="Resource_Folder_Base.zip"
macos_dir="src/macos"
expected_files=11
mkdir -p "$macos_dir"

(
  cd "$src" || exit 1
  zip -rq "$OLDPWD/$macos_dir/$zip_file" .
)

# Check that there are exactly 14 files in linux_dir
file_count=$(find "$macos_dir" -maxdepth 1 -type f | wc -l)
if [ "$file_count" -ne $expected_files ]; then
  echo "❌ Error: Expected $expected_files files in $macos_dir, but found $file_count."
  exit 1
fi

mkdir -p builds

makeself "$macos_dir" builds/ReaClassical_MacOS_Install.run \
    "ReaClassical MacOS Installer" ./install.sh

echo "✅ MacOS Installer built successfully!"
