#!/bin/zsh

#  Full_Release.sh
#  Intuneomator
#
#  Created by AI Assistant on 6/15/25.
#  
#  Complete release workflow script
#  Builds all applications, signs, notarizes, then creates final installer package

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

print_header() {
    echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

main() {
    print_header "Intuneomator Full Release Workflow"
    print_info "This script will:"
    echo "  1. Build all applications (GUI + 2 CLI tools)"
    echo "  2. Code sign and notarize all binaries" 
    echo "  3. Create final installer package"
    echo "  4. Sign and notarize the installer package"
    echo ""
    
    # Check we're in the right directory
    if [ ! -f "Intuneomator.xcodeproj/project.pbxproj" ]; then
        print_error "Please run this script from the project root directory"
        exit 1
    fi
    
    # Step 1: Build and notarize applications
    print_header "Step 1: Building and Notarizing Applications"
    if ! ./Scripts/Release_Build.sh; then
        print_error "Application build and notarization failed"
        exit 1
    fi
    print_success "Applications built and notarized successfully"
    
    # Step 2: Create installer package
    print_header "Step 2: Creating Installer Package"
    cd Package
    if ! ./Package_Build.sh; then
        print_error "Package creation failed"
        exit 1
    fi
    cd ..
    print_success "Installer package created and notarized successfully"
    
    # Final summary
    print_header "Release Complete"
    print_success "Full release workflow completed successfully!"
    
    echo ""
    print_info "Release artifacts:"
    echo "  • Applications: ./DerivedData/Build/Products/Release/"
    echo "  • Checksums: ./Release_Checksums.txt"
    echo "  • Installer: ./Package/Intuneomator-1.0.pkg"
    echo "  • SHA256: ./Package/Intuneomator-1.0.pkg.sha256.txt"
    
    echo ""
    print_info "All components are signed, notarized, and ready for distribution!"
}

# Execute main function
main "$@"