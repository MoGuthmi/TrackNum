#!/bin/sh
# Build TrackNum
set -e
cd "$(dirname "$0")"
swiftc -O TrackNum.swift -o TrackNum -framework Cocoa
echo "Built ./TrackNum — run it with: ./TrackNum"
