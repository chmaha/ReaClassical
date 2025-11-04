#!/bin/sh

# Script to create ReaClassical resource folder
#
# by chmaha (Jan 2025)

dir="$HOME/Downloads/Resource_Folder_Base"
mkdir -p "$dir"

# Source directory
src="$HOME/Desktop/ReaClassical_26/"

# List of files and directories to copy
files="BR.ini
ColorThemes/ReaClassical Light.ReaperThemeZip
ColorThemes/ReaClassical WaveColors Dark.ReaperThemeZip
ColorThemes/ReaClassical WaveColors Light.ReaperThemeZip
ColorThemes/ReaClassical.ReaperThemeZip
Data/toolbar_icons/Dest IN.png
Data/toolbar_icons/Dest OUT.png
Data/toolbar_icons/source IN.png
Data/toolbar_icons/source OUT.png
Data/toolbar_icons/Delete SD Markers.png
Data/toolbar_icons/SD Edit.png
Data/toolbar_icons/toolbar_item_next.png
Data/toolbar_icons/Insert with timestretching.png
Data/toolbar_icons/delete with ripple.png
Data/toolbar_icons/delete leaving silence.png
Data/toolbar_icons/Set_Dest_Proj.png
Data/toolbar_icons/Set_Source_Proj.png
Data/toolbar_icons/Delete SD Project Markers.png
Data/toolbar_icons/toolbar_misc_question_random.png
Data/toolbar_icons/toolbar_razor_off.png
Data/toolbar_icons/toolbar_marquee_cursor_selection_off.png
Data/toolbar_icons/animation_toolbar_armed.png
Data/toolbar_icons/animation_toolbar_highlight.png
Data/toolbar_icons/copy_dest_material.png
Data/toolbar_icons/move_dest_material.png
Data/toolbar_icons/Reverse SD Edit.png
Data/toolbar_icons/assembly.png
Effects/ReJJ/
Effects/chmaha Scripts/
Effects/chmaha airwindows JSFX Ports
MenuSets/
ProjectTemplates/ReaClassical.RPP
ProjectTemplates/Room_Tone_Generation.RPP
Scripts/ReaTeam Scripts/Development/cfillion_Interactive ReaScript.lua
Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua
Scripts/chmaha Scripts/
reaper-convertmetadata.ini
reaper-fxfolders.ini
reaper-hwoutfx.ini
reaper-kb.ini
reaper-menu.ini
reaper-render.ini
reaper-render2.ini
reaper-themeconfig.ini
sws-autocoloricon.ini
reaper-install-rev.txt
reaper-mouse.ini
reaper-wndpos.ini
reaper.ini"

# Loop through each file and directory
echo "$files" | while IFS= read -r item; do
    src_path="$src/$item"
    dest_path="$dir/$item"

    if [ -e "$src_path" ]; then
        # Create the destination directory if it doesn't exist
        mkdir -p "$(dirname "$dest_path")"

        # Copy the file or directory
        cp -r "$src_path" "$dest_path"
    else
        echo "Warning: $src_path does not exist"
    fi
done

echo "Files copied to $dir successfully."

touch $dir/rc_portable

echo "Removing references to chmaha and plugin search history..."

sed -i '/home\/chmaha/d;/media\/chmaha/d;/Users\\xxx/d;/Users\\chmaha/d;/^RecentFX/d;/\/mnt\//d;/\/tmp/d;/^Count=/d;/^autonbworkerthreads/d;/^workthreads/d;\|D:/|d' $dir/reaper.ini

echo "Copying keymap, menu, project template and theme files..."

cp $dir/reaper.ini ~/code/chmaha/ReaClassical/ReaClassical/ReaClassical.ini
cp $dir/reaper.ini "$dir/Scripts/chmaha Scripts/ReaClassical/ReaClassical.ini"
cp $dir/reaper.ini "$src/Scripts/chmaha Scripts/ReaClassical/ReaClassical.ini"

cp $dir/reaper-kb.ini ~/code/chmaha/ReaClassical/ReaClassical/ReaClassical-kb.ini
cp $dir/reaper-kb.ini "$dir/Scripts/chmaha Scripts/ReaClassical/ReaClassical-kb.ini"
cp $dir/reaper-kb.ini "$src/Scripts/chmaha Scripts/ReaClassical/ReaClassical-kb.ini"

cp $dir/reaper-menu.ini ~/code/chmaha/ReaClassical/ReaClassical/ReaClassical-menu.ini
cp $dir/reaper-menu.ini "$dir/Scripts/chmaha Scripts/ReaClassical/ReaClassical-menu.ini"
cp $dir/reaper-menu.ini "$src/Scripts/chmaha Scripts/ReaClassical/ReaClassical-menu.ini"

cp $dir/reaper-render.ini ~/code/chmaha/ReaClassical/ReaClassical/ReaClassical-render.ini
cp $dir/reaper-render.ini "$dir/Scripts/chmaha Scripts/ReaClassical/ReaClassical-render.ini"
cp $dir/reaper-render.ini "$src/Scripts/chmaha Scripts/ReaClassical/ReaClassical-render.ini"

cp ~/code/chmaha/ReaClassical/PDF-Manual/ReaClassical-Manual.pdf "$dir/Scripts/chmaha Scripts/ReaClassical/ReaClassical-Manual.pdf"

cp $dir/ProjectTemplates/ReaClassical.RPP ~/code/chmaha/ReaClassical/ReaClassical/
cp $dir/ProjectTemplates/Room_Tone_Generation.RPP ~/code/chmaha/ReaClassical/ReaClassical/
cp "$dir/ColorThemes/ReaClassical Light.ReaperThemeZip" ~/code/chmaha/ReaClassical/ReaClassical/
cp "$dir/ColorThemes/ReaClassical WaveColors Dark.ReaperThemeZip" ~/code/chmaha/ReaClassical/ReaClassical/
cp "$dir/ColorThemes/ReaClassical WaveColors Light.ReaperThemeZip" ~/code/chmaha/ReaClassical/ReaClassical/
cp "$dir/ColorThemes/ReaClassical.ReaperThemeZip" ~/code/chmaha/ReaClassical/ReaClassical/

echo "Zipping resource folder base..."

cd $dir
zip -rq Resource_Folder_Base.zip .

echo "Deleting old zipped Resource Folder Base in ReaClassical code directory..."

rm ~/code/chmaha/ReaClassical/Resource\ Folder/Resource_Folder_Base.zip

echo "Moving new zipped Resource Folder Base to ReaClassical code directory..."

mv $dir/Resource_Folder_Base.zip ~/code/chmaha/ReaClassical/Resource\ Folder/

echo "Removing Resource Folder Base..."

rm -r ~/Downloads/Resource_Folder_Base

echo "Done!"
