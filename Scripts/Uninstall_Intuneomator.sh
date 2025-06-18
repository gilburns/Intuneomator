#!/bin/zsh
#
#  Uninstall_Intuneomator.sh
#  Intuneomator
#
#  Created by Gil Burns on 6/17/25.
#
#  Complete uninstall script for Intuneomator
#  Removes application, services, daemons, data, logs, and keychain items
#

# Require sudo
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)" 
   exit 1
fi

echo "🗑️  Intuneomator Uninstaller"
echo "=================================="

# Base path for LaunchDaemons
DAEMON_DIR="/Library/LaunchDaemons"

# Main paths to remove
APPLICATION_PATH="/Applications/Intuneomator.app"
SERVICE_PATH="/Library/Application Support/Intuneomator"
LOGGING_PATH="/Library/Logs/Intuneomator"
USER_LOGGING_PATH="$HOME/Library/Logs/Intuneomator"

# Additional paths that may contain data
TEMP_FOLDERS="/tmp/Intuneomator*"
USER_TEMP_FOLDERS="$HOME/tmp/Intuneomator*"

# List of daemon plist filenames (actual daemons found in project)
daemons=(
  "com.gilburns.intuneomator.automation.plist"
  "com.gilburns.intuneomator.cachecleaner.plist" 
  "com.gilburns.intuneomator.labelupdater.plist"
  "com.gilburns.intuneomator.ondemand.plist"
  "com.gilburns.intuneomator.service.plist"
  "com.gilburns.intuneomator.updatecheck.plist"
)

# Keychain items to remove (from KeychainManager.swift)
KEYCHAIN_SERVICE="EntraIDSecret"
KEYCHAIN_ACCOUNTS=(
  "com.intuneomator.entrasecret"
  "entraIDSecretKey"
  "entraIDTenantID"
  "entraIDApplicationID"
)

# === Step 1: Kill any running processes ===
echo "🔄 Stopping Intuneomator processes..."
pkill -f "Intuneomator" 2>/dev/null && echo "  ✅ Stopped Intuneomator processes" || echo "  ℹ️  No running Intuneomator processes found"

# === Step 2: Unload and remove Launch Daemons ===
echo "🔄 Unloading and removing launch daemons..."

for daemon in "${daemons[@]}"; do
  plistPath="$DAEMON_DIR/$daemon"
  label="${daemon%.plist}"

  if [[ -f "$plistPath" ]]; then
    echo "  🔄 Unloading $label..."
    
    # Try to unload/bootout the daemon
    launchctl bootout system "$plistPath" 2>/dev/null || \
    launchctl unload "$plistPath" 2>/dev/null || \
    echo "    ⚠️  $label was not loaded or already stopped"
    
    # Remove the plist file
    rm -f "$plistPath" && echo "  ✅ Removed $plistPath" || echo "  ❌ Failed to remove $plistPath"
  else
    echo "  ℹ️  $plistPath does not exist, skipping"
  fi
done

# === Step 3: Remove application bundle ===
echo "🔄 Removing application..."
if [[ -d "$APPLICATION_PATH" ]]; then
  rm -rf "$APPLICATION_PATH" && echo "  ✅ Removed $APPLICATION_PATH" || echo "  ❌ Failed to remove $APPLICATION_PATH"
else
  echo "  ℹ️  Application not found at $APPLICATION_PATH"
fi

# === Step 4: Remove service data directory ===
echo "🔄 Removing service data..."
if [[ -d "$SERVICE_PATH" ]]; then
  rm -rf "$SERVICE_PATH" && echo "  ✅ Removed $SERVICE_PATH" || echo "  ❌ Failed to remove $SERVICE_PATH"
else
  echo "  ℹ️  Service directory not found at $SERVICE_PATH"
fi

# === Step 5: Remove system log directory ===
echo "🔄 Removing system logs..."
if [[ -d "$LOGGING_PATH" ]]; then
  rm -rf "$LOGGING_PATH" && echo "  ✅ Removed $LOGGING_PATH" || echo "  ❌ Failed to remove $LOGGING_PATH"
else
  echo "  ℹ️  System log directory not found at $LOGGING_PATH"
