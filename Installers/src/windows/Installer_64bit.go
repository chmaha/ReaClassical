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
	_ "embed"
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
		rcfolder = fmt.Sprintf("ReaClassical_%s_%s", rcver, dateSuffix)
		fmt.Printf("Folder ReaClassical_%s already exists. Adding unique identifier as suffix.\n", rcver)
	}

	// Write embedded 7-zip to temp and extract
	sevenZipDir := filepath.Join(tempFilePath, "7zip")
	os.MkdirAll(sevenZipDir, os.ModePerm)

	zipPath := filepath.Join(tempFilePath, "7zip.zip")
	if err := os.WriteFile(zipPath, zip64, 0644); err != nil {
		fmt.Println("Error writing 7zip.zip:", err)
		return
	}
	extractArchive(zipPath, sevenZipDir)
	os.Remove(zipPath)

	// Determine REAPER installer & UP zip based on architecture
	var reaperExePath string
	switch arch {
	case "amd64":
		reaperExePath = filepath.Join(tempFilePath, fmt.Sprintf("reaper%s_x64-install.exe", strings.ReplaceAll(pkgver, ".", "")))
		if err := os.WriteFile(reaperExePath, Reaper64, 0644); err != nil {
			fmt.Println("Error writing REAPER installer:", err)
			return
		}
	case "arm64":
		reaperExePath = filepath.Join(tempFilePath, fmt.Sprintf("reaper%s_arm64-install.exe", strings.ReplaceAll(pkgver, ".", "")))
		if err := os.WriteFile(reaperExePath, ReaperARM64, 0644); err != nil {
			fmt.Println("Error writing REAPER ARM64 installer:", err)
			return
		}
	default:
		fmt.Printf("Unsupported architecture: %s\n", arch)
		return
	}

	// Extract REAPER
	fmt.Printf("Extracting REAPER from .exe to %s folder...\n", rcfolder)
	time.Sleep(1 * time.Second)
	runCommand(filepath.Join(sevenZipDir, "7z.exe"), "x", reaperExePath, "-o"+rcfolder)

	// Write and extract Resource_Folder_Base.zip
	resourceZipPath := filepath.Join(tempFilePath, "Resource_Folder_Base.zip")
	if err := os.WriteFile(resourceZipPath, ResourceZip, 0644); err != nil {
		fmt.Println("Error writing Resource_Folder_Base.zip:", err)
		return
	}
	extractArchive(resourceZipPath, rcfolder)

	// Write and extract UserPlugins based on architecture
	// Ensure UserPlugins folder exists
	userPluginsDir := filepath.Join(rcfolder, "UserPlugins")
	if err := os.MkdirAll(userPluginsDir, 0755); err != nil {
		fmt.Println("Error creating UserPlugins folder:", err)
		return
	}

	// Write the DLL file
	dllPath := filepath.Join(userPluginsDir, "reaper_sws-x64.dll")
	if err := os.WriteFile(dllPath, sws64, 0644); err != nil {
		fmt.Println("Error writing reaper_sws-x64.dll:", err)
		return
	}

	// Add theme/splash references
	fmt.Println("Adding theme and splash screen lines to reaper.ini under [REAPER] section")
	addLineToReaperIni(rcfolder)

	// Remove temporary files
	fmt.Println("Removing temporary files...")
	time.Sleep(1 * time.Second)
	os.RemoveAll(tempFilePath)

	fmt.Println("Portable ReaClassical Installation complete!")
}
