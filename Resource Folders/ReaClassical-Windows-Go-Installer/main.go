package main

import "runtime"

func main() {
	if is64Bit() {
		Install64bit()
	} else {
		Install32bit()
	}
}

func is64Bit() bool {
	// Your logic to determine if it's a 64-bit system.
	return runtime.GOARCH == "amd64"

}
