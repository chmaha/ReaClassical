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

	arch := find_arch()

	time.Sleep(2 * time.Second)
	fmt.Printf("Versions: REAPER %s (%s), ReaClassical %s\n\n", pkgver, arch, rcver)
	time.Sleep(2 * time.Second)

	if arch == "amd64" || arch == "arm64" {
		Install64bit(rcfolder, pkgver, rcver, arch)
	} else if arch == "386" {
		Install32bit(rcfolder, pkgver, rcver)
	} else {
		fmt.Printf("Sorry, your system architecture is not supported.")
	}

}

func find_arch() string {
	return runtime.GOARCH
}
