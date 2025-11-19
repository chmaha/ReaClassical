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
	"archive/zip"
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// REAPER installers
//
//go:embed reaper752_x64-install.exe
var Reaper64 []byte

//go:embed reaper752_win11_arm64ec_beta-install.exe
var ReaperARM64 []byte

// 32-bit REAPER installer
//
//go:embed reaper752-install.exe
var Reaper32 []byte

// Resource Folder
//
//go:embed Resource_Folder_Base.zip
var ResourceZip []byte

// UserPlugins zip
//
//go:embed reaper_imgui-x64.dll
var reaimgui64 []byte

//go:embed reaper_imgui-x86.dll
var reaimgui32 []byte

// 7zip
//
//go:embed 7zip.zip
var zip64 []byte

//go:embed 7zip32.zip
var zip32 []byte

func getHashedDateSuffix() string {
	// Get the current epoch time in seconds
	epochTime := time.Now().Unix()

	// Convert epoch time to string
	epochTimeString := fmt.Sprintf("%d", epochTime)

	// Calculate SHA-256 hash
	hash := sha256.New()
	hash.Write([]byte(epochTimeString))
	hashInBytes := hash.Sum(nil)

	// Convert hash to a 4-character string
	hashString := hex.EncodeToString(hashInBytes)[:5]

	return hashString
}

func extractArchive(archive, destination string) {
	r, err := zip.OpenReader(archive)
	if err != nil {
		fmt.Fprintf(os.Stdout, "Error opening archive %s: %s\n", archive, err)
		os.Exit(1)
	}
	defer r.Close()

	for _, f := range r.File {
		fpath := filepath.Join(destination, f.Name)

		if f.FileInfo().IsDir() {
			// Ensure directory exists
			os.MkdirAll(fpath, os.ModePerm)
			continue
		}

		// Ensure parent directory exists
		if err := os.MkdirAll(filepath.Dir(fpath), os.ModePerm); err != nil {
			fmt.Fprintf(os.Stdout, "Error creating directory %s: %s\n", filepath.Dir(fpath), err)
			os.Exit(1)
		}

		// Check if file already exists
		if _, err := os.Stat(fpath); err == nil {
			fmt.Fprintf(io.Discard, "File already exists: %s, merging...\n", fpath)

			// Open existing file
			existingFile, err := os.OpenFile(fpath, os.O_RDWR|os.O_CREATE, os.ModePerm)
			if err != nil {
				fmt.Fprintf(os.Stdout, "Error opening existing file %s: %s\n", fpath, err)
				os.Exit(1)
			}
			defer existingFile.Close()

			// Open file from archive
			rc, err := f.Open()
			if err != nil {
				fmt.Fprintf(os.Stdout, "Error opening file %s in archive: %s\n", f.Name, err)
				os.Exit(1)
			}
			defer rc.Close()

			// Copy content from archive file to existing file
			_, err = io.Copy(existingFile, rc)
			if err != nil {
				fmt.Fprintf(os.Stdout, "Error merging content to file %s: %s\n", fpath, err)
				os.Exit(1)
			}
		} else {
			// File does not exist, create new file
			outFile, err := os.Create(fpath)
			if err != nil {
				fmt.Fprintf(os.Stdout, "Error creating file %s: %s\n", fpath, err)
				os.Exit(1)
			}

			rc, err := f.Open()
			if err != nil {
				fmt.Fprintf(os.Stdout, "Error opening file %s in archive: %s\n", f.Name, err)
				os.Exit(1)
			}

			_, err = io.Copy(outFile, rc)
			if err != nil {
				fmt.Fprintf(os.Stdout, "Error copying content to file %s: %s\n", fpath, err)
				os.Exit(1)
			}

			outFile.Close()
			rc.Close()
		}

		fmt.Fprintf(io.Discard, "Extracted/Merged: %s\n", fpath)
	}
}

func runCommand(command string, args ...string) {
	cmd := exec.Command(command, args...)
	cmd.Stdout = io.Discard
	cmd.Stderr = os.Stderr

	err := cmd.Run()
	if err != nil {
		fmt.Printf("Error running command %s: %s\n", command, err)
		os.Exit(1)
	}
}

func addLineToReaperIni(rcfolder string) {
	// Calculate absolute path
	abspath, err := os.Getwd()
	if err != nil {
		fmt.Printf("Error getting current working directory: %s\n", err)
		os.Exit(1)
	}

	// Read the content of reaper.ini
	reaperIniPath := filepath.Join(abspath, rcfolder, "reaper.ini")
	content, err := os.ReadFile(reaperIniPath)
	if err != nil {
		fmt.Printf("Error reading reaper.ini: %s\n", err)
		os.Exit(1)
	}

	// Find the index where [REAPER] section starts
	reaperSectionIndex := strings.Index(string(content), "[REAPER]")
	if reaperSectionIndex == -1 {
		fmt.Println("[REAPER] section not found in reaper.ini")
		os.Exit(1)
	}

	// Calculate the position to insert the new line after [REAPER] section
	insertPosition := reaperSectionIndex + len("[REAPER]")

	// Define the new lines to be added
	newLines := "\nlastthemefn5=" + filepath.Join(abspath, rcfolder, "ColorThemes", "ReaClassical.ReaperTheme") + "\n" +
		"splashimage=Scripts\\chmaha Scripts\\ReaClassical\\reaclassical-splash.png\n"

	// Modify the content by inserting the new line
	newContent := string(content[:insertPosition]) + newLines + string(content[insertPosition:])

	// Write the modified content back to reaper.ini
	err = os.WriteFile(reaperIniPath, []byte(newContent), os.ModePerm)
	if err != nil {
		fmt.Printf("Error writing to reaper.ini: %s\n", err)
		os.Exit(1)
	}

}
