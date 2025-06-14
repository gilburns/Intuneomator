//
//  MainViewController+Notifications.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/11/25.
//

import Cocoa

/**
 * MainViewController+Notifications
 *
 * This extension handles all notification registration and processing for the MainViewController.
 * It manages communication between different parts of the application through the notification center.
 *
 * ## Responsibilities:
 * - Register for application and custom notifications
 * - Handle main window lifecycle events
 * - Process label editing completion notifications
 * - Manage directory addition events
 * - Update validation cache when app data changes
 *
 * ## Notification Types:
 * - **mainWindowDidLoad**: Triggered when main window finishes loading
 * - **labelWindowWillClose**: Sent when label editing sheet closes
 * - **newDirectoryAdded**: Fired when new app directory is created
 * - **labelEditCompleted**: Sent after app configuration is modified
 */
extension MainViewController {
    
    // MARK: - Notification Registration
    
    /**
     * Registers the view controller as an observer for relevant notifications.
     * 
     * This method sets up all notification observers that the main view controller
     * needs to respond to. It's called during viewDidLoad to ensure the controller
     * is ready to receive notifications throughout its lifecycle.
     * 
     * ## Registered Notifications:
     * - `.mainWindowDidLoad`: Starts data loading process
     * - `.labelWindowWillClose`: Updates UI after label editing
     * - `.newDirectoryAdded`: Adds new apps to the table view
     * - `.labelEditCompleted`: Refreshes validation status
     */
    func registerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(mainWindowDidLoad(_:)), name: .mainWindowDidLoad, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(labelWindowWillClose(_:)), name: .labelWindowWillClose, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(handleNewDirectoryAdded(_:)), name: .newDirectoryAdded, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(handleLabelEditCompleted(_:)), name: .labelEditCompleted, object: nil)
        
        // register for potential Daemon status updates
        StatusMonitor.shared.startMonitoring()
        
        // Observe changes
        StatusMonitor.shared.$operations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] operations in
                self?.updateUI(operations: operations)
            }
            .store(in: &cancellables)

    }
    
    // MARK: - Notification Handlers
    
    /**
     * Handles the main window loaded notification.
     * 
     * This is triggered when the main window has finished loading and is ready
     * to display data. It starts the data loading process with appropriate UI feedback.
     * 
     * - Parameter notification: The main window loaded notification
     * 
     * ## Actions Performed:
     * 1. Shows progress spinner to indicate loading activity
     * 2. Makes status label visible for user feedback
     * 3. Initiates asynchronous app data loading
     */
    @objc func mainWindowDidLoad(_ notification: Notification) {
        progressSpinner.startAnimation(self)
        statusLabel.isHidden = false
        loadAppData()
    }

    /**
     * Handles the label editing window close notification.
     * 
     * This is called when a label editing sheet is closed. It updates the local
     * data model with any changes made during editing and refreshes the UI.
     * 
     * - Parameter notification: Window close notification containing edited label info
     * 
     * ## Notification UserInfo Keys:
     * - `labelInfo`: The updated label string from the editing session
     * 
     * ## Update Process:
     * 1. Extracts edited label from notification
     * 2. Updates the corresponding item in filtered data
     * 3. Refreshes the entire UI to reflect changes
     */
    @objc func labelWindowWillClose(_ notification: Notification) {
        guard let editedLabel = notification.userInfo?["labelInfo"] as? String else { return }
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 {
            var editedAppInfo = filteredAppData[selectedRow]
            editedAppInfo.label = editedLabel
            filteredAppData[selectedRow] = editedAppInfo
            refreshUI()
        }
    }


    
    /**
     * Handles completion of label editing operations.
     * 
     * This is triggered after an app's configuration has been modified through
     * the editing interface. It updates the validation cache and refreshes the
     * table view to reflect any changes in automation readiness.
     * 
     * - Parameter notification: Edit completion notification with app details
     * 
     * ## Notification UserInfo Keys:
     * - `label`: The app's label identifier
     * - `guid`: The app's unique identifier
     * 
     * ## Validation Update Process:
     * 1. Constructs the app's folder path from label and GUID
     * 2. Invalidates the existing validation cache entry
     * 3. Performs fresh validation check
     * 4. Updates cache with new validation result
     * 5. Reloads table view to show updated status
     */
    @objc func handleLabelEditCompleted(_ notification: Notification) {
        // Recheck label automation status after editing
        let editedLabel = notification.userInfo?["label"] as? String ?? ""
        let editedGUID = notification.userInfo?["guid"] as? String ?? ""
        let editedLabelPath = AppConstants.intuneomatorManagedTitlesFolderURL.appendingPathComponent("\(editedLabel)_\(editedGUID)")
            .path
            .removingPercentEncoding ?? ""
        invalidateValidationCache(for: editedLabelPath)

        // Update the cached status after invalidating the existing
        let isValid: Bool
        isValid = AutomationCheck.validateFolder(at: editedLabelPath)
        validationCache[editedLabelPath] = isValid
        tableView.reloadData()
    }
    
    /**
     * Handles notifications when new app directories are added.
     * 
     * This is triggered when new app automation entries are created, either
     * through the UI or external processes. It processes the new directory
     * and adds the app to the table view without requiring a full reload.
     * 
     * - Parameter notification: Directory addition notification
     * 
     * ## Notification UserInfo Keys:
     * - `directoryPath`: Full path to the newly created app directory
     * 
     * ## Processing Steps:
     * 1. Extracts directory path from notification
     * 2. Processes the directory asynchronously to create AppInfo
     * 3. Adds new app to both main and filtered data arrays
     * 4. Sorts arrays alphabetically by app name
     * 5. Reloads table view and clears validation cache
     * 
     * ## Concurrency:
     * Directory processing is performed asynchronously, with UI updates
     * dispatched back to the main thread for thread safety.
     */
    @objc func handleNewDirectoryAdded(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let directoryPath = userInfo["directoryPath"] as? String else {
            return
        }

        let directoryURL = URL(fileURLWithPath: directoryPath)

        Task {
            if let newAppInfo = await processSubdirectory(directoryURL) {
                DispatchQueue.main.async {
                    self.appData.append(newAppInfo)
                    self.appData.sort(by: { $0.name.lowercased() < $1.name.lowercased() })
                    self.filteredAppData.append(newAppInfo)
                    self.filteredAppData.sort(by: { $0.name.lowercased() < $1.name.lowercased() })
                    self.tableView.reloadData()
                    
                    self.invalidateValidationCache()
                }
            }
        }
    }

    /**
     * Handles notifications from the Daemon and updates the GUI as required.
     *
     */
    
    private func updateUI(operations: [String: StatusMonitor.OperationProgress]) {
        let active = operations.values.filter { $0.status.isActive }
        
        if let current = active.first {
            statusLabel.stringValue = "\(current.appName): \(current.currentPhase.name)"
            progressView.doubleValue = current.overallProgress * 100
            progressView.isHidden = false
        } else {
            statusLabel.stringValue = "Ready"
            progressView.isHidden = true
        }
    }

}
