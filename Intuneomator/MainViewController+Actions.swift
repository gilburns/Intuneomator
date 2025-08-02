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
        let storyboard = NSStoryboard(name: "LabelView", bundle: nil)
        guard let controller = storyboard.instantiateController(withIdentifier: "LabelView") as? LabelViewController else { return }

        presentAsSheet(controller)
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
        let storyboard = NSStoryboard(name: "ScheduleEditor", bundle: nil)
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
        let storyboard = NSStoryboard(name: "StatsView", bundle: nil)
        guard let controller = storyboard.instantiateController(withIdentifier: "StatsViewController") as? StatsViewController else { return }

        presentAsSheet(controller)
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
