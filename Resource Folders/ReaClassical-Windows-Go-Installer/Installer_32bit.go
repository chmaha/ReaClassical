package main

import (
	"fmt"
	"os"
	"strings"
	"time"
)

func Install32bit() {
	fmt.Println("Welcome to the ReaClassical 32-bit installer...")
	time.Sleep(2 * time.Second)

	// Create a unique hash-based date suffix
	dateSuffix := getHashedDateSuffix()

	// Check if the folder ReaClassical_${rcver} exists
	if _, err := os.Stat(rcfolder); err == nil {
		// If it exists, append the hash-based date suffix
		rcfolder = fmt.Sprintf("ReaClassical_%s_%s", rcver, dateSuffix)
		fmt.Printf("Folder ReaClassical_%s already exists. Adding unique identifier as suffix.\n", rcver)
	}

	// Download and extract portable 7-zip
	fmt.Println("Downloading and extracting portable 7-zip...")
	time.Sleep(2 * time.Second)
	downloadFile("https://github.com/chmaha/7-zip/raw/main/7zip32.zip", "7zip32.zip")
	extractArchive("7zip32.zip", "7zip")
	os.Remove("7zip32.zip")

	// Download REAPER
	fmt.Printf("Downloading REAPER %s from reaper.fm\n", pkgver)
	time.Sleep(2 * time.Second)
	reaperURL := fmt.Sprintf("https://www.reaper.fm/files/%s.x/reaper%s-install.exe", strings.Split(pkgver, ".")[0], strings.ReplaceAll(pkgver, ".", ""))
	downloadFile(reaperURL, fmt.Sprintf("reaper%s-install.exe", strings.ReplaceAll(pkgver, ".", "")))

	// Extract REAPER
	fmt.Printf("Extracting REAPER from .exe to %s folder...\n", rcfolder)
	time.Sleep(2 * time.Second)
	runCommand("./7zip/7z.exe", "x", fmt.Sprintf("reaper%s-install.exe", strings.ReplaceAll(pkgver, ".", "")), "-o"+rcfolder)

	// Download ReaClassical files from GitHub
	fmt.Println("Downloading ReaClassical files from GitHub...")
	time.Sleep(2 * time.Second)
	downloadFile("https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/Resource_Folder_Base.zip", "Resource_Folder_Base.zip")
	downloadFile("https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_Windows-x86.zip", "UP_Windows-x86.zip")

	// Extract ReaClassical files
	fmt.Println("Extracting ReaClassical files to ReaClassical folder...")
	time.Sleep(2 * time.Second)
	extractArchive("Resource_Folder_Base.zip", rcfolder)
	extractArchive("UP_Windows-x86.zip", fmt.Sprintf("%s/UserPlugins", rcfolder))

	// Add the line to reaper.ini under the [REAPER] section
	fmt.Println("Adding theme and splash screen lines to reaper.ini under [REAPER] section")
	addLineToReaperIni(rcfolder)

	// Remove temporary files
	fmt.Println("Removing temporary files...")
	time.Sleep(2 * time.Second)
	os.Remove("Resource_Folder_Base.zip")
	os.Remove("UP_Windows-x86.zip")
	os.Remove(fmt.Sprintf("reaper%s-install.exe", strings.ReplaceAll(pkgver, ".", "")))
	os.RemoveAll("7zip")

	fmt.Println("Done!")

	// Wait for user input before exiting
	fmt.Print("Press Enter to exit...")
	fmt.Scanln()
}
