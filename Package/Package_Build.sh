#!/bin/zsh

#  Package_Build.sh
#  Intuneomator
#
#  Created by Gil Burns on 5/20/25.
#  

set -e  # Exit on error

# === Variables ===
APP_NAME="Intuneomator"
IDENTIFIER="com.gilburns.Intuneomator"

# === Version Information from Built Application ===
# Read version from the actual built app to ensure consistency with build artifacts

# Determine build path first (needed for version reading)
if [ -d "../DerivedData/Build/Products/Release" ]; then
    BUILD_PATH="../DerivedData/Build/Products/Release"
    echo "Using Release_Build.sh output from: $BUILD_PATH"
elif [ -d "/Users/gilburns/Library/Developer/Xcode/DerivedData/Intuneomator-goaiftwymseounhbjldcvcytweic/Build/Products/Release" ]; then
    BUILD_PATH="/Users/gilburns/Library/Developer/Xcode/DerivedData/Intuneomator-goaiftwymseounhbjldcvcytweic/Build/Products/Release"
    echo "Using Xcode default Release build from: $BUILD_PATH"
else
    BUILD_PATH="/Users/gilburns/Library/Developer/Xcode/DerivedData/Intuneomator-goaiftwymseounhbjldcvcytweic/Build/Products/Debug"
    echo "Fallback to Debug build from: $BUILD_PATH"
fi

# Read version from the built application's Info.plist
APP_INFO_PLIST="${BUILD_PATH}/${APP_NAME}.app/Contents/Info.plist"

if [[ ! -f "$APP_INFO_PLIST" ]]; then
    echo "❌ Error: Built application Info.plist not found at $APP_INFO_PLIST"
    echo "Make sure to run Release_Build.sh first to build the applications"
    exit 1
fi

# Extract version values from the built application
MARKETING_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_INFO_PLIST" 2>/dev/null)
BUILD_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_INFO_PLIST" 2>/dev/null)

# Validate version extraction
if [[ -z "$MARKETING_VERSION" || -z "$BUILD_VERSION" ]]; then
    echo "❌ Error: Could not extract version values from built application"
    echo "Marketing Version: '$MARKETING_VERSION'"
    echo "Build Version: '$BUILD_VERSION'"
    echo "Info.plist path: $APP_INFO_PLIST"
    exit 1
fi

# Create full version string: MARKETING_VERSION.BUILD_VERSION
VERSION="${MARKETING_VERSION}.${BUILD_VERSION}"

echo "📦 Package version: $VERSION (Marketing: $MARKETING_VERSION, Build: $BUILD_VERSION)"
echo "   (Read from built application: $APP_INFO_PLIST)"

INSTALL_LOCATION="/Applications"
TMP_DIR="./Root"
SCRIPTS_DIR="./Scripts"
PKG_NAME="${APP_NAME}.pkg"
SIGNED_PKG_NAME="${APP_NAME}-${VERSION}.pkg"
COMPONENT_PLIST="component.plist"
DIST_XML="Distribution.xml"
SIGN_ID="Developer ID Installer: Gil Burns (G4MQ57TVLE)"

# Build path was already determined above for version reading

# Insure that the scripts are executable
chmod 755 "${SCRIPTS_DIR}/preinstall"
chmod 755 "${SCRIPTS_DIR}/postinstall"

# === Cleanup ===
rm -rf "$PKG_NAME" "$SIGNED_PKG_NAME" "$COMPONENT_PLIST" "$DIST_XML"

# === Create staging root ===
mkdir -p "$TMP_DIR/Applications"
mkdir -p "$TMP_DIR/Library/Application Support/Intuneomator"

cp -R "${BUILD_PATH}/${APP_NAME}.app" "$TMP_DIR${INSTALL_LOCATION}"
cp "${BUILD_PATH}/IntuneomatorService" "$TMP_DIR/Library/Application Support/Intuneomator/"
cp "${BUILD_PATH}/IntuneomatorUpdater" "$TMP_DIR/Library/Application Support/Intuneomator/"

chmod 755 "$TMP_DIR/Library/Application Support/Intuneomator/IntuneomatorService"
chmod 755 "$TMP_DIR/Library/Application Support/Intuneomator/IntuneomatorUpdater"

# === Remove any .DS_Store files ===
echo "Cleaning up .DS_Store files..."
find "$TMP_DIR" -name ".DS_Store" -type f -delete
find "$SCRIPTS_DIR" -name ".DS_Store" -type f -delete

# === Analyze app to generate component plist ===
/usr/bin/pkgbuild --analyze --root "$TMP_DIR" "$COMPONENT_PLIST"

# === Modify component plist to set BundleIsRelocatable to false ===
/usr/bin/plutil -replace "BundleIsRelocatable" -bool false "$COMPONENT_PLIST"

# === Build component package ===
/usr/bin/pkgbuild \
  --root "$TMP_DIR" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --scripts "$SCRIPTS_DIR" \
  --component-plist "$COMPONENT_PLIST" \
  "$PKG_NAME"

# === Generate Distribution XML ===
/usr/bin/productbuild --synthesize --package "$PKG_NAME" "$DIST_XML"

# === Build final signed package ===
/usr/bin/productbuild \
  --distribution "$DIST_XML" \
  --package-path "." \
  --sign "$SIGN_ID" \
  "$SIGNED_PKG_NAME"

echo "Created signed package: $SIGNED_PKG_NAME"

# === Notarize the package ===
echo "Submitting package for notarization..."
if ! xcrun notarytool submit "$SIGNED_PKG_NAME" --keychain-profile "apple-notary-profile" --wait; then
  echo "Notarization failed"
  exit 1
fi

# === Staple the ticket ===
echo "Stapling notarization ticket..."
if ! xcrun stapler staple "$SIGNED_PKG_NAME"; then
  echo "Stapling failed"
  exit 1
fi

echo "Notarization and stapling complete."

# === Output SHA256 hash of the final package ===
echo "Calculating SHA256 hash..."
shasum -a 256 "$SIGNED_PKG_NAME" > "${SIGNED_PKG_NAME}.sha256.txt"
cat "${SIGNED_PKG_NAME}.sha256.txt"
