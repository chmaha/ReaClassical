package main

import (
	"archive/zip"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const (
	pkgver = "7.07"
	rcver  = "24"
)

var (
	rcfolder = fmt.Sprintf("ReaClassical_%s", rcver)
)

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

func downloadFile(url, destination string) {
	response, err := http.Get(url)
	if err != nil {
		fmt.Printf("Error downloading file from %s: %s\n", url, err)
		os.Exit(1)
	}
	defer response.Body.Close()

	file, err := os.Create(destination)
	if err != nil {
		fmt.Printf("Error creating file %s: %s\n", destination, err)
		os.Exit(1)
	}
	defer file.Close()

	_, err = io.Copy(file, response.Body)
	if err != nil {
		fmt.Printf("Error copying content to file %s: %s\n", destination, err)
		os.Exit(1)
	}
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