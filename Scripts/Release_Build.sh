#!/bin/zsh

#  Release_Build.sh
#  Intuneomator
#
#  Created by AI Assistant on 6/15/25.
#  
#  Comprehensive release build script for Intuneomator
#  Builds all three applications (GUI + 2 CLI) and handles code signing and notarization

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# === Colors for output ===
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

# === Configuration ===
PROJECT_NAME="Intuneomator"
PROJECT_FILE="Intuneomator.xcodeproj"
CONFIGURATION="Release"
DERIVED_DATA_PATH="./DerivedData"
BUILD_PRODUCTS_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}"

# Architecture configuration
BUILD_UNIVERSAL=false  # Set to false for ARM64-only builds

# Code signing identities
APP_SIGN_ID="Developer ID Application: Gil Burns (G4MQ57TVLE)"
INSTALLER_SIGN_ID="Developer ID Installer: Gil Burns (G4MQ57TVLE)"

# Notarization profile (configured with `xcrun notarytool store-credentials`)
NOTARY_PROFILE="apple-notary-profile"

# Build targets
GUI_TARGET="Intuneomator"
SERVICE_TARGET="IntuneomatorService"  
UPDATER_TARGET="IntuneomatorUpdater"

# === Utility Functions ===

print_header() {
    echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# === Cleanup Function ===
cleanup_build_artifacts() {
    print_header "Cleanup Previous Build Artifacts"
    
    if [ -d "$DERIVED_DATA_PATH" ]; then
        rm -rf "$DERIVED_DATA_PATH"
        print_success "Removed previous derived data"
    fi
    
    # Clean up any existing signed/notarized binaries in Scripts directory
    find Scripts -name "*-signed*" -type f -delete 2>/dev/null || true
    find Scripts -name "*-notarized*" -type f -delete 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# === Version Synchronization ===
sync_versions() {
    print_header "Synchronizing Daemon Versions"
    
    # Run the daemon version sync script
    if [ -f "Scripts/sync-daemon-versions.sh" ]; then
        ./Scripts/sync-daemon-versions.sh
        print_success "Version constants synchronized"
    else
        print_warning "Version sync script not found - versions may be out of sync"
    fi
}

# === Build Functions ===

build_target() {
    local target=$1
    local description=$2
    local clean_first=${3:-false}  # Optional third parameter to control cleaning
    
    print_header "Building $description ($target)"
    
    # Clean first if requested
    if [ "$clean_first" = true ]; then
        print_info "Cleaning previous build artifacts for $target"
        
        if [ "$BUILD_UNIVERSAL" = true ]; then
            xcodebuild \
                -project "$PROJECT_FILE" \
                -scheme "$target" \
                -configuration "$CONFIGURATION" \
                -derivedDataPath "$DERIVED_DATA_PATH" \
                -arch arm64 \
                -arch x86_64 \
                clean
        else
            xcodebuild \
                -project "$PROJECT_FILE" \
                -scheme "$target" \
                -configuration "$CONFIGURATION" \
                -derivedDataPath "$DERIVED_DATA_PATH" \
                -arch arm64 \
                clean
        fi
    fi
    
    # Build the target with appropriate architecture flags
    if [ "$BUILD_UNIVERSAL" = true ]; then
        print_info "Architecture: Universal (ARM64 + x86_64)"
        xcodebuild \
            -project "$PROJECT_FILE" \
            -scheme "$target" \
            -configuration "$CONFIGURATION" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            -arch arm64 \
            -arch x86_64 \
            CODE_SIGN_IDENTITY="$APP_SIGN_ID" \
            DEVELOPMENT_TEAM="G4MQ57TVLE" \
            CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
            OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
            build
        print_success "Built $description successfully (Universal)"
    else
        print_info "Architecture: ARM64-only"
        xcodebuild \
            -project "$PROJECT_FILE" \
            -scheme "$target" \
            -configuration "$CONFIGURATION" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            -arch arm64 \
            CODE_SIGN_IDENTITY="$APP_SIGN_ID" \
            DEVELOPMENT_TEAM="G4MQ57TVLE" \
            CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
            OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
            build
        print_success "Built $description successfully (ARM64-only)"
    fi
}

# === Code Signing Verification ===
verify_code_signature() {
    local binary_path=$1
    local description=$2
    
    print_info "Verifying code signature for $description"
    
    # Check basic signature
    if ! codesign --verify --verbose "$binary_path"; then
        print_error "Code signature verification failed for $description"
        return 1
    fi
    
    # Check hardened runtime and timestamp
    local signature_info=$(codesign --display --verbose=2 "$binary_path" 2>&1)
    
    if echo "$signature_info" | grep -q "runtime"; then
        print_success "Hardened runtime enabled for $description"
    else
        print_warning "Hardened runtime not detected for $description"
    fi
    
    if echo "$signature_info" | grep -q "timestamp"; then
        print_success "Timestamp signature verified for $description"
    else
        print_warning "Timestamp signature not detected for $description"
    fi
    
    return 0
}

# === Notarization Functions ===
notarize_binary() {
    local binary_path=$1
    local description=$2
    local zip_name="${description// /_}_notarization.zip"
    
    print_header "Notarizing $description"
    
    # Create ZIP for notarization
    print_info "Creating ZIP archive for notarization"
    if [ -d "$binary_path" ]; then
        # For .app bundles
        ditto -c -k --keepParent "$binary_path" "$zip_name"
    else
        # For single binaries
        zip -r "$zip_name" "$binary_path"
    fi
    
    # Submit for notarization
    print_info "Submitting $description for notarization..."
    if ! xcrun notarytool submit "$zip_name" --keychain-profile "$NOTARY_PROFILE" --wait; then
        print_error "Notarization failed for $description"
        rm -f "$zip_name"
        return 1
    fi
    
    # Staple if it's an app bundle
    if [ -d "$binary_path" ] && [[ "$binary_path" == *.app ]]; then
        print_info "Stapling notarization ticket to $description"
        if ! xcrun stapler staple "$binary_path"; then
            print_warning "Stapling failed for $description (this may be normal for CLI tools)"
        else
            print_success "Stapling completed for $description"
        fi
    fi
    
    # Cleanup
    rm -f "$zip_name"
    print_success "Notarization completed for $description"
}

# === SHA256 Generation ===
generate_checksums() {
    print_header "Generating SHA256 Checksums"
    
    local checksum_file="Release_Checksums.txt"
    echo "# Intuneomator Release Build Checksums" > "$checksum_file"
    echo "# Generated on $(date)" >> "$checksum_file"
    echo "" >> "$checksum_file"
    
    # GUI App
    if [ -d "$BUILD_PRODUCTS_PATH/${GUI_TARGET}.app" ]; then
        echo "## GUI Application" >> "$checksum_file"
        shasum -a 256 "$BUILD_PRODUCTS_PATH/${GUI_TARGET}.app/Contents/MacOS/${GUI_TARGET}" >> "$checksum_file"
        echo "" >> "$checksum_file"
    fi
    
    # Service binary
    if [ -f "$BUILD_PRODUCTS_PATH/$SERVICE_TARGET" ]; then
        echo "## XPC Service" >> "$checksum_file"
        shasum -a 256 "$BUILD_PRODUCTS_PATH/$SERVICE_TARGET" >> "$checksum_file"
        echo "" >> "$checksum_file"
    fi
    
    # Updater binary
    if [ -f "$BUILD_PRODUCTS_PATH/$UPDATER_TARGET" ]; then
        echo "## Updater Tool" >> "$checksum_file"
        shasum -a 256 "$BUILD_PRODUCTS_PATH/$UPDATER_TARGET" >> "$checksum_file"
        echo "" >> "$checksum_file"
    fi
    
    print_success "Checksums saved to $checksum_file"
    cat "$checksum_file"
}

# === Main Execution ===

main() {
    print_header "Intuneomator Release Build Script"
    print_info "Building all targets with code signing and notarization"
    print_info "Configuration: $CONFIGURATION"
    if [ "$BUILD_UNIVERSAL" = true ]; then
        print_info "Architecture: Universal (ARM64 + x86_64)"
    else
        print_info "Architecture: ARM64-only"
    fi
    print_info "Code Signing Identity: $APP_SIGN_ID"
    echo ""
    
    # Check prerequisites
    if [ ! -f "$PROJECT_FILE/project.pbxproj" ]; then
        print_error "Xcode project not found. Make sure you're in the project root directory."
        exit 1
    fi
    
    # Check code signing identity
    if ! security find-identity -p codesigning -v | grep -q "$APP_SIGN_ID"; then
        print_error "Code signing identity not found: $APP_SIGN_ID"
        print_info "Available identities:"
        security find-identity -p codesigning -v
        exit 1
    fi
    
    # Check notarization profile
    if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        print_error "Notarization profile '$NOTARY_PROFILE' not found"
        print_info "Set up with: xcrun notarytool store-credentials $NOTARY_PROFILE"
        exit 1
    fi
    
    # Execute build process
    cleanup_build_artifacts
    sync_versions
    
    # Build all targets (clean only on first build to preserve previous artifacts)
    build_target "$GUI_TARGET" "GUI Application" true
    build_target "$SERVICE_TARGET" "XPC Service"  
    build_target "$UPDATER_TARGET" "Updater Tool"
    
    print_header "Build Verification"
    
    # Verify build products exist
    local gui_app="$BUILD_PRODUCTS_PATH/${GUI_TARGET}.app"
    local service_binary="$BUILD_PRODUCTS_PATH/$SERVICE_TARGET"
    local updater_binary="$BUILD_PRODUCTS_PATH/$UPDATER_TARGET"
    
    if [ ! -d "$gui_app" ]; then
        print_error "GUI application not found at expected location"
        exit 1
    fi
    
    if [ ! -f "$service_binary" ]; then
        print_error "XPC Service binary not found at expected location"
        exit 1
    fi
    
    if [ ! -f "$updater_binary" ]; then
        print_error "Updater binary not found at expected location"
        exit 1
    fi
    
    print_success "All build products verified"
    
    # Verify code signatures
    verify_code_signature "$gui_app" "GUI Application"
    verify_code_signature "$service_binary" "XPC Service"
    verify_code_signature "$updater_binary" "Updater Tool"
    
    # Notarize all binaries
    notarize_binary "$gui_app" "GUI Application"
    notarize_binary "$service_binary" "XPC Service"
    notarize_binary "$updater_binary" "Updater Tool"
    
    # Generate checksums
    generate_checksums
    
    print_header "Release Build Complete"
    print_success "All applications built, signed, and notarized successfully!"
    print_info "Build products location: $BUILD_PRODUCTS_PATH"
    print_info "Ready for package creation with Package_Build.sh"
    
    # Display final status
    echo ""
    print_info "Next steps:"
    echo "  1. Run './Package/Package_Build.sh' to create installer package"
    echo "  2. Test all components before distribution"
    echo "  3. Upload to distribution channels"
}

# Execute main function
main "$@"
