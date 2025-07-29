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
        Logger.info("Button clicked to delete '\(itemName)' directory.", category: .core, toUserDirectory: true)

        // Create a confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Confirm Deletion"
        alert.informativeText = "Are you sure you want to delete?\n\nName: \(itemName)\nLabel: \(itemLabel)\n\nWARNING: There is no undo for this action."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        // Show the dialog and handle the response
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // User confirmed deletion
            Logger.info("User confirmed deletion of '\(itemName)' directory.", category: .core, toUserDirectory: true)
            // Remove the directory associated with the item
            let directoryPath = (AppConstants.intuneomatorManagedTitlesFolderURL.path as NSString).appendingPathComponent("\(itemToRemove.label)_\(itemToRemove.guid)")

            
            XPCManager.shared.removeLabelContent(directoryPath) { success in
                if let success = success, success {
                    Logger.info("Deleted directory: \(directoryPath)", category: .core, toUserDirectory: true)
                } else {
                    Logger.info("Failed to delete directory: \(directoryPath)", category: .core, toUserDirectory: true)
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
            updateAutomationTriggerUIState()

            // Disable buttons after deletion
            editButton.isEnabled = false
            removeButton.isEnabled = false
        } else {
            // User canceled deletion
            Logger.info("User canceled deletion", category: .core, toUserDirectory: true)
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
        // Load current settings from the daemon
        XPCManager.shared.getSettings { [weak self] settingsData in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Debug logging to identify the issue
                if let settings = settingsData {
                    Logger.debug("Successfully retrieved settings from XPC service: \(settings.keys.joined(separator: ", "))", category: .core, toUserDirectory: true)
                } else {
                    Logger.error("XPC service returned nil for getSettings - this indicates XPC communication failure", category: .core, toUserDirectory: true)
                }
                
                // Use the settings data directly (already in dictionary format)
                let data = settingsData ?? [:]
                
                // Create tabbed settings editor
                guard let settingsVC = TabbedSheetViewController.createSettingsEditor(
                    settingsData: data,
                    saveHandler: { [weak self] combinedData in
                        self?.handleSettingsSaved(combinedData)
                    },
                    cancelHandler: {
                        Logger.info("Settings editing cancelled", category: .core, toUserDirectory: true)
                    }
                ) else {
                    Logger.error("Failed to create settings editor", category: .core, toUserDirectory: true)
                    return
                }
                
                self.presentAsSheet(settingsVC)
            }
        }
    }
    
    /// Handles settings being saved from the tabbed interface
    private func handleSettingsSaved(_ combinedData: [String: Any]) {
        Logger.info("Settings saved via tabbed interface", category: .core, toUserDirectory: true)
        
        // Convert combined data back to Settings object and save via XPC
        XPCManager.shared.saveSettingsFromDictionary(combinedData) { [weak self] success in
            DispatchQueue.main.async {
                if let success = success, success {
                    Logger.info("Settings saved successfully", category: .core, toUserDirectory: true)
                    // Refresh any UI that depends on settings
                    self?.refreshSettingsDependentUI()
                } else {
                    Logger.error("Failed to save settings", category: .core, toUserDirectory: true)
                    
                    let alert = NSAlert()
                    alert.messageText = "Settings Save Failed"
                    alert.informativeText = "Unable to save the settings. Please try again."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    /// Refreshes UI components that depend on settings
    private func refreshSettingsDependentUI() {
        // Add any UI refresh logic here if needed
        // For example, updating status indicators, refresh intervals, etc.
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

    
    
    @IBAction func openAppsCategoryManagerWindow(_ sender: Any) {
        // First check if Graph connectivity is available
        guard isGraphConnectivityAvailable() else {
            let (_, message) = getGraphConnectivityStatus()
            
            let alert = NSAlert()
            alert.messageText = "Microsoft Graph Not Available"
            alert.informativeText = "\(message)\n\nThe App Category Manager requires a working connection to Microsoft Graph to fetch application data. Please check your authentication settings and internet connectivity."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Check if there's an existing App Category Manager window
        if let existingWindowController = appCategoryManagerWindowControllers.first(where: { $0.window?.isVisible == true }) {
            existingWindowController.window?.makeKeyAndOrderFront(nil) // Bring to front
            return
        }

        let storyboard = NSStoryboard(name: "AppCategories", bundle: nil)

        guard let appsCategoriesManagerVC = storyboard.instantiateController(withIdentifier: "AppCategoryManagerViewController") as? AppCategoryManagerViewController else {
            Logger.error("Failed to instantiate AppCategoryManagerViewController", category: .core, toUserDirectory: true)
            return
        }

        let windowWidth: CGFloat = 650
        let windowHeight: CGFloat = 500

        let appsCategoriesManagerWindow = NSWindow(
            contentRect: NSMakeRect(0, 0, windowWidth, windowHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        appsCategoriesManagerWindow.contentViewController = appsCategoriesManagerVC
        appsCategoriesManagerWindow.title = "App Category Manager"

        // Explicitly set the window frame to fix initial sizing issue
        appsCategoriesManagerWindow.setFrame(NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight), display: true)

        // Set minimum window size
        appsCategoriesManagerWindow.minSize = NSSize(width: windowWidth, height: windowHeight)

        // Center the window on the screen
        appsCategoriesManagerWindow.center()

        let windowController = NSWindowController(window: appsCategoriesManagerWindow)
        windowController.showWindow(self)

        // Keep reference to prevent deallocation
        appCategoryManagerWindowControllers.append(windowController)
    }

    /**
     * Opens or focuses the App Installation Reporting window.
     *
     * This method manages a separate window for viewing Intune apps
     * It implements singleton behavior:
     * - If window already exists and is visible, brings it to front
     * - Otherwise creates a new window with proper sizing and configuration
     *
     * The window is tracked in appsReportingManagerWindowControllers to
     * prevent multiple instances and ensure proper memory management.
     *
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openAppsReportingManagerWindow(_ sender: Any) {
        // First check if Graph connectivity is available
        guard isGraphConnectivityAvailable() else {
            let (_, message) = getGraphConnectivityStatus()
            
            let alert = NSAlert()
            alert.messageText = "Microsoft Graph Not Available"
            alert.informativeText = "\(message)\n\nThe App Installation Reporting requires a working connection to Microsoft Graph to fetch application data. Please check your authentication settings and internet connectivity."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Check if there's an existing App Installation Reporting window
        if let existingWindowController = appsReportingManagerWindowControllers.first(where: { $0.window?.isVisible == true }) {
            existingWindowController.window?.makeKeyAndOrderFront(nil) // Bring to front
            return
        }

        let storyboard = NSStoryboard(name: "AppsReporting", bundle: nil)

        guard let appsReportingManagerVC = storyboard.instantiateController(withIdentifier: "AppsReportingManagerViewController") as? AppsReportingManagerViewController else {
            Logger.error("Failed to instantiate AppsReportingManagerViewController", category: .core, toUserDirectory: true)
            return
        }

        let frame = restoredWindowFrame(forElement: "AppsReportingManagerViewController", defaultSize: NSSize(width: 820, height: 410))

        let appsReportingManagerWindow = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        appsReportingManagerWindow.contentViewController = appsReportingManagerVC
        appsReportingManagerWindow.title = "App Installation Status"

        // Set minimum window size
        appsReportingManagerWindow.minSize = NSSize(width: 820, height: 410)
        appsReportingManagerWindow.setFrame(frame, display: true)

        let windowController = NSWindowController(window: appsReportingManagerWindow)
        windowController.showWindow(self)
        
        // Keep reference to prevent deallocation
        appsReportingManagerWindowControllers.append(windowController)
    }

    /**
     * Opens or focuses the Configuration Profile Reporting window.
     *
     * This method manages a separate window for viewing Intune config profiles
     * It implements singleton behavior:
     * - If window already exists and is visible, brings it to front
     * - Otherwise creates a new window with proper sizing and configuration
     *
     * The window is tracked in configReportingManagerWindowControllers to
     * prevent multiple instances and ensure proper memory management.
     *
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openConfigReportingManagerWindow(_ sender: Any) {
        // First check if Graph connectivity is available
        guard isGraphConnectivityAvailable() else {
            let (_, message) = getGraphConnectivityStatus()
            
            let alert = NSAlert()
            alert.messageText = "Microsoft Graph Not Available"
            alert.informativeText = "\(message)\n\nThe Configuration Installation Reporting requires a working connection to Microsoft Graph to fetch application data. Please check your authentication settings and internet connectivity."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Check if there's an existing Config Reporting window
        if let existingWindowController = configReportingManagerWindowControllers.first(where: { $0.window?.isVisible == true }) {
            existingWindowController.window?.makeKeyAndOrderFront(nil) // Bring to front
            return
        }

        let storyboard = NSStoryboard(name: "ConfigReporting", bundle: nil)

        guard let configReportingManagerVC = storyboard.instantiateController(withIdentifier: "ConfigReportingManagerViewController") as? ConfigReportingManagerViewController else {
            Logger.error("Failed to instantiate ConfigReportingManagerViewController", category: .core, toUserDirectory: true)
            return
        }

        let frame = restoredWindowFrame(forElement: "ConfigReportingManagerViewController", defaultSize: NSSize(width: 820, height: 410))

        let configReportingManagerWindow = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        configReportingManagerWindow.contentViewController = configReportingManagerVC
        configReportingManagerWindow.title = "Config Installation Status"

        // Set minimum window size
        configReportingManagerWindow.minSize = NSSize(width: 820, height: 410)
        configReportingManagerWindow.setFrame(frame, display: true)

        let windowController = NSWindowController(window: configReportingManagerWindow)
        windowController.showWindow(self)
        
        // Keep reference to prevent deallocation
        configReportingManagerWindowControllers.append(windowController)
    }

    @IBAction func openDevicesManagerWindow(_ sender: Any) {
        // First check if Graph connectivity is available
        guard isGraphConnectivityAvailable() else {
            let (_, message) = getGraphConnectivityStatus()
            
            let alert = NSAlert()
            alert.messageText = "Microsoft Graph Not Available"
            alert.informativeText = "\(message)\n\nThe Devices window requires a working connection to Microsoft Graph to fetch application data. Please check your authentication settings and internet connectivity."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Check if there's an existing Devices manager window
        if let existingWindowController = devicesManagerWindowControllers.first(where: { $0.window?.isVisible == true }) {
            existingWindowController.window?.makeKeyAndOrderFront(nil) // Bring to front
            return
        }

        let storyboard = NSStoryboard(name: "DevicesManager", bundle: nil)

        guard let devicesManagerVC = storyboard.instantiateController(withIdentifier: "DevicesViewController") as? DevicesViewController else {
            Logger.error("Failed to instantiate DevicesViewController", category: .core, toUserDirectory: true)
            return
        }

        let frame = restoredWindowFrame(forElement: "DevicesViewController", defaultSize: NSSize(width: 950, height: 600))

        let devicesManagerWindow = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        devicesManagerWindow.contentViewController = devicesManagerVC
        devicesManagerWindow.title = "Intune Devices"

        // Set minimum window size
        devicesManagerWindow.minSize = NSSize(width: 950, height: 600)
        devicesManagerWindow.setFrame(frame, display: true)

        let windowController = NSWindowController(window: devicesManagerWindow)
        windowController.showWindow(self)
        
        // Keep reference to prevent deallocation
        devicesManagerWindowControllers.append(windowController)
    }

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
        // First check if Graph connectivity is available
        guard isGraphConnectivityAvailable() else {
            let (_, message) = getGraphConnectivityStatus()
            
            let alert = NSAlert()
            alert.messageText = "Microsoft Graph Not Available"
            alert.informativeText = "\(message)\n\nThe Discovered Apps Manager requires a working connection to Microsoft Graph to fetch application data. Please check your authentication settings and internet connectivity."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Check if there's an existing Discovered Apps Manager window
        if let existingWindowController = discoveredAppsManagerWindowControllers.first(where: { $0.window?.isVisible == true }) {
            existingWindowController.window?.makeKeyAndOrderFront(nil) // Bring to front
            return
        }

        let storyboard = NSStoryboard(name: "Main", bundle: nil)

        guard let discoveredAppsManagerVC = storyboard.instantiateController(withIdentifier: "DiscoveredAppsViewController") as? DiscoveredAppsViewController else {
            Logger.error("Failed to instantiate DiscoveredAppsViewController", category: .core, toUserDirectory: true)
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
    
    /**
     * Opens or focuses the Reports Export window.
     *
     * This method manages a separate window for viewing Intune report export
     * It implements singleton behavior:
     * - If window already exists and is visible, brings it to front
     * - Otherwise creates a new window with proper sizing and configuration
     *
     * The window is tracked in configReportExportManagerWindowControllers to
     * prevent multiple instances and ensure proper memory management.
     *
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openReportsExportManagerWindow(_ sender: Any) {
        openReportsExportManagerWindow(preselectedReportType: nil)
    }
    
    /// Opens the Reports Export window with optional preselection of report type
    /// - Parameter preselectedReportType: The report type to preselect (e.g., "Devices with Inventory")
    func openReportsExportManagerWindow(preselectedReportType: String?) {
        // First check if Graph connectivity is available
        guard isGraphConnectivityAvailable() else {
            let (_, message) = getGraphConnectivityStatus()
            
            let alert = NSAlert()
            alert.messageText = "Microsoft Graph Not Available"
            alert.informativeText = "\(message)\n\nThe Reports Export feature requires a working connection to Microsoft Graph to fetch application data. Please check your authentication settings and internet connectivity."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Check if there's an existing Reports Export window
        if let existingWindowController = reportExportManagerWindowControllers.first(where: { $0.window?.isVisible == true }) {
            // If we have a preselected report type, update the existing window
            if let reportType = preselectedReportType,
               let reportsVC = existingWindowController.window?.contentViewController as? IntuneReportsViewController {
                reportsVC.preselectReportType(reportType)
            }
            existingWindowController.window?.makeKeyAndOrderFront(nil) // Bring to front
            return
        }

        let storyboard = NSStoryboard(name: "IntuneReports", bundle: nil)

        guard let reportsExportManagerVC = storyboard.instantiateController(withIdentifier: "IntuneReportsViewController") as? IntuneReportsViewController else {
            Logger.error("Failed to instantiate IntuneReportsViewController", category: .core, toUserDirectory: true)
            return
        }

        let frame = restoredWindowFrame(forElement: "IntuneReportsViewController", defaultSize: NSSize(width: 520, height: 250))

        let reportsExportWindow = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        reportsExportWindow.contentViewController = reportsExportManagerVC
        reportsExportWindow.title = "Intune Reports Export"

        // Set minimum window size
        reportsExportWindow.minSize = NSSize(width: 520, height: 250)
        reportsExportWindow.setFrame(frame, display: true)
        
        // Preselect report type if specified
        if let reportType = preselectedReportType {
            reportsExportManagerVC.preselectReportType(reportType)
        }

        let windowController = NSWindowController(window: reportsExportWindow)
        windowController.showWindow(self)
        
        // Keep reference to prevent deallocation
        reportExportManagerWindowControllers.append(windowController)
    }


    /**
     * Opens or focuses the Intune Shell Scripts Manager window.
     *
     * This method manages a separate window for viewing and managing shell
     * scripts in the Intune tenant. It implements singleton behavior:
     * - If window already exists and is visible, brings it to front
     * - Otherwise creates a new window with proper sizing and configuration
     *
     * The window is tracked in shellScriptsManagerWindowControllers to
     * prevent multiple instances and ensure proper memory management.
     *
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openShellScriptsManagerWindow(_ sender: Any) {
        // First check if Graph connectivity is available
        guard isGraphConnectivityAvailable() else {
            let (_, message) = getGraphConnectivityStatus()
            
            let alert = NSAlert()
            alert.messageText = "Microsoft Graph Not Available"
            alert.informativeText = "\(message)\n\nThe Shell Scripts Manager requires a working connection to Microsoft Graph to fetch application data. Please check your authentication settings and internet connectivity."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Check if there's an existing Shell Scripts Manager window
        if let existingWindowController = shellScriptManagerWindowControllers.first(where: { $0.window?.isVisible == true }) {
            existingWindowController.window?.makeKeyAndOrderFront(nil) // Bring to front
            return
        }

        let storyboard = NSStoryboard(name: "ShellScripts", bundle: nil)

        guard let shellScriptsManagerVC = storyboard.instantiateController(withIdentifier: "ScriptManagerViewController") as? ScriptManagerViewController else {
            Logger.error("Failed to instantiate ScriptManagerViewController", category: .core, toUserDirectory: true)
            return
        }

        let windowWidth: CGFloat = 820
        let windowHeight: CGFloat = 410

        let shellScriptsManagerWindow = NSWindow(
            contentRect: NSMakeRect(0, 0, windowWidth, windowHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        shellScriptsManagerWindow.contentViewController = shellScriptsManagerVC
        shellScriptsManagerWindow.title = "Shell Script Manager"

        // Explicitly set the window frame to fix initial sizing issue
        shellScriptsManagerWindow.setFrame(NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight), display: true)

        // Set minimum window size
        shellScriptsManagerWindow.minSize = NSSize(width: windowWidth, height: windowHeight)

        // Center the window on the screen
        shellScriptsManagerWindow.center()

        let windowController = NSWindowController(window: shellScriptsManagerWindow)
        windowController.showWindow(self)

        // Keep reference to prevent deallocation
        shellScriptManagerWindowControllers.append(windowController)
    }

    
    /**
     * Opens or focuses the Intune Custom Attribute Manager window.
     *
     * This method manages a separate window for viewing and managing custom
     * attributes in the Intune tenant. It implements singleton behavior:
     * - If window already exists and is visible, brings it to front
     * - Otherwise creates a new window with proper sizing and configuration
     *
     * The window is tracked in customAttributeManagerWindowControllers to
     * prevent multiple instances and ensure proper memory management.
     *
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openCustomAttributeManagerWindow(_ sender: Any) {
        // First check if Graph connectivity is available
        guard isGraphConnectivityAvailable() else {
            let (_, message) = getGraphConnectivityStatus()
            
            let alert = NSAlert()
            alert.messageText = "Microsoft Graph Not Available"
            alert.informativeText = "\(message)\n\nThe Custom Attribute Manager requires a working connection to Microsoft Graph to fetch application data. Please check your authentication settings and internet connectivity."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Check if there's an existing Custom Attribute Manager window
        if let existingWindowController = customAttributeManagerWindowControllers.first(where: { $0.window?.isVisible == true }) {
            existingWindowController.window?.makeKeyAndOrderFront(nil) // Bring to front
            return
        }

        let storyboard = NSStoryboard(name: "CustomAttributes", bundle: nil)

        guard let customAttributeManagerVC = storyboard.instantiateController(withIdentifier: "CustomAttributeManagerViewController") as? CustomAttributeManagerViewController else {
            Logger.error("Failed to instantiate CustomAttributeManagerViewController", category: .core, toUserDirectory: true)
            return
        }

        let windowWidth: CGFloat = 820
        let windowHeight: CGFloat = 410

        let customAttributeManagerWindow = NSWindow(
            contentRect: NSMakeRect(0, 0, windowWidth, windowHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        customAttributeManagerWindow.contentViewController = customAttributeManagerVC
        customAttributeManagerWindow.title = "Custom Attribute Manager"

        // Explicitly set the window frame to fix initial sizing issue
        customAttributeManagerWindow.setFrame(NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight), display: true)

        // Set minimum window size
        customAttributeManagerWindow.minSize = NSSize(width: windowWidth, height: windowHeight)

        // Center the window on the screen
        customAttributeManagerWindow.center()

        let windowController = NSWindowController(window: customAttributeManagerWindow)
        windowController.showWindow(self)

        // Keep reference to prevent deallocation
        customAttributeManagerWindowControllers.append(windowController)
    }

    @IBAction func openWebClipsManagerWindow(_ sender: Any) {
        // First check if Graph connectivity is available
        guard isGraphConnectivityAvailable() else {
            let (_, message) = getGraphConnectivityStatus()
            
            let alert = NSAlert()
            alert.messageText = "Microsoft Graph Not Available"
            alert.informativeText = "\(message)\n\nThe Web Clips Manager requires a working connection to Microsoft Graph to fetch application data. Please check your authentication settings and internet connectivity."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Check if there's an existing Web Clips Manager window
        if let existingWindowController = webClipsManagerWindowControllers.first(where: { $0.window?.isVisible == true }) {
            existingWindowController.window?.makeKeyAndOrderFront(nil) // Bring to front
            return
        }

        let storyboard = NSStoryboard(name: "WebClips", bundle: nil)

        guard let webClipsManagerVC = storyboard.instantiateController(withIdentifier: "WebClipsManagerViewController") as? WebClipsManagerViewController else {
            Logger.error("Failed to instantiate WebClipsManagerViewController", category: .core, toUserDirectory: true)
            return
        }

        let windowWidth: CGFloat = 820
        let windowHeight: CGFloat = 410

        let webClipsManagerWindow = NSWindow(
            contentRect: NSMakeRect(0, 0, windowWidth, windowHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        webClipsManagerWindow.contentViewController = webClipsManagerVC
        webClipsManagerWindow.title = "Web Clip Manager"

        // Explicitly set the window frame to fix initial sizing issue
        webClipsManagerWindow.setFrame(NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight), display: true)

        // Set minimum window size
        webClipsManagerWindow.minSize = NSSize(width: windowWidth, height: windowHeight)

        // Center the window on the screen
        webClipsManagerWindow.center()

        let windowController = NSWindowController(window: webClipsManagerWindow)
        windowController.showWindow(self)

        // Keep reference to prevent deallocation
        webClipsManagerWindowControllers.append(windowController)
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

    /**
     * Open the Intuneomator Wiki on GitHub.
     *
     * Opens the Wiki URL using the default web browser
     *
     *
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func openIntuneomatorWiki(_ sender: Any) {
        let helpWikiURL = "https://github.com/gilburns/Intuneomator/wiki"
        if let url = URL(string: helpWikiURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Automation Actions
    
    /**
     * Triggers full automation for all managed labels.
     * 
     * This action performs comprehensive validation before triggering automation:
     * 1. Checks if automation is available (folders ready + daemon enabled)
     * 2. Checks if automation is already running to prevent multiple executions
     * 3. Triggers the automation process via XPC
     * Shows appropriate user feedback during the process.
     * 
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func triggerFullAutomation(_ sender: Any) {
        // First check if automation is available (readiness + daemon status)
        guard isAutomationAvailable() else {
            let readyCount = getAutomationReadyCount()
            let daemonDisabled = isAutomationDaemonDisabled()
            
            let alert = NSAlert()
            alert.messageText = "Automation Not Available"
            
            if daemonDisabled {
                alert.informativeText = "The automation daemon is currently disabled. Please enable it in the Schedule Editor before triggering automation."
            } else if readyCount == 0 {
                alert.informativeText = "No managed labels are ready for automation. Please ensure you have properly configured labels with required metadata, assignments, and scripts."
            } else {
                alert.informativeText = "Automation is not available due to configuration issues."
            }
            
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Check if automation is already running
        XPCManager.shared.isAutomationRunning { [weak self] isRunning in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let isRunning = isRunning, isRunning {
                    // Show alert that automation is already running
                    let alert = NSAlert()
                    alert.messageText = "Automation Already Running"
                    alert.informativeText = "Full automation is already in progress. Please wait for it to complete before starting a new run."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    return
                }
                
                // Show confirmation dialog before proceeding
                let readyCount = self.getAutomationReadyCount()
                let confirmAlert = NSAlert()
                confirmAlert.messageText = "Confirm Automation Start"
                confirmAlert.informativeText = "This will start full automation for \(readyCount) ready label\(readyCount == 1 ? "" : "s"). The automation process will potentially download, package, and upload applications to Microsoft Intune.\n\n⚠️ This action cannot be canceled once started and may take multiple minutes to complete."
                confirmAlert.alertStyle = .warning
                confirmAlert.addButton(withTitle: "Start Automation")
                confirmAlert.addButton(withTitle: "Cancel")
                
                let response = confirmAlert.runModal()
                
                // Check if user confirmed (first button = .alertFirstButtonReturn)
                guard response == .alertFirstButtonReturn else {
                    // User canceled - do nothing
                    Logger.info("User canceled automation trigger", category: .core, toUserDirectory: true)
                    return
                }
                
                // User confirmed - proceed with automation
                self.statusLabel.stringValue = "Triggering automation for \(readyCount) ready labels..."
                Logger.info("User confirmed automation trigger for \(readyCount) labels", category: .core, toUserDirectory: true)
                

                XPCManager.shared.triggerDaemon(triggerType: "automation") { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        if let (success, message) = result {
                            if success {
                                self.statusLabel.stringValue = message ?? "Full automation triggered successfully"
                                Logger.info("✅ Full automation triggered for \(readyCount) labels", category: .core, toUserDirectory: true)
                            } else {
                                self.statusLabel.stringValue = "Failed to trigger automation: \(message ?? "Unknown error")"
                                Logger.error("❌ Failed to trigger automation: \(message ?? "Unknown error")", category: .core)
                            }
                        } else {
                            self.statusLabel.stringValue = "Failed to communicate with automation service"
                            Logger.error("❌ XPC communication failed for automation trigger", category: .core)
                        }
                    }
                }
            }
        }
    }


}
