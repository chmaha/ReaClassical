// Copyright (C) 2022–2025 chmaha

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func Install64bit(rcfolder string, pkgver string, rcver string, arch string) {

	// Create a unique hash-based date suffix
	dateSuffix := getHashedDateSuffix()
	tempDir := os.TempDir()
	tempFilePath := filepath.Join(tempDir, "ReaClassical_"+dateSuffix)

	if err := os.Mkdir(tempFilePath, os.ModePerm); err != nil {
		fmt.Println("Error creating temporary directory:", err)
		return
	}
	// Check if the folder ReaClassical_${rcver} exists
	if _, err := os.Stat(rcfolder); err == nil {
		// If it exists, append the hash-based date suffix
		rcfolder = fmt.Sprintf("ReaClassical_%s_%s", rcver, dateSuffix)
		fmt.Printf("Folder ReaClassical_%s already exists. Adding unique identifier as suffix.\n", rcver)
	}

	// Use filepath.Join to create paths within the temporary directory for downloaded files
	sevenZipDir := filepath.Join(tempFilePath, "7zip")
	reaperExePath := filepath.Join(tempFilePath, fmt.Sprintf("reaper%s_x64-install.exe", strings.ReplaceAll(pkgver, ".", "")))

	// Download and extract portable 7-zip
	fmt.Println("Downloading and extracting portable 7-zip...")
	time.Sleep(2 * time.Second)
	downloadFile("https://github.com/chmaha/7-zip/raw/main/7zip.zip", filepath.Join(tempFilePath, "7zip.zip"))
	extractArchive(filepath.Join(tempFilePath, "7zip.zip"), sevenZipDir)
	os.Remove(filepath.Join(tempFilePath, "7zip.zip"))

	// Download REAPER
	fmt.Printf("Downloading REAPER %s from reaper.fm\n", pkgver)
	time.Sleep(2 * time.Second)
	var reaperURL string

	if arch == "amd64" {
		reaperURL = fmt.Sprintf("https://www.reaper.fm/files/%s.x/reaper%s_x64-install.exe", strings.Split(pkgver, ".")[0], strings.ReplaceAll(pkgver, ".", ""))
	} else {
		reaperURL = fmt.Sprintf("https://www.reaper.fm/files/%s.x/reaper%s_win11_arm64ec_beta-install.exe", strings.Split(pkgver, ".")[0], strings.ReplaceAll(pkgver, ".", ""))
	}
	downloadFile(reaperURL, reaperExePath)

	// Extract REAPER
	fmt.Printf("Extracting REAPER from .exe to %s folder...\n", rcfolder)
	time.Sleep(2 * time.Second)
	runCommand(filepath.Join(sevenZipDir, "7z.exe"), "x", reaperExePath, "-o"+rcfolder)

	// Download ReaClassical files from GitHub
	fmt.Println("Downloading ReaClassical files from GitHub...")
	time.Sleep(2 * time.Second)
	downloadFile("https://github.com/chmaha/ReaClassical/raw/v25/Resource%20Folder/Resource_Folder_Base.zip", filepath.Join(tempFilePath, "Resource_Folder_Base.zip"))
	if arch == "amd64" {
		downloadFile("https://github.com/chmaha/ReaClassical/raw/v25/Resource%20Folder/UserPlugins/UP_Windows-x64.zip", filepath.Join(tempFilePath, "UP_Windows.zip"))
	} else {
		downloadFile("https://github.com/chmaha/ReaClassical/raw/v25/Resource%20Folder/UserPlugins/UP_Windows-arm64ec.zip", filepath.Join(tempFilePath, "UP_Windows.zip"))
	}
	// Extract ReaClassical files
	fmt.Println("Extracting ReaClassical files to ReaClassical folder...")
	time.Sleep(2 * time.Second)
	extractArchive(filepath.Join(tempFilePath, "Resource_Folder_Base.zip"), rcfolder)
	extractArchive(filepath.Join(tempFilePath, "UP_Windows.zip"), filepath.Join(rcfolder, "UserPlugins"))

	// Add the line to reaper.ini under the [REAPER] section
	fmt.Println("Adding theme and splash screen lines to reaper.ini under [REAPER] section")
	addLineToReaperIni(rcfolder)

	// Fix Ctrl+backtick shortcut
	fmt.Println("Fixing Ctrl+backtick reference in reaper-kb.ini")
	filePath := filepath.Join(rcfolder, "reaper-kb.ini")
	err := replaceKeyInFile(filePath)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
	}

	// Remove temporary files
	fmt.Println("Removing temporary files...")
	time.Sleep(2 * time.Second)
	os.RemoveAll(tempFilePath)

	fmt.Println("Done!")

	// Wait for user input before exiting
	fmt.Print("Press Enter to exit...")
	fmt.Scanln()
}
