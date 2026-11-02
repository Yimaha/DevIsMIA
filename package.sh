#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build/PresenceLock.app/Contents/MacOS build/PresenceLock.app/Contents/Resources dist/PresenceLock
cp Info.plist build/PresenceLock.app/Contents/
cp AppIcon.icns build/PresenceLock.app/Contents/Resources/
for arch in arm64 x86_64; do
    swiftc -O -target "$arch-apple-macos14.0" -o "build/PresenceLock-$arch" Sources/*.swift
done
lipo -create -output build/PresenceLock.app/Contents/MacOS/PresenceLock build/PresenceLock-arm64 build/PresenceLock-x86_64
codesign --force --sign - build/PresenceLock.app

ditto build/PresenceLock.app dist/PresenceLock/PresenceLock.app
cp install.sh README.txt dist/PresenceLock/
ditto -c -k --norsrc --noextattr --keepParent dist/PresenceLock dist/PresenceLock.zip
echo "Created $(pwd)/dist/PresenceLock.zip"
