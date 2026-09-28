#!/bin/zsh
# Archive StarBarge for App Store Connect (TestFlight + App Review).
# Prerequisites: the app exists in App Store Connect, and your Apple account is signed in to Xcode.
#
# Usage:
#   scripts/release.sh              # bump the build number, test, archive, check the App Store
#                                   # export, then open the archive in Xcode's Organizer to upload
#   scripts/release.sh --no-upload  # same local checks, build number left unchanged
#
# Why the Organizer: for this project `xcodebuild -exportArchive` with destination=upload was
# rejected by App Store Connect ("Invalid Signature"), while the Organizer uploaded the very
# same archive successfully. The upload is one click there: Distribute App > App Store Connect.
set -euo pipefail

cd "$(dirname "$0")/.."
TEAM_ID="FP4HC6MKJ6"
TEST_APP_ID="ca-app-pub-3940256099942544~1458002511"
BUILD_DIR="build/release"
UPLOAD=true
[[ "${1:-}" == "--no-upload" ]] && UPLOAD=false

# 1. Never ship Google's test ads: Release must use your own AdMob IDs.
release_ids=$(awk '/^        Release:/{f=1;next} f&&/^        [A-Za-z]/{f=0} f' project.yml)
if [[ "$release_ids" == *"$TEST_APP_ID"* ]]; then
  if $UPLOAD; then
    echo "❌ project.yml > configs > Release still uses Google's TEST AdMob IDs. Put yours, then rerun." >&2
    exit 1
  fi
  echo "⚠️  Release uses Google's TEST AdMob IDs (fine for a local check, not for upload)."
fi

# 2. Bump the build number (App Store Connect rejects a reused one).
current=$(awk '/CURRENT_PROJECT_VERSION:/{gsub(/"/,"",$2); print $2; exit}' project.yml)
next=$((current + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION: \"$current\"/CURRENT_PROJECT_VERSION: \"$next\"/" project.yml
version=$(awk '/MARKETING_VERSION:/{gsub(/"/,"",$2); print $2; exit}' project.yml)
echo "▶︎ StarBarge $version ($next)"

# 3. Regenerate, test, archive.
xcodegen generate
xcodebuild -project StarBarge.xcodeproj -scheme StarBarge \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test -quiet
rm -rf "$BUILD_DIR"
xcodebuild -project StarBarge.xcodeproj -scheme StarBarge -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$BUILD_DIR/StarBarge.xcarchive" \
  -allowProvisioningUpdates archive -quiet

# 4. App Store export: proves distribution signing works before uploading.
cat > "$BUILD_DIR/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>export</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$BUILD_DIR/StarBarge.xcarchive" \
  -exportPath "$BUILD_DIR/export" -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  -allowProvisioningUpdates

if $UPLOAD; then
  open "$BUILD_DIR/StarBarge.xcarchive"
  echo "✅ Build $version ($next) archived and signed. Xcode's Organizer is open on it:"
  echo "   Distribute App > App Store Connect > Upload (keep automatic signing)."
  echo "   It appears in App Store Connect > TestFlight after processing (10–30 min)."
  echo "   Then commit the build number bump: git commit -am \"Release $version ($next)\""
else
  echo "✅ IPA ready: $BUILD_DIR/export/StarBarge.ipa (not uploaded)."
  sed -i '' "s/CURRENT_PROJECT_VERSION: \"$next\"/CURRENT_PROJECT_VERSION: \"$current\"/" project.yml
  xcodegen generate >/dev/null
fi
