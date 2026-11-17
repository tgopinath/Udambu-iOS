#!/bin/sh
# Copy the Udambu web app into the iPhone app, then build it for the simulator.
set -e
cd "$(dirname "$0")"
rsync -a --delete --exclude .git --exclude .work --exclude .claude --exclude tools --exclude sw.js --exclude prototype --exclude shots-desktop --exclude '*.glb' ../udambu/ web/
xcodebuild -project Udambu.xcodeproj -scheme Udambu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build CODE_SIGNING_ALLOWED=NO -quiet build
echo "App: $(pwd)/build/Build/Products/Debug-iphonesimulator/Udambu.app"
