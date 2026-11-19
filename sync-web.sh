#!/bin/sh
# Build Udambu (Explore + Lab), copy it into the iPhone app, then build it for the simulator.
# AR on iPhone uses the bundled USDZ files (AR Quick Look), so the AR .glb files stay out; the Lab's
# own models (web/lab/models/*.glb) are needed and stay in.
set -e
cd "$(dirname "$0")"
(cd ../udambu && npm run build)
rsync -a --delete --exclude sw.js --exclude 'ar/*.glb' ../udambu/dist/ web/
xcodebuild -project Udambu.xcodeproj -scheme Udambu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build CODE_SIGNING_ALLOWED=NO -quiet build
echo "App: $(pwd)/build/Build/Products/Debug-iphonesimulator/Udambu.app"
