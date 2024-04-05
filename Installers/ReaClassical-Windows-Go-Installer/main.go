package main

import (
	"fmt"
	"runtime"
	"time"
)

func main() {

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

	fmt.Println("Welcome to the ReaClassical installer...")
	time.Sleep(2 * time.Second)
	fmt.Println()
	fmt.Println("Versions:")
	fmt.Println("=========")
	fmt.Printf("REAPER %s\n", pkgver)
	fmt.Printf("ReaClassical %s\n\n", rcver)
	time.Sleep(2 * time.Second)

	if is64Bit() {
		Install64bit(rcfolder, pkgver, rcver)
	} else {
		Install32bit(rcfolder, pkgver, rcver)
	}
}

// Logic to determine if it's a 64-bit system.
func is64Bit() bool {
	return runtime.GOARCH == "amd64"

}
