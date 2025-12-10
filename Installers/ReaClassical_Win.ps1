# PowerShell script to install ReaClassical on Windows
# Works for x64 architecture compatible with REAPER

# Copyright (C) 2022–2025 chmaha

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

$rcver = "26"
$tempDir = $null

# Detect system architecture
$systemArch = $env:PROCESSOR_ARCHITECTURE
if ($systemArch -eq "AMD64") {
    $arch = "x64"
} elseif ($systemArch -eq "ARM64") {
    $arch = "arm64ec"
} elseif ($systemArch -eq "x86") {
    $arch = "x86"
} else {
    Write-Host "Unknown architecture: $systemArch"
    exit 1
}

function Cleanup {
    if ($tempDir -and (Test-Path $tempDir)) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Check-Internet {
    try {
        $ping = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction Stop
        if (-not $ping) {
            throw
        }
    }
    catch {
        Write-Host "`nError: The ReaClassical installer requires an internet connection."
        Write-Host "Enable the connection if possible or transfer the portable install from an online machine."
        Write-Host "Exiting...`n"
        exit 1
    }
}

# Ensure cleanup runs on exit
trap {
    Cleanup
    break
}

Check-Internet

$verTxt = "https://raw.githubusercontent.com/chmaha/ReaClassical/v26/tested_reaper_ver.txt"
$verContent = Invoke-WebRequest -Uri $verTxt -UseBasicParsing | Select-Object -ExpandProperty Content
$ver = ($verContent -split "`n" | Select-String -Pattern "====" -Context 0,1).Context.PostContext[0].Trim()

$major = $ver.Split('.')[0]
$minor = $ver.Split('.')[1]
$rcfolder = "ReaClassical_$rcver"

Write-Host "Welcome to the ReaClassical installer...`n"
Start-Sleep -Seconds 2
Write-Host "Versions: REAPER $ver ($arch), ReaClassical $rcver`n"
Start-Sleep -Seconds 2

# Create unique date suffix
$dateSuffix = -join ((Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes([DateTimeOffset]::Now.ToUnixTimeSeconds()))) -Algorithm SHA256).Hash[0..4] | ForEach-Object { $_.ToString("x2") })

# Create temporary directory
$tempDir = Join-Path $env:TEMP "ReaClassical_$dateSuffix"
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

Write-Host "Downloading REAPER from reaper.fm..."
Start-Sleep -Seconds 2

# Build REAPER download URL based on architecture
if ($arch -eq "x64") {
    $reaperOutput = Join-Path $tempDir "reaper$($major)$($minor)_x64-install.exe"
    $reaperUrl = "https://www.reaper.fm/files/$major.x/reaper$($major)$($minor)_x64-install.exe"
} elseif ($arch -eq "arm64ec") {
    $reaperOutput = Join-Path $tempDir "reaper$($major)$($minor)_win11_arm64ec_beta-install.exe"
    $reaperUrl = "https://www.reaper.fm/files/$major.x/reaper$($major)$($minor)_win11_arm64ec_beta-install.exe"
} elseif ($arch -eq "x86") {
    $reaperOutput = Join-Path $tempDir "reaper$($major)$($minor)-install.exe"
    $reaperUrl = "https://www.reaper.fm/files/$major.x/reaper$($major)$($minor)-install.exe"
}

Invoke-WebRequest -Uri $reaperUrl -OutFile $reaperOutput -UseBasicParsing

# Check if ReaClassical folder already exists
if (Test-Path "ReaClassical_$rcver") {
    $rcfolder = "ReaClassical_$($rcver)_$dateSuffix"
    Start-Sleep -Seconds 2
    Write-Host "Folder ReaClassical_$rcver already exists. Adding unique identifier as suffix."
}

Start-Sleep -Seconds 2
Write-Host "Extracting files from REAPER archive to $rcfolder folder"

# Download portable 7-zip for extraction
$sevenZipPath = Join-Path $tempDir "7zip"
$sevenZipZip = Join-Path $tempDir "7zip.zip"
Invoke-WebRequest -Uri "https://github.com/chmaha/7zip/raw/main/7zip.zip" -OutFile $sevenZipZip -UseBasicParsing
Expand-Archive -Path $sevenZipZip -DestinationPath $sevenZipPath -Force

# Extract REAPER exe to temp directory
$reaperExtract = Join-Path $tempDir "reaper_extract"
& "$sevenZipPath\7z.exe" x $reaperOutput "-o$reaperExtract" -y | Out-Null

# Move extracted REAPER files to final folder
New-Item -Path $rcfolder -ItemType Directory -Force | Out-Null
Get-ChildItem -Path $reaperExtract -Recurse | Move-Item -Destination $rcfolder -Force

Write-Host "Downloading ReaClassical files from Github..."
Start-Sleep -Seconds 2
$resOutput = Join-Path $tempDir "Resource_Folder_Base.zip"
$resUrl = "https://github.com/chmaha/ReaClassical/raw/v25/Resource%20Folder/Resource_Folder_Base.zip"
Invoke-WebRequest -Uri $resUrl -OutFile $resOutput -UseBasicParsing

$upOutput = Join-Path $tempDir "UP_Windows-$arch.zip"
$upUrl = "https://github.com/chmaha/ReaClassical/raw/v25/Resource%20Folder/UserPlugins/UP_Windows-$arch.zip"
Invoke-WebRequest -Uri $upUrl -OutFile $upOutput -UseBasicParsing

Start-Sleep -Seconds 2
Expand-Archive -Path $resOutput -DestinationPath $rcfolder -Force
Expand-Archive -Path $upOutput -DestinationPath (Join-Path $rcfolder "UserPlugins") -Force

# Get absolute path of rcfolder
$rcfolderPath = (Resolve-Path $rcfolder).Path

Start-Sleep -Seconds 2
Write-Host "Adding the ReaClassical theme reference to reaper.ini"
$iniPath = Join-Path $rcfolder "reaper.ini"
$iniContent = Get-Content $iniPath
$newContent = @()
foreach ($line in $iniContent) {
    $newContent += $line
    if ($line -eq "[REAPER]") {
        $newContent += "lastthemefn5=$rcfolderPath\ColorThemes\ReaClassical.ReaperTheme"
    }
}
$newContent | Set-Content $iniPath

Start-Sleep -Seconds 2
Write-Host "Adding the ReaClassical splash to reaper.ini"
$iniContent = Get-Content $iniPath
$newContent = @()
foreach ($line in $iniContent) {
    $newContent += $line
    if ($line -eq "[REAPER]") {
        $newContent += "splashimage=Scripts/chmaha Scripts/ReaClassical/reaclassical-splash.png"
    }
}
$newContent | Set-Content $iniPath

Start-Sleep -Seconds 2
Write-Host "Portable ReaClassical Installation complete!"

Cleanup
