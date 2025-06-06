//
//  MainViewController+Helpers.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/11/25.
//

import Cocoa
import UniformTypeIdentifiers

/**
 * MainViewController+Helpers
 *
 * This extension contains utility methods and helper functions for the MainViewController.
 * It provides common functionality used across the main view controller and its other extensions.
 *
 * ## Responsibilities:
 * - UI setup and configuration methods
 * - Icon generation and management
 * - Status animations and user feedback
 * - Version formatting and app information
 * - Table view configuration
 * - Permission alert displays
 *
 * ## Helper Categories:
 * - **Setup Methods**: Initial UI configuration
 * - **Icon Utilities**: File extension and app icon handling
 * - **UI Animation**: Status update animations
 * - **Version Info**: App version formatting
 * - **SF Symbols**: Custom tinted symbol creation
 */
extension MainViewController {
    
    // MARK: - Setup Methods
    
    /**
     * Initiates a background check for Intune automation status.
     * 
     * This method calls the XPC service to perform a scan of the Intune tenant
     * and check the current automation status. Results are logged but not
     * directly returned to the UI.
     */
    func checkForIntuneAutomation() {
        XPCManager.shared.checkIntuneForAutomation() { success in
            if let success = success {
                if success {
                    Logger.logApp("Scan completed successfully.", logType: MainViewController.logType)
                }
            }
        }
    }
    
    /**
     * Configures the table view's right-click context menu.
     * 
     * Sets up an empty menu with this controller as the delegate.
     * The actual menu items are populated dynamically in the
     * ContextMenu extension based on the selected row.
     * 
     * Also configures the double-click action for table rows.
     */
    func setupTableViewRightClickMenu() {
        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu
        tableView.target = self
        tableView.doubleAction = #selector(handleTableViewDoubleClick(_:))
    }
    

    /**
     * Sets the initial state of UI controls.
     * 
     * Disables edit and remove buttons since no row is initially selected.
     * Called during view setup and after operations that clear selection.
     */
    func configureInitialState() {
        editButton.isEnabled = false
        removeButton.isEnabled = false
    }

    /**
     * Refreshes the entire user interface.
     * 
     * Reloads the table view data and resets the UI to its initial state.
     * This is typically called after data changes or major UI updates.
     */
    func refreshUI() {
        tableView.reloadData()
        configureInitialState()
    }
    
    /**
     * Updates the label count display.
     * 
     * Shows the number of currently visible labels versus the total number
     * of labels loaded. Format: "X of Y" where X is filtered count and Y is total.
     */
    func setLabelCount() {
        let allLabels = appData.count
        let visibleLabels = filteredAppData.count
        labelCountField.stringValue = "\(visibleLabels) of \(allLabels)"
    }

    
    // MARK: - Icon Utilities
    
    /**
     * Returns the system icon for a given file extension.
     * 
     * Uses the Uniform Type Identifiers framework to get the appropriate
     * icon that macOS associates with the file type.
     * 
     * - Parameter fileExtension: The file extension (e.g., "pkg", "dmg")
     * - Returns: The system icon for the file type, or nil if not found
     */
    func iconForFileExtension(_ fileExtension: String) -> NSImage? {
        if let utType = UTType(filenameExtension: fileExtension) {
            return NSWorkspace.shared.icon(for: utType)
        }
        return nil
    }
    
