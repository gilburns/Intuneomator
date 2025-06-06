//
//  MainViewController+Actions.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/11/25.
//

import Cocoa

/**
 * MainViewController+Actions
 *
 * This extension contains all UI action handlers for the MainViewController.
 * It manages user interactions with buttons, menu items, and other UI controls.
 *
 * ## Responsibilities:
 * - Handle table row actions (add, edit, remove)
 * - Manage sheet presentation for various configuration screens
 * - Handle folder opening actions
 * - Manage discovered apps window lifecycle
 *
 * ## Action Categories:
 * - **Row Actions**: Add, edit, and remove app automation entries
 * - **Sheet Presentation**: Settings, certificates, schedules, statistics
 * - **Window Management**: Discovered apps manager window
 * - **Folder Access**: Quick access to important directories
 */
extension MainViewController {
    // MARK: - Row Actions

    /**
     * Presents the label creation sheet for adding a new app automation.
     * 
     * This action is typically triggered by the "+" button in the UI and opens
     * the LabelView sheet where users can configure a new Installomator label.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func addRow(_ sender: Any) {
        presentSheet(withIdentifier: "LabelView")
    }

    /**
     * Removes the selected app automation entry after user confirmation.
     * 
     * This method:
     * 1. Gets the selected table row and validates selection
     * 2. Shows a confirmation dialog with app details
     * 3. Deletes the associated directory via XPC service
     * 4. Updates the data arrays and refreshes the UI
     * 
     * The deletion is permanent and cannot be undone.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func removeRow(_ sender: Any) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }

        // Get the name of the selected item for the confirmation dialog
        let itemToRemove = filteredAppData[selectedRow]
        let itemName = itemToRemove.name
        let itemLabel = itemToRemove.label
        Logger.logApp("Button clicked to delete '\(itemName)' directory.")

        // Create a confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Confirm Deletion"
        alert.informativeText = "Are you sure you want to delete '\(itemName) - \(itemLabel)'? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        // Show the dialog and handle the response
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // User confirmed deletion
            Logger.logApp("User confirmed deletion of '\(itemName)' directory.")
            // Remove the directory associated with the item
            let directoryPath = (AppConstants.intuneomatorManagedTitlesFolderURL.path as NSString).appendingPathComponent("\(itemToRemove.label)_\(itemToRemove.guid)")

            
            XPCManager.shared.removeLabelContent(directoryPath) { success in
                if let success = success, success {
                    Logger.logApp("Deleted directory: \(directoryPath)")
                } else {
                    Logger.logApp("Failed to delete directory: \(directoryPath)")
                    return
                }
            }
    
            // Remove the item from appData and reload the table view
            if let appDataIndex = appData.firstIndex(where: { $0.name == itemName }) {
                // Remove from the original array
                appData.remove(at: appDataIndex)
            }

            // Also remove from the filtered array
            filteredAppData.remove(at: selectedRow)
            tableView.reloadData()
            setLabelCount()

            // Disable buttons after deletion
            editButton.isEnabled = false
            removeButton.isEnabled = false
        } else {
            // User canceled deletion
            Logger.logApp("User canceled deletion")
        }
        refreshUI()
    }

    /**
     * Opens the app editing interface for the selected table row.
     * 
     * This method:
     * 1. Validates that a row is selected
     * 2. Instantiates the TabViewController from the storyboard
     * 3. Passes the selected app data to the controller
     * 4. Presents it as a resizable sheet with hidden title
     * 
     * The TabViewController provides a tabbed interface for editing all
     * aspects of the app automation configuration.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func editAppItem(_ sender: Any) {
        guard tableView.selectedRow >= 0 else { return }
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let tabViewController = storyboard.instantiateController(withIdentifier: "TabView") as? TabViewController else { return }
        
        tabViewController.appData = filteredAppData[tableView.selectedRow]
        presentAsSheet(tabViewController)
        
        if let sheetWindow = tabViewController.view.window {
            sheetWindow.styleMask.insert(.resizable) // Allow resizing
            sheetWindow.titleVisibility = .hidden // Hide the sheet title for cleaner appearance
        }
    }
    
    // MARK: - Sheet Presentation Actions
    
    /**
     * Opens the application settings sheet.
     * 
     * Presents the SettingsView for configuring global application preferences,
     * authentication settings, and automation parameters.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openSettings(_ sender: Any) {
        presentSheet(withIdentifier: "SettingsView")
    }

    /**
     * Opens the certificate generation interface.
     * 
     * Presents the CertificateGenerator storyboard for creating and managing
     * certificates used for Intune authentication.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openCertificateGeneration(_ sender: Any) {
        let storyboard = NSStoryboard(name: "CertificateGenerator", bundle: nil)
        guard let controller = storyboard.instantiateController(withIdentifier: "CertificateViewController") as? CertificateViewController else { return }

        presentAsSheet(controller)
    }

    /**
     * Opens the schedule editor for automation timing configuration.
     * 
     * Presents the ScheduleEditorViewController for setting up automated
     * execution schedules for app updates and processing.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openScheduleEditor(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let controller = storyboard.instantiateController(withIdentifier: "ScheduleEditorViewController") as? ScheduleEditorViewController else { return }

        presentAsSheet(controller)
    }

    /**
     * Opens the statistics and analytics sheet.
     * 
     * Presents the StatsViewController showing usage statistics, processing
     * metrics, and system usage data.
     *
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openStatisticsSheet(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let controller = storyboard.instantiateController(withIdentifier: "StatsViewController") as? StatsViewController else { return }

        presentAsSheet(controller)
    }

    
    // MARK: - Window Management Actions

    /**
     * Opens or focuses the Discovered Apps Manager window.
     * 
     * This method manages a separate window for viewing and managing apps
     * discovered in the Intune tenant. It implements singleton behavior:
     * - If window already exists and is visible, brings it to front
     * - Otherwise creates a new window with proper sizing and configuration
     * 
     * The window is tracked in discoveredAppsManagerWindowControllers to
     * prevent multiple instances and ensure proper memory management.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openDiscoveredAppsManagerWindow(_ sender: Any) {
        // Check if there's an existing Discovered Apps Manager window
        if let existingWindowController = discoveredAppsManagerWindowControllers.first(where: { $0.window?.isVisible == true }) {
            existingWindowController.window?.makeKeyAndOrderFront(nil) // Bring to front
            return
        }

        let storyboard = NSStoryboard(name: "Main", bundle: nil)

        guard let discoveredAppsManagerVC = storyboard.instantiateController(withIdentifier: "DiscoveredAppsViewController") as? DiscoveredAppsViewController else {
            print("Failed to instantiate DiscoveredAppsViewController")
            return
        }

        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 420

        let discoveredAppsManagerWindow = NSWindow(
            contentRect: NSMakeRect(0, 0, windowWidth, windowHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        discoveredAppsManagerWindow.contentViewController = discoveredAppsManagerVC
        discoveredAppsManagerWindow.title = "Intune Discovered Apps"

        // Explicitly set the window frame to fix initial sizing issue
        discoveredAppsManagerWindow.setFrame(NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight), display: true)

        // Set minimum window size
        discoveredAppsManagerWindow.minSize = NSSize(width: windowWidth, height: windowHeight)

        // Center the window on the screen
        discoveredAppsManagerWindow.center()

        let windowController = NSWindowController(window: discoveredAppsManagerWindow)
        windowController.showWindow(self)

        // Keep reference to prevent deallocation
        discoveredAppsManagerWindowControllers.append(windowController)
    }

    
    // MARK: - Folder Access Actions
    
    /**
     * Opens the temporary files folder in Finder.
     * 
     * This folder contains temporary downloads and intermediate files
     * created during app processing.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openTempFolder(_ sender: Any) {
        NSWorkspace.shared.open(AppConstants.intuneomatorTempFolderURL)
    }

    /**
     * Opens the main Intuneomator application support folder in Finder.
     * 
     * This is the root folder containing all Intuneomator data including
     * managed titles, cache, logs, and configuration files.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openIntuneomatorFolder(_ sender: Any) {
        NSWorkspace.shared.open(AppConstants.intuneomatorFolderURL)
    }

    /**
     * Opens the system log directory in Finder.
     * 
     * Contains system-level logs from the XPC service and background
     * operations. Only opens if the directory exists.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openLogDirectory(_ sender: Any) {
        let logURL = AppConstants.intuneomatorLogSystemURL

        if FileManager.default.fileExists(atPath: logURL.path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: logURL.path))
        }
    }

    /**
     * Opens the custom Installomator labels folder in Finder.
     * 
     * This folder contains user-created custom labels that extend
     * the standard Installomator label set.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openCustomLabelsFolder(_ sender: Any) {
        NSWorkspace.shared.open(AppConstants.installomatorCustomLabelsFolderURL)
    }

    /**
     * Opens the application log directory in Finder.
     * 
     * Contains application-level logs from the main GUI process.
     * Only opens if the directory exists.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openAppLogDirectory(_ sender: Any) {
        let logURL = AppConstants.intuneomatorLogApplicationURL

        if FileManager.default.fileExists(atPath: logURL.path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: logURL.path))
        }
    }


    /**
     * Presents the About window with application information.
     * 
     * Shows version information, credits, license details, and other
     * application metadata in a sheet presentation.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func showAboutWindow(_ sender: Any) {
        let storyboard = NSStoryboard(name: "About", bundle: nil)
        guard let controller = storyboard.instantiateController(withIdentifier: "AboutViewController") as? AboutViewController else { return }

        presentAsSheet(controller)
    }

}
