package main

import (
	"fmt"
	"runtime"
	"time"
)

func main() {

	fmt.Println("Welcome to the ReaClassical installer...")
	fmt.Println()

	if !checkInternet() {
		fmt.Println()
		fmt.Println("Error: The ReaClassical installer requires an internet connection.")
		fmt.Println("Enable the connection if possible or transfer the portable install from an online machine.")
		fmt.Println()
		fmt.Print("Press Enter to exit...")
		fmt.Scanln()
		return
	}

	pkgver, err := getReaperVersion()
	if err != nil {
		fmt.Println("Error:", err)
		return
	}

	rcver, err := getReaClassicalMajorVersion()
	if err != nil {
		fmt.Println("Error:", err)
		return
	}

	var (
		rcfolder = fmt.Sprintf("ReaClassical_%s", rcver)
	)

	bool := false
	arch := "32-bit"
	if is64Bit() {
		bool = true
		arch = "64-bit"
	}

	time.Sleep(2 * time.Second)
	fmt.Printf("Versions: REAPER %s (%s), ReaClassical %s\n\n", pkgver, arch, rcver)
	time.Sleep(2 * time.Second)

	if bool {
		Install64bit(rcfolder, pkgver, rcver)
	} else {
		Install32bit(rcfolder, pkgver, rcver)
	}
}

// Logic to determine if it's a 64-bit system.
func is64Bit() bool {
	return runtime.GOARCH == "amd64"

}
