package main

import "runtime"

func main() {
	if is64Bit() {
		Install64bit()
	} else {
		Install32bit()
	}
}

// Logic to determine if it's a 64-bit system.
func is64Bit() bool {
	return runtime.GOARCH == "amd64"

}
