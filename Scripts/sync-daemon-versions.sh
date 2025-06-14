#!/bin/bash

# sync-daemon-versions.sh
# Automatically updates version constants in VersionInfo.swift from Config.xcconfig
# This ensures centralized version management across all Intuneomator targets
#
# NOTE: As of build 173+, daemon files use VersionInfo.swift instead of embedded constants
# This script now only needs to update VersionInfo.swift rather than main.swift files
#
# Can be called standalone or from Xcode build phase with PROJECT_DIR environment variable

set -e

# Colors for output (only use if in interactive terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Determine project root - use PROJECT_DIR if available (Xcode build), otherwise derive from script location
if [ -n "$PROJECT_DIR" ]; then
    PROJECT_ROOT="$PROJECT_DIR"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi

CONFIG_FILE="$PROJECT_ROOT/Config.xcconfig"
VERSION_INFO_FILE="$PROJECT_ROOT/IntuneomatorService/Utilities/VersionInfo.swift"

echo -e "${YELLOW}🔄 Syncing version constants to VersionInfo.swift from Config.xcconfig...${NC}"

# Check if Config.xcconfig exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}❌ Error: Config.xcconfig not found at $CONFIG_FILE${NC}"
    exit 1
fi

# Extract version values from Config.xcconfig
MARKETING_VERSION=$(grep "^MARKETING_VERSION" "$CONFIG_FILE" | cut -d'=' -f2 | xargs)
CURRENT_PROJECT_VERSION=$(grep "^CURRENT_PROJECT_VERSION" "$CONFIG_FILE" | cut -d'=' -f2 | xargs)

if [[ -z "$MARKETING_VERSION" || -z "$CURRENT_PROJECT_VERSION" ]]; then
    echo -e "${RED}❌ Error: Could not extract version values from Config.xcconfig${NC}"
    echo "MARKETING_VERSION: '$MARKETING_VERSION'"
    echo "CURRENT_PROJECT_VERSION: '$CURRENT_PROJECT_VERSION'"
    exit 1
fi

echo -e "${GREEN}📋 Found versions: $MARKETING_VERSION (build $CURRENT_PROJECT_VERSION)${NC}"

# Function to update version constants in a Swift file
update_version_constants() {
    local file="$1"
    local file_name=$(basename "$file")
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}❌ Warning: $file_name not found at $file${NC}"
        return 1
    fi
    
    # Create backup
    cp "$file" "$file.backup"
    
    # Update DAEMON_VERSION constant (using static let instead of private let for VersionInfo.swift)
    if sed -i '' "s/private static let DAEMON_VERSION = \".*\"/private static let DAEMON_VERSION = \"$MARKETING_VERSION\"/" "$file"; then
        echo -e "${GREEN}✅ Updated DAEMON_VERSION in $file_name${NC}"
    else
        echo -e "${RED}❌ Failed to update DAEMON_VERSION in $file_name${NC}"
        mv "$file.backup" "$file"
        return 1
    fi
    
    # Update DAEMON_BUILD constant (using static let instead of private let for VersionInfo.swift)
    if sed -i '' "s/private static let DAEMON_BUILD = \".*\"/private static let DAEMON_BUILD = \"$CURRENT_PROJECT_VERSION\"/" "$file"; then
        echo -e "${GREEN}✅ Updated DAEMON_BUILD in $file_name${NC}"
    else
        echo -e "${RED}❌ Failed to update DAEMON_BUILD in $file_name${NC}"
        mv "$file.backup" "$file"
        return 1
    fi
    
    # Remove backup if successful
    rm "$file.backup"
    return 0
}

# Update VersionInfo.swift (used by all daemon components)
echo -e "${YELLOW}🔧 Updating VersionInfo.swift...${NC}"
update_version_constants "$VERSION_INFO_FILE"

echo -e "${GREEN}✅ Version sync complete!${NC}"
echo -e "${GREEN}📦 VersionInfo.swift now provides version $MARKETING_VERSION (build $CURRENT_PROJECT_VERSION) to all daemon components${NC}"

# Optional: Show what changed
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    echo -e "${YELLOW}📝 Changes made:${NC}"
    git diff --no-index /dev/null <(echo "Version constants updated to:")
    git diff --no-index /dev/null <(echo "  DAEMON_VERSION = \"$MARKETING_VERSION\"")
    git diff --no-index /dev/null <(echo "  DAEMON_BUILD = \"$CURRENT_PROJECT_VERSION\"")
fi