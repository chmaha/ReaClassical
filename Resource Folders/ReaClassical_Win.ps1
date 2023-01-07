# Powershell script to install ReaClassical on Windows-x64
# by chmaha (Jan 2023)

# Instructions: Run script in the location you would like ReaClassical installed.
# Change the pkgver number below to download an alternative version of REAPER.

##############
$pkgver="6.73"
##############

Write-Host "Welcome to ReaClassical installer..."
sleep 2

Write-Host "Downloading and extracting portable 7-zip..."
sleep 2
Invoke-WebRequest -Uri https://github.com/chmaha/7-zip/raw/main/7zip.zip -OutFile 7zip.zip
Expand-Archive -Path .\7zip.zip -DestinationPath ./7zip
rm 7zip.zip

Write-Host "Downloading REAPER $pkgver from reaper.fm"
sleep 2

$first=$pkgver.split('.')[0]
$second=$pkgver.split('.')[1]
Invoke-WebRequest -Uri https://www.reaper.fm/files/$first.x/reaper$($first + $second)_x64-install.exe -OutFile reaper$($first + $second)_x64-install.exe

Write-Host "Extracting REAPER from .exe to ReaClassical folder..."
sleep 2

.\7zip\7z.exe x .\reaper$($first + $second)_x64-install.exe -oReaClassical | Out-Null

Write-Host "Downloading ReaClassical files from Github..."
sleep 2

Invoke-WebRequest -Uri https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/Resource_Folder_Base.zip -OutFile Resource_Folder_Base.zip
Invoke-WebRequest -Uri https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_Windows-x64.zip -OutFile UP_Windows-x64.zip

Write-Host "Extracting ReaClassical files to ReaClassical folder"
sleep 2

Expand-Archive -LiteralPath .\Resource_Folder_Base.zip -DestinationPath ReaClassical
Expand-Archive -LiteralPath .\UP_Windows-x64.zip -DestinationPath .\ReaClassical\UserPlugins

Write-Host "Removing temporary files..."
sleep 2

rm .\Resource_Folder_Base.zip, .\UP_Windows-x64.zip, .\reaper673_x64-install.exe
rm -Recurse .\7zip\

Write-Host "Done!"
sleep 2
