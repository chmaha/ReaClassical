package main

import (
	"archive/zip"
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
	pkgver = "6.83"
	rcver  = "23Q4"
)

func main() {
	fmt.Println("Welcome to ReaClassical installer...")
	time.Sleep(2 * time.Second)

	// Download and extract portable 7-zip
	fmt.Println("Downloading and extracting portable 7-zip...")
	time.Sleep(2 * time.Second)
	downloadFile("https://github.com/chmaha/7-zip/raw/main/7zip.zip", "7zip.zip")
	extractArchive("7zip.zip", "7zip")
	os.Remove("7zip.zip")

	// Download REAPER
	fmt.Printf("Downloading REAPER %s from reaper.fm\n", pkgver)
	time.Sleep(2 * time.Second)
	reaperURL := fmt.Sprintf("https://www.reaper.fm/files/%s.x/reaper%s_x64-install.exe", strings.Split(pkgver, ".")[0], strings.ReplaceAll(pkgver, ".", ""))
	downloadFile(reaperURL, fmt.Sprintf("reaper%s_x64-install.exe", strings.ReplaceAll(pkgver, ".", "")))

	// Extract REAPER
	fmt.Printf("Extracting REAPER from .exe to ReaClassical_%s folder...\n", rcver)
	time.Sleep(2 * time.Second)
	runCommand("./7zip/7z.exe", "x", fmt.Sprintf("reaper%s_x64-install.exe", strings.ReplaceAll(pkgver, ".", "")), "-oReaClassical_"+rcver)

	// Download ReaClassical files from GitHub
	fmt.Println("Downloading ReaClassical files from GitHub...")
	time.Sleep(2 * time.Second)
	downloadFile("https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/Resource_Folder_Base.zip", "Resource_Folder_Base.zip")
	downloadFile("https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_Windows-x64.zip", "UP_Windows-x64.zip")

	// Extract ReaClassical files
	fmt.Println("Extracting ReaClassical files to ReaClassical folder...")
	time.Sleep(2 * time.Second)
	extractArchive("Resource_Folder_Base.zip", fmt.Sprintf("ReaClassical_%s", rcver))
	extractArchive("UP_Windows-x64.zip", fmt.Sprintf("ReaClassical_%s/UserPlugins", rcver))

	// Remove temporary files
	fmt.Println("Removing temporary files...")
	time.Sleep(2 * time.Second)
	os.Remove("Resource_Folder_Base.zip")
	os.Remove("UP_Windows-x64.zip")
	os.Remove(fmt.Sprintf("reaper%s_x64-install.exe", strings.ReplaceAll(pkgver, ".", "")))
	os.RemoveAll("7zip")

	fmt.Println("Done!")

	// Wait for user input before exiting
	fmt.Print("Press Enter to exit...")
	fmt.Scanln()
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