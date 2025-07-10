//
//  WebClipsManagerViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/7/25.
//

import Cocoa

class WebClipsManagerViewController: NSViewController {
    // MARK: - Properties
    var webClips: [[String: Any]] = []
    private var isLoading: Bool = false

    // MARK: - UI Elements
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
    
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var editButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var refreshButton: NSButton!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Web Clips Manager"
        setupUI()
        loadWebClips()
        
        // Safety check for tableView
        if let tableView = tableView {
            tableView.reloadData()
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Verify IBOutlets are connected
        guard let tableView = tableView,
              let editButton = editButton,
              let deleteButton = deleteButton,
              let activityIndicator = activityIndicator else {
            fatalError("IBOutlets are not properly connected in Interface Builder")
        }
        
        // Configure table view
        tableView.target = self
        tableView.doubleAction = #selector(editWebClip)
        
        // Initially disable edit/delete buttons
        editButton.isEnabled = false
        deleteButton.isEnabled = false
    }
    
    // MARK: - Data Loading
    private func loadWebClips() {
        // Prevent concurrent loading
        guard !isLoading else {
            Logger.info("Web clips already loading, skipping duplicate request", toUserDirectory: true)
            return
        }
        
        // Safety check for activityIndicator
        guard let activityIndicator = activityIndicator else {
            Logger.error("activityIndicator is nil - IBOutlet not connected", category: .core, toUserDirectory: true)
            return
        }
        
        isLoading = true
        activityIndicator.isHidden = false
        activityIndicator.startAnimation(nil)
        
        XPCManager.shared.fetchIntuneWebClips { [weak self] webClips in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let webClips = webClips {
                    // Update the web clips array
                    self.webClips = webClips
                    
                    
                    // Sort web clips and reload table view consistently
                    self.reloadTableData()
                    
                    // Reset selection and update button state
                    self.tableView?.deselectAll(nil)
                    self.updateButtonState()
                    
                    Logger.info("Loaded \(self.webClips.count) web clips", toUserDirectory: true)
                } else {
                    Logger.error("Failed to fetch Intune web clips", category: .core, toUserDirectory: true)
                    self.showAlert(title: "Error", message: "Failed to load web clips from Intune")
                }
                
                // Stop activity indicator and reset loading flag
                self.activityIndicator?.stopAnimation(nil)
                self.activityIndicator?.isHidden = true
                self.isLoading = false
            }
        }
    }
    
    // Ensuring sorting consistency
    func reloadTableData() {
        sortWebClips()
        
        
        tableView?.reloadData()
    }
    
    private func sortWebClips() {
        webClips.sort { webClip1, webClip2 in
            let name1 = webClip1["displayName"] as? String ?? ""
            let name2 = webClip2["displayName"] as? String ?? ""
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    // MARK: - Actions
    @IBAction func addButtonClicked(_ sender: NSButton) {
        addWebClip()
    }
    
    @IBAction func editButtonClicked(_ sender: NSButton) {
        editWebClip()
    }
    
    @IBAction func deleteButtonClicked(_ sender: NSButton) {
        deleteWebClip()
    }
    
    @IBAction func refreshButtonClicked(_ sender: NSButton) {
        refreshWebClips()
    }
    
    @IBAction func tableViewDoubleClicked(_ sender: NSTableView) {
        editWebClip()
    }
    
    // MARK: - Button Actions
    
    @objc private func refreshWebClips() {
        loadWebClips()
    }
    
    @objc private func addWebClip() {
        // Create initial data for a new web clip
        let initialData: [String: Any] = [
            "@odata.type": "#microsoft.graph.macOSWebClip",
            "displayName": "",
            "appUrl": "",
            "fullScreenEnabled": false,
            "preComposedIconEnabled": false,
            "description": "",
            "groupAssignments": []  // Initialize empty group assignments for new web clips
        ]
        
        // Create and present the tabbed editor
        guard let tabbedEditor = TabbedSheetViewController.createWebClipEditor(
            webClipData: initialData,
            isNewWebClip: true,
            saveHandler: { [weak self] webClipData in
                self?.createWebClipFromEditor(webClipData: webClipData)
            },
            cancelHandler: {
                Logger.info("Web clip creation cancelled", toUserDirectory: true)
            }
        ) else {
            showAlert(title: "Error", message: "Failed to open web clip editor")
            return
        }
        
        presentAsSheet(tabbedEditor)
    }
    
    @objc private func editWebClip() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < webClips.count else {
            return
        }
        
        var webClip = webClips[selectedRow]
        let webClipName = webClip["displayName"] as? String ?? "Unknown"
        let webClipId = webClip["id"] as? String ?? "Unknown"

        
        XPCManager.shared.fetchWebClipAssignmentsAndCategories(webClipId: webClipId) { fullWebClipData in
            if let completeData = fullWebClipData {
                DispatchQueue.main.async {
                    // Transform assignments for GroupAssignmentViewController compatibility
                    var processedData = completeData
                    
                    if let assignments = completeData["assignments"] as? [[String: Any]] {
                        let transformedAssignments = self.transformAssignmentsForGroupView(assignments)
                        processedData["groupAssignments"] = transformedAssignments
                    } else {
                        processedData["groupAssignments"] = []
                    }
                    
                    // Create and present the tabbed editor with complete web clip data
                    guard let tabbedEditor = TabbedSheetViewController.createWebClipEditor(
                        webClipData: processedData,
                        isNewWebClip: false,
                        saveHandler: { [weak self] webClipData in
                            self?.updateWebClipFromEditor(webClipData: webClipData)
                        },
                        cancelHandler: {
                            Logger.info("Web clip editing cancelled", toUserDirectory: true)
                        }
                    ) else {
                        self.showAlert(title: "Error", message: "Failed to open web clip editor")
                        return
                    }
                    
                    self.presentAsSheet(tabbedEditor)
                }
            } else {
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: "Failed to load web clip details for editing")
                }
            }
        }

        
    }
    
    @objc private func deleteWebClip() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < webClips.count else {
            return
        }
        
        let webClip = webClips[selectedRow]
        let webClipName = webClip["displayName"] as? String ?? "Unknown"
        let webClipUrl = webClip["appUrl"] as? String ?? "Unknown"
        let webClipId = webClip["id"] as? String ?? ""
        
        let alert = NSAlert()
        alert.messageText = "Delete Web Clip"
        alert.informativeText = "Are you sure you want to delete '\(webClipName)' (\(webClipUrl))?\n\nThis action cannot be undone and will remove the web clip from all assigned devices."
        alert.alertStyle = .critical
        
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            removeWebClip(id: webClipId, name: webClipName)
        }
    }
    
    // MARK: - API Operations
    
    private func createWebClipFromEditor(webClipData: [String: Any]) {
        let name = webClipData["displayName"] as? String ?? "Unknown"
        
        // Show activity indicator
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimation(nil)
        
        // Store the original count for comparison
        let originalCount = webClips.count
        
        XPCManager.shared.createIntuneWebClip(webClipData: webClipData) { [weak self] webClipId in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Hide activity indicator
                self.activityIndicator?.stopAnimation(nil)
                self.activityIndicator?.isHidden = true
                
                if let webClipId = webClipId {
                    Logger.info("Web clip created successfully with ID: \(webClipId)", toUserDirectory: true)
                    self.showAlert(title: "Success", message: "Web clip '\(name)' created successfully")
                    
                    // Start intelligent refresh to wait for the new item to appear
                    self.startIntelligentRefresh(expectedCount: originalCount + 1, webClipId: webClipId, webClipName: name)
                } else {
                    Logger.error("Failed to create web clip '\(name)'", category: .core, toUserDirectory: true)
                    self.showAlert(title: "Error", message: "Failed to create web clip '\(name)'")
                }
            }
        }
    }
    
    private func updateWebClipFromEditor(webClipData: [String: Any]) {
        guard let webClipId = webClipData["id"] as? String else {
            showAlert(title: "Error", message: "Web clip ID is missing")
            return
        }
        
        let name = webClipData["displayName"] as? String ?? "Unknown"
        
        // Show activity indicator for all update operations
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimation(nil)
        
        // Check if we need to handle categories and assignments separately
        let hasCategories = !(webClipData["categories"] as? [[String: Any]] ?? []).isEmpty
        let groupAssignments = webClipData["groupAssignments"] as? [[String: Any]] ?? []
        
        // Check if we had assignments originally or have assignments now
        let currentWebClip = webClips.first { $0["id"] as? String == webClipId }
        let originallyHadAssignments = currentWebClip?["isAssigned"] as? Bool ?? false
        let hasAssignmentsNow = !groupAssignments.isEmpty
        let needsAssignmentHandling = originallyHadAssignments || hasAssignmentsNow
        
        if hasCategories || needsAssignmentHandling {
            // Use the comprehensive update workflow for complex updates
            Logger.info("Using comprehensive update workflow for web clip with assignments/categories", toUserDirectory: true)
            
            // Check current assignment status to determine if we need to watch for assignment changes
            let currentlyAssigned = originallyHadAssignments
            let willBeAssigned = hasAssignmentsNow
            let expectingAssignmentChange = currentlyAssigned != willBeAssigned
            
            
            XPCManager.shared.updateWebClipWithAssignments(webClipData: webClipData) { [weak self] success in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    // Hide activity indicator
                    self.activityIndicator?.stopAnimation(nil)
                    self.activityIndicator?.isHidden = true
                    
                    if success == true {
                        Logger.info("Web clip updated successfully with assignments/categories: \(name)", toUserDirectory: true)
                        self.showAlert(title: "Success", message: "Web clip '\(name)' updated successfully with assignments and categories.")
                        
                        // Use assignment-specific refresh if we're expecting the isAssigned status to change
                        if expectingAssignmentChange {
                            self.startIntelligentRefreshForAssignmentChange(webClipId: webClipId, webClipName: name, expectedIsAssigned: willBeAssigned)
                        } else {
                            // Use standard refresh for other changes
                            self.startIntelligentRefreshForUpdate(webClipId: webClipId, webClipName: name)
                        }
                    } else {
                        Logger.error("Failed to update web clip with assignments/categories '\(name)'", category: .core, toUserDirectory: true)
                        self.showAlert(title: "Error", message: "Failed to update web clip '\(name)' with assignments and categories.")
                    }
                }
            }
            return
        }
        
        // For simple updates (no assignments or categories), use the direct update method
        // Remove read-only and metadata fields before updating
        var updatedData = webClipData
        let readOnlyFields = [
            "id",
            "appUrl",  // appUrl is immutable after creation
            "@odata.context",
            "createdDateTime",
            "lastModifiedDateTime",
            "uploadState",
            "supersedingAppCount", 
            "dependentAppCount",
            "supersededAppCount",
            "isAssigned",
            "publishingState",
            "roleScopeTagIds",
            "assignments",  // Don't include raw assignments in simple update
            "categories",   // Don't include raw categories in simple update
            "groupAssignments",  // This is for internal use only
            "isNewWebClip"  // This is for internal use only
        ]
        
        for field in readOnlyFields {
            updatedData.removeValue(forKey: field)
        }
        
        // Keep @odata.type as it's required for Graph API
        updatedData["@odata.type"] = "#microsoft.graph.macOSWebClip"
                
        XPCManager.shared.updateWebClip(webClipId: webClipId, updatedData: updatedData) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Hide activity indicator
                self.activityIndicator?.stopAnimation(nil)
                self.activityIndicator?.isHidden = true
                
                if success == true {
                    Logger.info("Web clip updated successfully: \(name)", toUserDirectory: true)
                    self.showAlert(title: "Success", message: "Web clip '\(name)' updated successfully")
                    
                    // Start intelligent refresh to show updated data
                    self.startIntelligentRefreshForUpdate(webClipId: webClipId, webClipName: name)
                } else {
                    Logger.error("Failed to update web clip '\(name)'", category: .core, toUserDirectory: true)
                    self.showAlert(title: "Error", message: "Failed to update web clip '\(name)'")
                }
            }
        }
    }
    
    private func removeWebClip(id: String, name: String) {
        // Show activity indicator
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimation(nil)
        
        // Store the original count for comparison
        let originalCount = webClips.count
        
        XPCManager.shared.deleteWebClip(webClipId: id) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Hide activity indicator
                self.activityIndicator?.stopAnimation(nil)
                self.activityIndicator?.isHidden = true
                
                if success == true {
                    Logger.info("Web clip deleted successfully: \(name)", toUserDirectory: true)
                    self.showAlert(title: "Success", message: "Web clip '\(name)' deleted successfully")
                    
                    // Start intelligent refresh to wait for the item to be removed
                    self.startIntelligentRefreshForDeletion(expectedCount: originalCount - 1, webClipId: id, webClipName: name)
                } else {
                    Logger.error("Failed to delete web clip '\(name)'", category: .core, toUserDirectory: true)
                    self.showAlert(title: "Error", message: "Failed to delete web clip '\(name)'")
                }
            }
        }
    }
    
    // MARK: - Assignment Data Transformation
    
    /// Looks up group display name by ID from cached Entra groups
    /// - Parameter groupId: The group GUID to look up
    /// - Returns: Display name if found, or formatted GUID if not found
    private func getGroupDisplayName(for groupId: String) -> String {
        let cachedGroups = AppDataManager.shared.getEntraGroups()
        if let group = cachedGroups.first(where: { $0["id"] as? String == groupId }),
           let displayName = group["displayName"] as? String {
            return displayName
        }
        // Fallback to formatted GUID if group not found in cache
        return "Group \(groupId.prefix(8))..."
    }
    
    /// Transforms Microsoft Graph assignment data to GroupAssignmentViewController format
    /// - Parameter graphAssignments: Raw assignments from Microsoft Graph API
    /// - Returns: Transformed assignments compatible with GroupAssignmentViewController
    private func transformAssignmentsForGroupView(_ graphAssignments: [[String: Any]]) -> [[String: Any]] {
        var transformedAssignments: [[String: Any]] = []
        
        for assignment in graphAssignments {
            guard let target = assignment["target"] as? [String: Any],
                  let targetType = target["@odata.type"] as? String else {
                continue
            }
            
            var transformedAssignment: [String: Any] = [:]
            
            // Extract the actual assignment intent (required/available/uninstall) from Graph API
            let assignmentIntent = assignment["intent"] as? String ?? "required"
            let assignmentType = assignmentIntent.capitalized // Convert to Required, Available, Uninstall
            
            // Transform based on target type
            switch targetType {
            case "#microsoft.graph.allDevicesAssignmentTarget":
                transformedAssignment["displayName"] = "All Devices"
                transformedAssignment["groupId"] = "adadadad-808e-44e2-905a-0b7873a8a531"
                transformedAssignment["isVirtual"] = true
                transformedAssignment["mode"] = "include"
                transformedAssignment["assignmentType"] = assignmentType
                
            case "#microsoft.graph.allLicensedUsersAssignmentTarget":
                transformedAssignment["displayName"] = "All Users"
                transformedAssignment["groupId"] = "acacacac-9df4-4c7d-9d50-4ef0226f57a9"
                transformedAssignment["isVirtual"] = true
                transformedAssignment["mode"] = "include"
                transformedAssignment["assignmentType"] = assignmentType
                
            case "#microsoft.graph.groupAssignmentTarget":
                if let groupId = target["groupId"] as? String {
                    transformedAssignment["groupId"] = groupId
                    
                    // Check if this is a virtual group
                    if groupId == "adadadad-808e-44e2-905a-0b7873a8a531" {
                        transformedAssignment["displayName"] = "All Devices"
                        transformedAssignment["isVirtual"] = true
                    } else if groupId == "acacacac-9df4-4c7d-9d50-4ef0226f57a9" {
                        transformedAssignment["displayName"] = "All Users"
                        transformedAssignment["isVirtual"] = true
                    } else {
                        transformedAssignment["displayName"] = getGroupDisplayName(for: groupId)
                        transformedAssignment["isVirtual"] = false
                        transformedAssignment["id"] = groupId  // Add id field for real groups
                    }
                    
                    transformedAssignment["mode"] = "include"
                    transformedAssignment["assignmentType"] = assignmentType
                }
                
            case "#microsoft.graph.exclusionGroupAssignmentTarget":
                if let groupId = target["groupId"] as? String {
                    transformedAssignment["groupId"] = groupId
                    
                    // Check if this is a virtual group (though exclude shouldn't be used for virtual groups)
                    if groupId == "adadadad-808e-44e2-905a-0b7873a8a531" {
                        transformedAssignment["displayName"] = "All Devices"
                        transformedAssignment["isVirtual"] = true
                    } else if groupId == "acacacac-9df4-4c7d-9d50-4ef0226f57a9" {
                        transformedAssignment["displayName"] = "All Users"
                        transformedAssignment["isVirtual"] = true
                    } else {
                        transformedAssignment["displayName"] = getGroupDisplayName(for: groupId)
                        transformedAssignment["isVirtual"] = false
                        transformedAssignment["id"] = groupId  // Add id field for real groups
                    }
                    
                    transformedAssignment["mode"] = "exclude"
                    transformedAssignment["assignmentType"] = assignmentType
                }
                
            default:
                // Skip unknown target types
                continue
            }
            
            // Extract filter information from the target if present
            if let filterId = target["deviceAndAppManagementAssignmentFilterId"] as? String,
               let filterType = target["deviceAndAppManagementAssignmentFilterType"] as? String {
                
                // Look up filter display name from cached filters
                let cachedFilters = AppDataManager.shared.getEntraFilters()
                let filterDisplayName = cachedFilters.first(where: { $0["id"] as? String == filterId })?["displayName"] as? String ?? "Unknown Filter"
                
                transformedAssignment["filter"] = [
                    "id": filterId,
                    "mode": filterType, // Keep original case (include/exclude)
                    "displayName": filterDisplayName
                ]
                
            }
            
            // Add assignment ID for future operations
            if let assignmentId = assignment["id"] as? String {
                transformedAssignment["assignmentId"] = assignmentId
            }
            
            transformedAssignments.append(transformedAssignment)
        }
        
        return transformedAssignments
    }
    
    // MARK: - Intelligent Refresh Logic
    
    /// Starts an intelligent refresh that polls until the new WebClip appears or timeout is reached
    /// - Parameters:
    ///   - expectedCount: The expected number of WebClips after the new one is created
    ///   - webClipId: The ID of the newly created WebClip to look for
    ///   - webClipName: The name of the WebClip for logging purposes
    private func startIntelligentRefresh(expectedCount: Int, webClipId: String, webClipName: String) {
        Logger.info("Starting intelligent refresh for new WebClip: \(webClipName) (\(webClipId))", toUserDirectory: true)
        
        // Show activity indicator to indicate background refresh
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimation(nil)
        
        // Start the polling process
        intelligentRefreshPolling(
            expectedCount: expectedCount,
            webClipId: webClipId,
            webClipName: webClipName,
            attempt: 1,
            maxAttempts: 10,
            interval: 3.0 // Start with 3 second intervals
        )
    }
    
    /// Recursively polls the WebClips list until the new item appears or max attempts are reached
    /// - Parameters:
    ///   - expectedCount: The expected number of WebClips after the new one is created
    ///   - webClipId: The ID of the newly created WebClip to look for
    ///   - webClipName: The name of the WebClip for logging purposes
    ///   - attempt: Current attempt number
    ///   - maxAttempts: Maximum number of attempts before giving up
    ///   - interval: Time interval between attempts (in seconds)
    private func intelligentRefreshPolling(expectedCount: Int, webClipId: String, webClipName: String, attempt: Int, maxAttempts: Int, interval: TimeInterval) {
        Logger.info("Intelligent refresh attempt \(attempt)/\(maxAttempts) for WebClip: \(webClipName)", toUserDirectory: true)
        
        XPCManager.shared.fetchIntuneWebClips { [weak self] webClips in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let webClips = webClips {
                    // Check if the new WebClip appears in the list
                    let foundNewClip = webClips.contains { clip in
                        clip["id"] as? String == webClipId
                    }
                    
                    if foundNewClip && webClips.count >= expectedCount {
                        // Success! The new WebClip has appeared
                        Logger.info("New WebClip found in list: \(webClipName)", toUserDirectory: true)
                        
                        // Update the local data and refresh the table
                        self.webClips = webClips
                        self.reloadTableData()
                        self.tableView?.deselectAll(nil)
                        self.updateButtonState()
                        
                        // Stop the activity indicator
                        self.activityIndicator?.stopAnimation(nil)
                        self.activityIndicator?.isHidden = true
                        
                        // Try to select the newly created WebClip in the table
                        self.selectWebClipInTable(webClipId: webClipId)
                        
                        return
                    }
                    
                    // Check if we've reached max attempts
                    if attempt >= maxAttempts {
                        Logger.info("Intelligent refresh timed out for WebClip: \(webClipName)", toUserDirectory: true)
                        
                        // Do a final refresh and stop
                        self.webClips = webClips
                        self.reloadTableData()
                        self.tableView?.deselectAll(nil)
                        self.updateButtonState()
                        
                        // Stop the activity indicator
                        self.activityIndicator?.stopAnimation(nil)
                        self.activityIndicator?.isHidden = true
                        
                        return
                    }
                    
                    // Continue polling with exponential backoff (but cap at 5 seconds)
                    let nextInterval = min(interval * 1.2, 5.0)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + nextInterval) {
                        self.intelligentRefreshPolling(
                            expectedCount: expectedCount,
                            webClipId: webClipId,
                            webClipName: webClipName,
                            attempt: attempt + 1,
                            maxAttempts: maxAttempts,
                            interval: nextInterval
                        )
                    }
                } else {
                    // API call failed, try again or give up
                    Logger.error("Intelligent refresh API call failed (attempt \(attempt))", category: .core, toUserDirectory: true)
                    
                    if attempt >= maxAttempts {
                        // Stop the activity indicator
                        self.activityIndicator?.stopAnimation(nil)
                        self.activityIndicator?.isHidden = true
                        return
                    }
                    
                    // Retry after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                        self.intelligentRefreshPolling(
                            expectedCount: expectedCount,
                            webClipId: webClipId,
                            webClipName: webClipName,
                            attempt: attempt + 1,
                            maxAttempts: maxAttempts,
                            interval: interval
                        )
                    }
                }
            }
        }
    }
    
    /// Attempts to select the newly created WebClip in the table view
    /// - Parameter webClipId: The ID of the WebClip to select
    private func selectWebClipInTable(webClipId: String) {
        if let index = webClips.firstIndex(where: { $0["id"] as? String == webClipId }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            tableView.scrollRowToVisible(index)
        }
    }
    
    /// Starts an intelligent refresh for WebClip updates (doesn't wait for count increase, just refreshes data)
    /// - Parameters:
    ///   - webClipId: The ID of the updated WebClip
    ///   - webClipName: The name of the WebClip for logging purposes
    private func startIntelligentRefreshForUpdate(webClipId: String, webClipName: String) {
        Logger.info("Starting intelligent refresh for updated WebClip: \(webClipName) (\(webClipId))", toUserDirectory: true)
        
        // Show activity indicator to indicate background refresh
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimation(nil)
        
        // Store the current selection to restore it later
        let selectedRow = tableView.selectedRow
        
        // Start the polling process (fewer attempts since we're just refreshing data)
        intelligentRefreshPollingForUpdate(
            webClipId: webClipId,
            webClipName: webClipName,
            selectedRow: selectedRow,
            attempt: 1,
            maxAttempts: 5,
            interval: 2.0 // Shorter intervals for updates
        )
    }
    
    /// Starts an intelligent refresh that polls until the WebClip is removed or timeout is reached
    /// - Parameters:
    ///   - expectedCount: The expected number of WebClips after the deletion
    ///   - webClipId: The ID of the deleted WebClip to check for removal
    ///   - webClipName: The name of the WebClip for logging purposes
    private func startIntelligentRefreshForDeletion(expectedCount: Int, webClipId: String, webClipName: String) {
        Logger.info("Starting intelligent refresh for deleted WebClip: \(webClipName) (\(webClipId))", toUserDirectory: true)
        
        // Show activity indicator to indicate background refresh
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimation(nil)
        
        // Start the polling process
        intelligentRefreshPollingForDeletion(
            expectedCount: expectedCount,
            webClipId: webClipId,
            webClipName: webClipName,
            attempt: 1,
            maxAttempts: 8,
            interval: 2.0 // Start with 2 second intervals for deletion
        )
    }
    
    /// Starts an intelligent refresh that polls until the WebClip's isAssigned status changes to true
    /// - Parameters:
    ///   - webClipId: The ID of the WebClip to monitor for assignment status change
    ///   - webClipName: The name of the WebClip for logging purposes
    ///   - expectedIsAssigned: The expected value of isAssigned (typically true after adding assignments)
    private func startIntelligentRefreshForAssignmentChange(webClipId: String, webClipName: String, expectedIsAssigned: Bool) {
        Logger.info("Starting intelligent refresh for assignment change: \(webClipName) (\(webClipId)), expecting isAssigned=\(expectedIsAssigned)", toUserDirectory: true)
        
        // Show activity indicator to indicate background refresh
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimation(nil)
        
        // Store the current selection to restore it later
        let selectedRow = tableView.selectedRow
        
        // Start the polling process
        intelligentRefreshPollingForAssignmentChange(
            webClipId: webClipId,
            webClipName: webClipName,
            selectedRow: selectedRow,
            expectedIsAssigned: expectedIsAssigned,
            attempt: 1,
            maxAttempts: 10, // More attempts since assignment propagation can be slower
            interval: 3.0 // Start with 3 second intervals for assignment changes
        )
    }
    
    /// Polls the WebClips list to refresh data after an update
    /// - Parameters:
    ///   - webClipId: The ID of the updated WebClip
    ///   - webClipName: The name of the WebClip for logging purposes
    ///   - selectedRow: The previously selected row to restore
    ///   - attempt: Current attempt number
    ///   - maxAttempts: Maximum number of attempts before giving up
    ///   - interval: Time interval between attempts (in seconds)
    private func intelligentRefreshPollingForUpdate(webClipId: String, webClipName: String, selectedRow: Int, attempt: Int, maxAttempts: Int, interval: TimeInterval) {
        Logger.info("Intelligent refresh (update) attempt \(attempt)/\(maxAttempts) for WebClip: \(webClipName)", toUserDirectory: true)
        
        XPCManager.shared.fetchIntuneWebClips { [weak self] webClips in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let webClips = webClips {
                    // Update the local data and refresh the table
                    self.webClips = webClips
                    self.reloadTableData()
                    
                    // Restore selection if possible
                    if selectedRow >= 0 && selectedRow < webClips.count {
                        self.tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
                        self.tableView.scrollRowToVisible(selectedRow)
                    }
                    
                    self.updateButtonState()
                    
                    // Stop the activity indicator
                    self.activityIndicator?.stopAnimation(nil)
                    self.activityIndicator?.isHidden = true
                    
                    return
                }
                
                // API call failed, try again or give up
                Logger.error("Intelligent refresh (update) API call failed (attempt \(attempt))", category: .core, toUserDirectory: true)
                
                if attempt >= maxAttempts {
                    // Stop the activity indicator
                    self.activityIndicator?.stopAnimation(nil)
                    self.activityIndicator?.isHidden = true
                    return
                }
                
                // Retry after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                    self.intelligentRefreshPollingForUpdate(
                        webClipId: webClipId,
                        webClipName: webClipName,
                        selectedRow: selectedRow,
                        attempt: attempt + 1,
                        maxAttempts: maxAttempts,
                        interval: interval
                    )
                }
            }
        }
    }
    
    /// Recursively polls the WebClips list until the deleted item is removed or max attempts are reached
    /// - Parameters:
    ///   - expectedCount: The expected number of WebClips after the deletion
    ///   - webClipId: The ID of the deleted WebClip to check for removal
    ///   - webClipName: The name of the WebClip for logging purposes
    ///   - attempt: Current attempt number
    ///   - maxAttempts: Maximum number of attempts before giving up
    ///   - interval: Time interval between attempts (in seconds)
    private func intelligentRefreshPollingForDeletion(expectedCount: Int, webClipId: String, webClipName: String, attempt: Int, maxAttempts: Int, interval: TimeInterval) {
        Logger.info("Intelligent refresh (deletion) attempt \(attempt)/\(maxAttempts) for WebClip: \(webClipName)", toUserDirectory: true)
        
        XPCManager.shared.fetchIntuneWebClips { [weak self] webClips in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let webClips = webClips {
                    // Check if the deleted WebClip is no longer in the list
                    let itemStillExists = webClips.contains { clip in
                        clip["id"] as? String == webClipId
                    }
                    
                    if !itemStillExists && webClips.count <= expectedCount {
                        // Success! The WebClip has been removed
                        Logger.info("WebClip successfully removed from list: \(webClipName)", toUserDirectory: true)
                        
                        // Update the local data and refresh the table
                        self.webClips = webClips
                        self.reloadTableData()
                        self.tableView?.deselectAll(nil)
                        self.updateButtonState()
                        
                        // Stop the activity indicator
                        self.activityIndicator?.stopAnimation(nil)
                        self.activityIndicator?.isHidden = true
                        
                        return
                    }
                    
                    // Check if we've reached max attempts
                    if attempt >= maxAttempts {
                        Logger.info("Intelligent refresh (deletion) timed out for WebClip: \(webClipName)", toUserDirectory: true)
                        
                        // Do a final refresh and stop
                        self.webClips = webClips
                        self.reloadTableData()
                        self.tableView?.deselectAll(nil)
                        self.updateButtonState()
                        
                        // Stop the activity indicator
                        self.activityIndicator?.stopAnimation(nil)
                        self.activityIndicator?.isHidden = true
                        
                        return
                    }
                    
                    // Continue polling with exponential backoff (but cap at 5 seconds)
                    let nextInterval = min(interval * 1.2, 5.0)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + nextInterval) {
                        self.intelligentRefreshPollingForDeletion(
                            expectedCount: expectedCount,
                            webClipId: webClipId,
                            webClipName: webClipName,
                            attempt: attempt + 1,
                            maxAttempts: maxAttempts,
                            interval: nextInterval
                        )
                    }
                } else {
                    // API call failed, try again or give up
                    Logger.error("Intelligent refresh (deletion) API call failed (attempt \(attempt))", category: .core, toUserDirectory: true)
                    
                    if attempt >= maxAttempts {
                        // Stop the activity indicator
                        self.activityIndicator?.stopAnimation(nil)
                        self.activityIndicator?.isHidden = true
                        return
                    }
                    
                    // Retry after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                        self.intelligentRefreshPollingForDeletion(
                            expectedCount: expectedCount,
                            webClipId: webClipId,
                            webClipName: webClipName,
                            attempt: attempt + 1,
                            maxAttempts: maxAttempts,
                            interval: interval
                        )
                    }
                }
            }
        }
    }
    
    /// Recursively polls the WebClips list until the isAssigned status changes or max attempts are reached
    /// - Parameters:
    ///   - webClipId: The ID of the WebClip to monitor for assignment status change
    ///   - webClipName: The name of the WebClip for logging purposes
    ///   - selectedRow: The previously selected row to restore
    ///   - expectedIsAssigned: The expected value of isAssigned (typically true after adding assignments)
    ///   - attempt: Current attempt number
    ///   - maxAttempts: Maximum number of attempts before giving up
    ///   - interval: Time interval between attempts (in seconds)
    private func intelligentRefreshPollingForAssignmentChange(webClipId: String, webClipName: String, selectedRow: Int, expectedIsAssigned: Bool, attempt: Int, maxAttempts: Int, interval: TimeInterval) {
        Logger.info("Intelligent refresh (assignment) attempt \(attempt)/\(maxAttempts) for WebClip: \(webClipName), expecting isAssigned=\(expectedIsAssigned)", toUserDirectory: true)
        
        XPCManager.shared.fetchIntuneWebClips { [weak self] webClips in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let webClips = webClips {
                    // Find the WebClip and check its isAssigned status
                    if let webClip = webClips.first(where: { $0["id"] as? String == webClipId }) {
                        let currentIsAssigned = webClip["isAssigned"] as? Bool ?? false
                        
                        if currentIsAssigned == expectedIsAssigned {
                            // Success! The assignment status has changed as expected
                            Logger.info("WebClip assignment status updated: \(webClipName)", toUserDirectory: true)
                            
                            // Update the local data and refresh the table
                            self.webClips = webClips
                            self.reloadTableData()
                            
                            // Restore selection if possible
                            if selectedRow >= 0 && selectedRow < webClips.count {
                                self.tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
                                self.tableView.scrollRowToVisible(selectedRow)
                            }
                            
                            self.updateButtonState()
                            
                            // Stop the activity indicator
                            self.activityIndicator?.stopAnimation(nil)
                            self.activityIndicator?.isHidden = true
                            
                            return
                        }
                        
                    } else {
                        Logger.warning("⚠️ WebClip not found in list during assignment polling: \(webClipId)", category: .core, toUserDirectory: true)
                    }
                    
                    // Check if we've reached max attempts
                    if attempt >= maxAttempts {
                        Logger.info("Intelligent refresh (assignment) timed out for WebClip: \(webClipName)", toUserDirectory: true)
                        
                        // Do a final refresh and stop
                        self.webClips = webClips
                        self.reloadTableData()
                        
                        // Restore selection if possible
                        if selectedRow >= 0 && selectedRow < webClips.count {
                            self.tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
                            self.tableView.scrollRowToVisible(selectedRow)
                        }
                        
                        self.updateButtonState()
                        
                        // Stop the activity indicator
                        self.activityIndicator?.stopAnimation(nil)
                        self.activityIndicator?.isHidden = true
                        
                        return
                    }
                    
                    // Continue polling with exponential backoff (but cap at 5 seconds)
                    let nextInterval = min(interval * 1.3, 5.0)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + nextInterval) {
                        self.intelligentRefreshPollingForAssignmentChange(
                            webClipId: webClipId,
                            webClipName: webClipName,
                            selectedRow: selectedRow,
                            expectedIsAssigned: expectedIsAssigned,
                            attempt: attempt + 1,
                            maxAttempts: maxAttempts,
                            interval: nextInterval
                        )
                    }
                } else {
                    // API call failed, try again or give up
                    Logger.error("Intelligent refresh (assignment) API call failed (attempt \(attempt))", category: .core, toUserDirectory: true)
                    
                    if attempt >= maxAttempts {
                        // Stop the activity indicator
                        self.activityIndicator?.stopAnimation(nil)
                        self.activityIndicator?.isHidden = true
                        return
                    }
                    
                    // Retry after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                        self.intelligentRefreshPollingForAssignmentChange(
                            webClipId: webClipId,
                            webClipName: webClipName,
                            selectedRow: selectedRow,
                            expectedIsAssigned: expectedIsAssigned,
                            attempt: attempt + 1,
                            maxAttempts: maxAttempts,
                            interval: interval
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateButtonState() {
        let hasSelection = tableView.selectedRow >= 0
        editButton?.isEnabled = hasSelection
        deleteButton?.isEnabled = hasSelection
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - NSTableViewDataSource

extension WebClipsManagerViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return webClips.count
    }
}

// MARK: - NSTableViewDelegate

extension WebClipsManagerViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < webClips.count else { return nil }
        
        let webClip = webClips[row]
        let cellIdentifier = tableColumn?.identifier.rawValue ?? ""
        
        let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(cellIdentifier), owner: self) as? NSTableCellView
        
        switch cellIdentifier {
        case "displayName":
            cellView?.textField?.stringValue = webClip["displayName"] as? String ?? "Unknown"
        case "appUrl":
            cellView?.textField?.stringValue = webClip["appUrl"] as? String ?? "Unknown"
        case "isAssigned":
            let isAssigned = webClip["isAssigned"] as? Bool ?? false
            cellView?.textField?.stringValue = isAssigned ? "✅" : "☑️"
            cellView?.textField?.textColor = isAssigned ? NSColor.systemGreen : NSColor.systemYellow
        default:
            cellView?.textField?.stringValue = ""
        }
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonState()
    }
}
