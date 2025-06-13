#!/bin/bash

# integrate-daemon-sync.sh
# Adds daemon version sync to the GUI app's existing Run Script build phase
# This ensures daemon versions are automatically updated after each GUI build

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

PROJECT_FILE="$PROJECT_ROOT/Intuneomator.xcodeproj/project.pbxproj"
BACKUP_FILE="$PROJECT_FILE.backup-daemon-sync"

echo -e "${YELLOW}🔧 Integrating daemon version sync into GUI build phase...${NC}"

# Check if project file exists
if [[ ! -f "$PROJECT_FILE" ]]; then
    echo -e "${RED}❌ Error: Xcode project file not found at $PROJECT_FILE${NC}"
    exit 1
fi

# Create backup
cp "$PROJECT_FILE" "$BACKUP_FILE"
echo -e "${GREEN}📋 Created backup at $BACKUP_FILE${NC}"

# New shell script content that includes daemon sync
NEW_SHELL_SCRIPT='#!/bin/bash\n\n# Path to your xcconfig file\nCONFIG_PATH="${PROJECT_DIR}/Config.xcconfig"\necho "Config path: $CONFIG_PATH"\n\n# Check if file exists\nif [ ! -f "$CONFIG_PATH" ]; then\n    echo "Error: Config.xcconfig file not found at $CONFIG_PATH"\n    exit 1\nfi\n\n# Get the current version from the xcconfig file\ncurrentVersion=$(grep "CURRENT_PROJECT_VERSION" "$CONFIG_PATH" | cut -d'\''='\'' -f2)\necho "Current version: $currentVersion"\n\n# Remove any whitespace\ncurrentVersion=$(echo $currentVersion | tr -d '\''[:space:]'\'')\n\n# Increment the version\nnewVersion=$(($currentVersion + 1))\necho "New version: $newVersion"\n\n# Replace the version in the file\nsed -i '\'''\'' "s/CURRENT_PROJECT_VERSION=$currentVersion/CURRENT_PROJECT_VERSION=$newVersion/" "$CONFIG_PATH"\necho "Version updated successfully in Config.xcconfig"\n\n# Sync daemon version constants after version increment\necho "Syncing daemon version constants..."\nDAEMON_SYNC_SCRIPT="${PROJECT_DIR}/Scripts/sync-daemon-versions.sh"\nif [ -f "$DAEMON_SYNC_SCRIPT" ]; then\n    "$DAEMON_SYNC_SCRIPT"\n    echo "Daemon versions synced successfully"\nelse\n    echo "Warning: Daemon sync script not found at $DAEMON_SYNC_SCRIPT"\nfi\n'

# Find the current shell script and replace it
if grep -q "Version updated successfully in Config.xcconfig" "$PROJECT_FILE"; then
    # Use sed to replace the shell script content
    # First extract the current line number where the shellScript starts
    SHELL_SCRIPT_LINE=$(grep -n "shellScript = " "$PROJECT_FILE" | cut -d: -f1)
    
    if [ -n "$SHELL_SCRIPT_LINE" ]; then
        # Use awk to replace the shellScript line
        awk -v line="$SHELL_SCRIPT_LINE" -v new_script="$NEW_SHELL_SCRIPT" '
        NR == line {
            print "\t\t\tshellScript = \"" new_script "\";"
            next
        }
        { print }
        ' "$PROJECT_FILE" > "$PROJECT_FILE.tmp" && mv "$PROJECT_FILE.tmp" "$PROJECT_FILE"
    else
        echo -e "${RED}❌ Error: Could not find shellScript line${NC}"
        mv "$BACKUP_FILE" "$PROJECT_FILE"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Successfully integrated daemon sync into GUI build phase${NC}"
    echo -e "${GREEN}📦 Now when you build the GUI app:${NC}"
    echo -e "${GREEN}   1. Version gets auto-incremented${NC}"
    echo -e "${GREEN}   2. Daemon versions get auto-synced${NC}"
    echo -e "${GREEN}   3. All components use the same version${NC}"
    
    echo -e "${YELLOW}🔄 Testing the integration...${NC}"
    
    # Verify the change was made correctly
    if grep -q "Syncing daemon version constants" "$PROJECT_FILE"; then
        echo -e "${GREEN}✅ Integration verified successfully${NC}"
    else
        echo -e "${RED}❌ Integration verification failed${NC}"
        echo -e "${YELLOW}📋 Restoring backup...${NC}"
        mv "$BACKUP_FILE" "$PROJECT_FILE"
        exit 1
    fi
    
else
    echo -e "${RED}❌ Error: Could not find the expected content in the Run Script build phase${NC}"
    echo -e "${YELLOW}📋 Restoring backup...${NC}"
    mv "$BACKUP_FILE" "$PROJECT_FILE"
    exit 1
fi

echo -e "${GREEN}🎉 Integration complete!${NC}"
echo -e "${YELLOW}💡 Build order for releases:${NC}"
echo -e "   1. Build GUI app (increments version + syncs daemons automatically)"
echo -e "   2. Build IntuneomatorService and IntuneomatorUpdater"
echo -e "   3. All components will have matching version numbers"