    /**
     * Returns the icon for an application given its bundle identifier.
     * 
     * Looks up the application by bundle ID and returns its icon.
     * 
     * - Parameter bundleIdentifier: The app's bundle identifier (e.g., "com.apple.Safari")
     * - Returns: The application's icon, or nil if app not found
     */
    func iconForApp(bundleIdentifier: String) -> NSImage? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }

    
    /**
     * Returns the appropriate icon and label for an item based on its type and delivery method.
     * 
     * This method determines the visual representation for different app packaging formats
     * and delivery mechanisms in the table view.
     * 
     * - Parameter itemType: The source item type (pkg, dmg, zip, etc.)
     * - Parameter deliveryType: How the app will be delivered (0=DMG, 1=PKG, 2=LOB)
     * - Returns: A tuple containing the icon image and text label
     * 
     * ## Delivery Types:
     * - 0: DMG delivery (traditional disk image)
     * - 1: PKG delivery (installer package)
     * - 2: LOB delivery (Line of Business via Company Portal)
     */
    func iconForItemType(_ itemType: String, _ deliveryType: Int) -> (NSImage?, NSString?) {
        if ["pkg", "pkgInDmg", "pkgInZip", "pkgInDmgInZip"].contains(itemType) {
            if deliveryType == 1 {
                return (iconForFileExtension("pkg"), "PKG")
            } else if deliveryType == 2 {
                // Try to load custom Company Portal icon, fallback to system icon
                if let cpIconPath = Bundle.main.path(forResource: "CP", ofType: "png"),
                    let icon = NSImage(contentsOfFile: cpIconPath) {
                    return (icon, "LOB")
                }
                return (iconForApp(bundleIdentifier: "com.microsoft.CompanyPortalMac"), "LOB")
            } else {
                return (iconForFileExtension("pkg"), "PKG")
            }
        } else if ["dmg", "zip", "tbz", "appInDmgInZip"].contains(itemType) {
            if deliveryType == 0 {
                return (iconForFileExtension("dmg"), "DMG")
            } else if deliveryType == 1 {
                return (iconForFileExtension("pkg"), "PKG")
            } else {
                return (iconForFileExtension("dmg"), "DMG")
            }
        } else {
            // Unknown item type
            return (NSImage(named: NSImage.cautionName), "???")
        }
    }
    
    
    /**
     * Displays an alert dialog for missing Microsoft Graph API permissions.
     * 
     * This alert is shown when the application cannot access Intune data due to
     * insufficient permissions. It provides specific guidance on which permissions
     * are required and how to resolve the issue.
     * 
     * The alert includes:
     * - Clear explanation of the permission issue
     * - List of required Microsoft Graph API permissions
     * - Instructions for admin consent in Entra ID
     */
    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Permissions Missing"
        alert.informativeText = """
        This application does not have the required permissions to retrieve detected applications.
        
        Please ensure that the enterprise application has been assigned the following Microsoft Graph API permissions:

        - DeviceManagementManagedDevices.Read.All
        - DeviceManagementManagedDevices.ReadWrite.All (optional, if editing is needed)

        After granting permissions, an admin must consent to them in Entra ID.
        """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Version Information
    
    /**
     * Formats the application version string from the bundle information.
     * 
     * Reads both the short version string and build number from the app's Info.plist
     * and combines them into a user-friendly format.
     * 
     * - Returns: Formatted version string in the format "vX.Y.Z.Build" 
     *           (e.g., "v1.2.3.456")
     * 
     * ## Info.plist Keys Used:
     * - CFBundleShortVersionString: The marketing version (e.g., "1.2.3")
     * - CFBundleVersion: The build number (e.g., "456")
     */
    func formattedAppVersion() -> String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber  = info?["CFBundleVersion"]            as? String ?? "?"
        return "v\(shortVersion).\(buildNumber)"
    }
    
    
    // MARK: - UI Animation
    
    /**
     * Animates a status message with fade in/out effects.
     * 
     * Displays a temporary status message to the user with smooth animations.
     * The message fades in, remains visible for a specified duration, then fades out.
     * 
     * - Parameter message: The status message to display
     * - Parameter fadeInDuration: Time for fade-in animation (default: 0.25s)
     * - Parameter visibleDuration: Time message remains visible (default: 5.0s)
     * - Parameter fadeOutDuration: Time for fade-out animation (default: 0.25s)
     * 
     * The animation sequence:
     * 1. Sets message text and makes label visible at 0% opacity
     * 2. Animates opacity to 100% over fadeInDuration
     * 3. Waits for visibleDuration
     * 4. Animates opacity to 0% over fadeOutDuration
     * 5. Hides label and clears text
     */
    func animateStatusUpdate(_ message: String,
                                     fadeInDuration: TimeInterval = 0.25,
                                     visibleDuration: TimeInterval = 5.0,
                                     fadeOutDuration: TimeInterval = 0.25) {
        statusUpdateLabel.alphaValue = 0
        statusUpdateLabel.isHidden = false
        statusUpdateLabel.stringValue = message
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fadeInDuration
            self.statusUpdateLabel.animator().alphaValue = 1.0
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = fadeOutDuration
                self.statusUpdateLabel.animator().alphaValue = 0.0
            }, completionHandler: {
                self.statusUpdateLabel.isHidden = true
                self.statusUpdateLabel.stringValue = ""
            })
        }
    }

    
    // MARK: - SF Symbols Utilities
    
    /**
     * Creates a tinted SF Symbol image with custom color and size.
     * 
     * This utility method generates colored SF Symbol images for use in the UI.
     * It's particularly useful for creating status indicators and custom icons
     * that match the app's color scheme.
     * 
     * - Parameter name: The SF Symbol name (e.g., "cloud", "circle.fill")
     * - Parameter color: The tint color to apply
     * - Parameter size: The desired image size
     * - Parameter config: Symbol configuration (weight, point size, etc.)
     * - Returns: A tinted symbol image, or nil if the symbol couldn't be created
     * 
     * ## Implementation Details:
     * - Uses high-quality image interpolation for crisp rendering
     * - Applies color using sourceAtop blend mode for proper tinting
     * - Returns non-template image to preserve the custom coloring
     */
    func tintedSymbolImage(named name: String, color: NSColor, size: NSSize, config: NSImage.SymbolConfiguration) -> NSImage? {
        guard let baseImage = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
            return nil
        }

        let tinted = NSImage(size: size)
        tinted.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        baseImage.draw(in: NSRect(origin: .zero, size: size))
        color.set()
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)

        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }

}
