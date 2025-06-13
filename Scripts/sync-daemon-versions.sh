#!/bin/bash

# sync-daemon-versions.sh
# Automatically updates version constants in daemon files from Config.xcconfig
# This ensures centralized version management across all Intuneomator targets
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
SERVICE_FILE="$PROJECT_ROOT/IntuneomatorService/main.swift"
UPDATER_FILE="$PROJECT_ROOT/IntuneomatorUpdater/main.swift"

echo -e "${YELLOW}🔄 Syncing daemon version constants from Config.xcconfig...${NC}"

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
    
    # Update DAEMON_VERSION constant
    if sed -i '' "s/^private let DAEMON_VERSION = \".*\"/private let DAEMON_VERSION = \"$MARKETING_VERSION\"/" "$file"; then
        echo -e "${GREEN}✅ Updated DAEMON_VERSION in $file_name${NC}"
    else
        echo -e "${RED}❌ Failed to update DAEMON_VERSION in $file_name${NC}"
        mv "$file.backup" "$file"
        return 1
    fi
    
    # Update DAEMON_BUILD constant
    if sed -i '' "s/^private let DAEMON_BUILD = \".*\"/private let DAEMON_BUILD = \"$CURRENT_PROJECT_VERSION\"/" "$file"; then
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

# Update both daemon files
echo -e "${YELLOW}🔧 Updating IntuneomatorService...${NC}"
update_version_constants "$SERVICE_FILE"

echo -e "${YELLOW}🔧 Updating IntuneomatorUpdater...${NC}"
update_version_constants "$UPDATER_FILE"

echo -e "${GREEN}✅ Version sync complete!${NC}"
echo -e "${GREEN}📦 All daemon files now use version $MARKETING_VERSION (build $CURRENT_PROJECT_VERSION)${NC}"

# Optional: Show what changed
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    echo -e "${YELLOW}📝 Changes made:${NC}"
    git diff --no-index /dev/null <(echo "Version constants updated to:")
    git diff --no-index /dev/null <(echo "  DAEMON_VERSION = \"$MARKETING_VERSION\"")
    git diff --no-index /dev/null <(echo "  DAEMON_BUILD = \"$CURRENT_PROJECT_VERSION\"")
fi