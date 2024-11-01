#!/bin/sh

GOOS=windows GOARCH=amd64 go build -o ../ReaClassical_Win64.exe .
GOOS=windows GOARCH=386 go build -o ../ReaClassical_Win32.exe .
GOOS=windows GOARCH=arm64 go build -o ../ReaClassical_Win11_arm64ec_beta.exe .