fi

# === Step 6: Remove user log directory ===
echo "🔄 Removing user logs..."
if [[ -d "$USER_LOGGING_PATH" ]]; then
  rm -rf "$USER_LOGGING_PATH" && echo "  ✅ Removed $USER_LOGGING_PATH" || echo "  ❌ Failed to remove $USER_LOGGING_PATH"
else
  echo "  ℹ️  User log directory not found at $USER_LOGGING_PATH"
fi

# === Step 7: Remove temporary directories ===
echo "🔄 Cleaning up temporary files..."
temp_removed=false
for temp_dir in $TEMP_FOLDERS $USER_TEMP_FOLDERS; do
  if [[ -d "$temp_dir" ]]; then
    rm -rf "$temp_dir" && echo "  ✅ Removed $temp_dir" && temp_removed=true
  fi
done
if [[ "$temp_removed" == "false" ]]; then
  echo "  ℹ️  No temporary directories found"
fi

# === Step 8: Remove keychain items ===
echo "🔄 Removing keychain items..."

# Remove certificates (find all Intuneomator-related certs)
cert_count=$(security find-certificate -a -c "Intuneomator" 2>/dev/null | grep -c "Intuneomator" || echo "0")
if [[ $cert_count -gt 0 ]]; then
  echo "  🔄 Found $cert_count Intuneomator certificates to remove..."
  security delete-certificate -c "Intuneomator" 2>/dev/null && echo "  ✅ Removed Intuneomator certificates" || echo "  ⚠️  Some certificates may not have been removed"
else
  echo "  ℹ️  No Intuneomator certificates found"
fi

# Remove keychain entries for secrets
secrets_removed=0
for account in "${KEYCHAIN_ACCOUNTS[@]}"; do
  if security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$account" 2>/dev/null; then
    echo "  ✅ Removed keychain entry: $account"
    ((secrets_removed++))
  fi
done

if [[ $secrets_removed -eq 0 ]]; then
  echo "  ℹ️  No keychain secrets found"
fi

# === Step 9: Remove private keys ===
echo "🔄 Removing private keys..."
key_count=$(security find-key -a -l "Intuneomator" 2>/dev/null | wc -l || echo "0")
if [[ $key_count -gt 0 ]]; then
  security delete-key -l "Intuneomator" 2>/dev/null && echo "  ✅ Removed Intuneomator private keys" || echo "  ⚠️  Some private keys may not have been removed"
else
  echo "  ℹ️  No Intuneomator private keys found"
fi

# === Step 10: Final cleanup check ===
echo "🔄 Performing final cleanup check..."

# Check for any remaining files
remaining_files=()
[[ -d "$APPLICATION_PATH" ]] && remaining_files+=("$APPLICATION_PATH")
[[ -d "$SERVICE_PATH" ]] && remaining_files+=("$SERVICE_PATH") 
[[ -d "$LOGGING_PATH" ]] && remaining_files+=("$LOGGING_PATH")

for daemon in "${daemons[@]}"; do
  [[ -f "$DAEMON_DIR/$daemon" ]] && remaining_files+=("$DAEMON_DIR/$daemon")
done

if [[ ${#remaining_files[@]} -gt 0 ]]; then
  echo "  ⚠️  Some files could not be removed:"
  for file in "${remaining_files[@]}"; do
    echo "    - $file"
  done
  echo "  💡 You may need to remove these manually"
else
  echo "  ✅ All files successfully removed"
fi

# === Summary ===
echo ""
echo "📋 UNINSTALL SUMMARY"
echo "=================================="
echo "✅ Stopped all Intuneomator processes"
echo "✅ Unloaded and removed launch daemons"
echo "✅ Removed application bundle"
echo "✅ Removed service data directory"
echo "✅ Removed log directories"
echo "✅ Cleaned up temporary files"
echo "✅ Removed keychain items and certificates"
echo "✅ Removed private keys"
echo ""
echo "🎉 Intuneomator uninstall complete!"
echo ""
echo "💡 Note: If you had any custom configurations or scripts"
echo "   that referenced Intuneomator, you may need to remove"
echo "   those manually."
