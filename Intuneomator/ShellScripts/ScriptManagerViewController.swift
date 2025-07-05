//
//  ScriptManagerViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/22/25.
//

import Cocoa

class ScriptManagerViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextViewDelegate {
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var editButton: NSButton!
        
    var allScripts: [[String: Any]] = []
    
    // Date formatter for human-friendly dates
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private lazy var isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /// Converts Microsoft Graph ISO8601 date string to human-friendly format
    /// - Parameter dateString: ISO8601 date string from Microsoft Graph API
    /// - Returns: Human-friendly date string or "Unknown" if parsing fails
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString, !dateString.isEmpty else {
            return "Unknown"
        }
        
        // Try parsing with ISO8601 formatter first
        if let date = isoDateFormatter.date(from: dateString) {
            return dateFormatter.string(from: date)
        }
        
        // Fallback: try with standard ISO formatter without fractional seconds
        let fallbackFormatter = ISO8601DateFormatter()
        if let date = fallbackFormatter.date(from: dateString) {
            return dateFormatter.string(from: date)
        }
        
        // If all parsing fails, return the original string
        return dateString
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(doubleClickTableRow(_:))
        
        // Initial button state
        deleteButton.isEnabled = false
        editButton.isEnabled = false

        loadScripts()
    }
    
    func loadScripts() {
        // Show loading state
        DispatchQueue.main.async {
            self.deleteButton.isEnabled = false
            self.editButton.isEnabled = false
        }
        
        // First ensure Entra groups are loaded for assignment display name lookup
        Task {
            do {
                try await AppDataManager.shared.fetchEntraGroups()
                Logger.info("Entra groups loaded for assignment lookup", category: .core, toUserDirectory: true)
            } catch {
                Logger.error("Failed to load Entra groups: \(error)", category: .core, toUserDirectory: true)
                // Continue anyway - we'll fall back to GUID display
            }
            
            // Now load scripts
            DispatchQueue.main.async {
                self.fetchAndLoadScripts()
            }
        }
    }
    
    private func fetchAndLoadScripts() {
        XPCManager.shared.fetchIntuneShellScripts { scripts in
                DispatchQueue.main.async {
                    if let scripts = scripts {
                        Logger.info("Successfully loaded \(scripts.count) shell scripts", category: .core, toUserDirectory: true)
                        self.allScripts = scripts
                        self.tableView.reloadData()

                        // Load assignments for each script
                        for (index, script) in self.allScripts.enumerated() {
                            if let scriptId = script["id"] as? String {
                                XPCManager.shared.getShellScriptAssignments(scriptId: scriptId) { assignments in
                                    DispatchQueue.main.async {
                                        if let assignments = assignments {
                                            // Add assignments to the script data
                                            self.allScripts[index]["assignments"] = assignments
                                        } else {
                                            // Set empty assignments array if fetch failed
                                            self.allScripts[index]["assignments"] = []
                                            Logger.error("Failed to retrieve assignments for script: \(script["displayName"] as? String ?? "Unknown")", category: .core, toUserDirectory: true)
                                        }
                                        // Reload table to update assignment column
                                        self.tableView.reloadData()
                                    }
                                }
                            }
                        }


                        // Re-enable buttons based on selection
                        let selectedRow = self.tableView.selectedRow
                        let hasSelection = selectedRow >= 0 && selectedRow < scripts.count
                        self.deleteButton.isEnabled = hasSelection
                        self.editButton.isEnabled = hasSelection
                        
                    } else {
                        Logger.error("Failed to fetch shell scripts from Intune", category: .core, toUserDirectory: true)
                        self.showError(message: "Failed to load shell scripts from Intune. Please check your connection and authentication.")
                        self.allScripts = []
                    }
                }
            }
    }
    
    // MARK: - Group Assignment Handling
    
    /// Transforms group assignment data for Microsoft Graph API and handles assignment operations
    /// - Parameters:
    ///   - groupAssignments: Array of group assignment data from the UI
    ///   - scriptId: The script ID to assign groups to
    ///   - completion: Called when assignment operations are complete
    private func handleGroupAssignments(_ groupAssignments: [[String: Any]], for scriptId: String, completion: @escaping (Bool) -> Void) {
        // Always remove all existing assignments first, regardless of whether there are new assignments
        Logger.info("Removing existing assignments for script: \(scriptId)", category: .core, toUserDirectory: true)
        XPCManager.shared.removeAllShellScriptAssignments(scriptId: scriptId) { removeSuccess in
            guard removeSuccess == true else {
                Logger.error("Failed to remove existing assignments for script: \(scriptId)", category: .core, toUserDirectory: true)
                completion(false)
                return
            }
            
            // If no new assignments, we're done (all assignments have been removed)
            guard !groupAssignments.isEmpty else {
                Logger.info("No new assignments to apply - all assignments removed for script: \(scriptId)", category: .core, toUserDirectory: true)
                completion(true)
                return
            }
            
            // Transform assignments for Microsoft Graph API
            let transformedAssignments = self.transformGroupAssignmentsForAPI(groupAssignments)
            
            // Debug logging
            Logger.info("Original assignments: \(groupAssignments)", category: .core, toUserDirectory: true)
            Logger.info("Transformed assignments: \(transformedAssignments)", category: .core, toUserDirectory: true)
            
            // If no valid assignments after transformation, complete successfully
            guard !transformedAssignments.isEmpty else {
                Logger.info("No valid assignments to apply for script: \(scriptId)", category: .core, toUserDirectory: true)
                completion(true)
                return
            }
            
            // Apply new assignments
            Logger.info("Applying \(transformedAssignments.count) new assignments for script: \(scriptId)", category: .core, toUserDirectory: true)
            XPCManager.shared.assignGroupsToShellScript(scriptId: scriptId, groupAssignments: transformedAssignments) { assignSuccess in
                if assignSuccess == true {
                    Logger.info("Successfully assigned groups to script: \(scriptId)", category: .core, toUserDirectory: true)
                    completion(true)
                } else {
                    Logger.error("Failed to assign groups to script: \(scriptId)", category: .core, toUserDirectory: true)
                    completion(false)
                }
            }
        }
    }
    
    /// Transforms UI group assignment data to Microsoft Graph API format
    /// - Parameter groupAssignments: Array of group assignment data from the UI
    /// - Returns: Array of assignment data formatted for Microsoft Graph API
    private func transformGroupAssignmentsForAPI(_ groupAssignments: [[String: Any]]) -> [[String: Any]] {
        var transformedAssignments: [[String: Any]] = []
        
        for assignment in groupAssignments {
            guard let displayName = assignment["displayName"] as? String,
                  let mode = assignment["mode"] as? String,
                  let assignmentType = assignment["assignmentType"] as? String else {
                continue
            }
            
            let isVirtual = assignment["isVirtual"] as? Bool ?? false
            var transformedAssignment: [String: Any] = [:]
            
            if isVirtual {
                // Handle virtual groups
                if displayName == "All Users" {
                    transformedAssignment["groupId"] = "acacacac-9df4-4c7d-9d50-4ef0226f57a9"
                } else if displayName == "All Devices" {
                    transformedAssignment["groupId"] = "adadadad-808e-44e2-905a-0b7873a8a531"
                } else {
                    continue // Skip unknown virtual groups
                }
            } else {
                // Handle real groups - use "id" key for real groups
                guard let groupId = assignment["id"] as? String else {
                    continue
                }
                transformedAssignment["groupId"] = groupId
            }
            
            // Add mode (include/exclude)
            transformedAssignment["mode"] = mode
            
            // Add assignment type
            transformedAssignment["assignmentType"] = assignmentType
            
            transformedAssignments.append(transformedAssignment)
        }
        
        return transformedAssignments
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
            
            Logger.debug("Processing assignment target type: \(targetType)", category: .core, toUserDirectory: true)
            
            // Transform based on target type
            switch targetType {
            case "#microsoft.graph.allDevicesAssignmentTarget":
                transformedAssignment["displayName"] = "All Devices"
                transformedAssignment["groupId"] = "adadadad-808e-44e2-905a-0b7873a8a531"
                transformedAssignment["isVirtual"] = true
                transformedAssignment["mode"] = "include"
                transformedAssignment["assignmentType"] = "Required"
                
            case "#microsoft.graph.allLicensedUsersAssignmentTarget":
                transformedAssignment["displayName"] = "All Users"
                transformedAssignment["groupId"] = "acacacac-9df4-4c7d-9d50-4ef0226f57a9"
                transformedAssignment["isVirtual"] = true
                transformedAssignment["mode"] = "include"
                transformedAssignment["assignmentType"] = "Required"
                
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
                    }
                    
                    transformedAssignment["mode"] = "include"
                    transformedAssignment["assignmentType"] = "Required"
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
                    }
                    
                    transformedAssignment["mode"] = "exclude"
                    transformedAssignment["assignmentType"] = "Required"
                }
                
            default:
                // Skip unknown target types
                continue
            }
            
            // Add assignment ID for future operations
            if let assignmentId = assignment["id"] as? String {
                transformedAssignment["assignmentId"] = assignmentId
            }
            
            transformedAssignments.append(transformedAssignment)
        }
        
        return transformedAssignments
    }
    
    // MARK: - Script Editor Sheet
    func openScriptEditor(for script: [String: Any], isNew: Bool) {
        if isNew {
            // For new scripts, assignments will be empty
            var newScript = script
            newScript["groupAssignments"] = []
            presentEditor(with: newScript, isNew: true)
        } else if let scriptId = script["id"] as? String {
            // Show loading state - disable buttons during fetch
            editButton.isEnabled = false
            deleteButton.isEnabled = false
            
            XPCManager.shared.getShellScriptDetails(scriptId: scriptId) { details in
                DispatchQueue.main.async {
                    // Re-enable buttons
                    let selectedRow = self.tableView.selectedRow
                    let hasSelection = selectedRow >= 0 && selectedRow < self.allScripts.count
                    self.deleteButton.isEnabled = hasSelection
                    self.editButton.isEnabled = hasSelection
                    
                    if let details = details {
                        Logger.info("Successfully loaded script details for: \(details["displayName"] as? String ?? "Unknown")", category: .core, toUserDirectory: true)
                        
                        var detailedScript = details
                        detailedScript["id"] = scriptId
                        
                        // Transform and add assignment data from allScripts array
                        if let assignments = script["assignments"] as? [[String: Any]] {
                            let transformedAssignments = self.transformAssignmentsForGroupView(assignments)
                            detailedScript["groupAssignments"] = transformedAssignments
                            Logger.info("Added \(assignments.count) assignments to script data for editor", category: .core, toUserDirectory: true)
                        } else {
                            detailedScript["groupAssignments"] = []
                            Logger.info("No assignments found for script, using empty array", category: .core, toUserDirectory: true)
                        }
                        
                        self.presentEditor(with: detailedScript, isNew: false)
                    } else {
                        Logger.error("Failed to fetch script details for ID: \(scriptId)", category: .core, toUserDirectory: true)
                        self.showError(message: "Failed to load script details. Please try again.")
                    }
                }
            }
        } else {
            showError(message: "Script ID not found.")
        }
    }
    
    private func presentEditor(with script: [String: Any], isNew: Bool) {
        guard let tabbedVC = TabbedSheetViewController.createScriptEditor(
            scriptData: script,
            isNewScript: isNew,
            saveHandler: { combinedData in
                self.handleScriptSave(combinedData, isNew: isNew)
            },
            cancelHandler: {
                // Optional: Handle cancel if needed
                Logger.info("User cancelled script editing", category: .core, toUserDirectory: true)
            }
        ) else {
            showError(message: "Failed to create script editor. Please try again.")
            return
        }
        
        self.presentAsSheet(tabbedVC)
    }
    
    // MARK: - NSTableView DataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return allScripts.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnIdentifier = tableColumn?.identifier.rawValue else { return nil }
        let script = allScripts[row]
        
        if columnIdentifier == "NameColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("NameCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = script["displayName"] as? String ?? "Unknown"
            return cell
        } else if columnIdentifier == "AssignedColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("AssignedCell"), owner: self) as? NSTableCellView
            
            // Check if assignments are loaded and show appropriate status
            if let assignments = script["assignments"] as? [[String: Any]] {
                let assignmentCount = assignments.count
                if assignmentCount > 0 {
                    cell?.textField?.stringValue = "🟢 (\(assignmentCount))"
                    cell?.textField?.textColor = NSColor.systemGreen
                } else {
                    cell?.textField?.stringValue = "🔘 (0)"
                    cell?.textField?.textColor = NSColor.systemGray
                }
            } else {
                // Assignments not loaded yet
                cell?.textField?.stringValue = "⏳"
                cell?.textField?.textColor = NSColor.systemGray
            }
            return cell
        } else if columnIdentifier == "IDColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("IDCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = script["id"] as? String ?? "ID Pending"
            return cell
        } else if columnIdentifier == "RunAsColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("RunAsCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = script["runAsAccount"] as? String ?? "Unknown"
            return cell
        } else if columnIdentifier == "CreatedColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("CreatedCell"), owner: self) as? NSTableCellView
            let createdDate = script["createdDateTime"] as? String
            cell?.textField?.stringValue = formatDate(createdDate)
            return cell
        } else if columnIdentifier == "ModifiedColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ModifiedCell"), owner: self) as? NSTableCellView
            let modifiedDate = script["lastModifiedDateTime"] as? String
            cell?.textField?.stringValue = formatDate(modifiedDate)
            return cell
        }
        return nil
    }
        
    // MARK: - NSTableView Delegate
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        let hasSelection = selectedRow >= 0 && selectedRow < allScripts.count

        deleteButton.isEnabled = hasSelection
        editButton.isEnabled = hasSelection
    }
    
        
    func handleScriptSave(_ updatedScript: [String: Any], isNew: Bool) {
        let displayName = updatedScript["displayName"] as? String ?? "Unnamed Script"
        Logger.info("Handling script save - Display Name: \(displayName), Is New: \(isNew)", category: .core, toUserDirectory: true)
        let scriptContent = updatedScript["scriptContent"] as? String ?? ""
        
        if isNew {
            // Create new script
            let filename = "\(displayName).sh"
            let scriptData: [String: Any] = [
                "displayName": displayName,
                "scriptContent": Data(scriptContent.utf8).base64EncodedString(),
                "fileName": filename,
                "blockExecutionNotifications": updatedScript["blockExecutionNotifications"] as? Bool ?? false,
                "retryCount": updatedScript["retryCount"] as? Int ?? 2,
                "executionFrequency": updatedScript["executionFrequency"] as? String ?? "PT0M",
                "runAsAccount": updatedScript["runAsAccount"] as? String ?? "system",
                "roleScopeTagIds": updatedScript["roleScopeTagIds"] as? [String] ?? [],
                "description": updatedScript["description"] as? String ?? ""
            ]
            
            XPCManager.shared.createNewShellScript(scriptData: scriptData) { scriptId in
                DispatchQueue.main.async {
                    if let scriptId = scriptId {
                        // Handle group assignments if any exist
                        if let groupAssignments = updatedScript["groupAssignments"] as? [[String: Any]], !groupAssignments.isEmpty {
                            self.handleGroupAssignments(groupAssignments, for: scriptId) { assignmentSuccess in
                                DispatchQueue.main.async {
                                    if assignmentSuccess {
                                        Logger.info("Successfully created script '\(displayName)' with assignments", category: .core, toUserDirectory: true)
                                        self.showSuccess(message: "Script '\(displayName)' created successfully with group assignments.")
                                    } else {
                                        Logger.error("Script created but failed to assign groups", category: .core, toUserDirectory: true)
                                        self.showError(message: "Script '\(displayName)' created but failed to assign groups.")
                                    }
                                    self.loadScripts()
                                }
                            }
                        } else {
                            Logger.info("Successfully created script '\(displayName)' with ID: \(scriptId)", category: .core, toUserDirectory: true)
                            self.showSuccess(message: "Script '\(displayName)' created successfully.")
                            self.loadScripts()
                        }
                    } else {
                        Logger.error("Failed to create script '\(displayName)'", category: .core, toUserDirectory: true)
                        self.showError(message: "Failed to create script '\(displayName)'. Please check your connection and try again.")
                    }
                }
            }
        } else {
            // Update existing script
            guard let scriptId = updatedScript["id"] as? String else {
                showError(message: "Script ID missing. Cannot update script.")
                return
            }
            
            // Build update data with only changed properties
            var updateData: [String: Any] = [:]
            
            if let displayName = updatedScript["displayName"] as? String {
                updateData["displayName"] = displayName
            }
            if let description = updatedScript["description"] as? String {
                updateData["description"] = description
            }
            if let runAsAccount = updatedScript["runAsAccount"] as? String {
                updateData["runAsAccount"] = runAsAccount
            }
            if let retryCount = updatedScript["retryCount"] as? Int {
                updateData["retryCount"] = retryCount
            }
            if let executionFrequency = updatedScript["executionFrequency"] as? String {
                updateData["executionFrequency"] = executionFrequency
            }
            if let blockNotifications = updatedScript["blockExecutionNotifications"] as? Bool {
                updateData["blockExecutionNotifications"] = blockNotifications
            }
            
            // Always update script content
            updateData["scriptContent"] = Data(scriptContent.utf8).base64EncodedString()
            
            XPCManager.shared.updateShellScript(scriptId: scriptId, updatedData: updateData) { success in
                DispatchQueue.main.async {
                    if success == true {
                        // Handle group assignments if they exist
                        if let groupAssignments = updatedScript["groupAssignments"] as? [[String: Any]] {
                            self.handleGroupAssignments(groupAssignments, for: scriptId) { assignmentSuccess in
                                DispatchQueue.main.async {
                                    if assignmentSuccess {
                                        Logger.info("Successfully updated script '\(displayName)' with assignments", category: .core, toUserDirectory: true)
                                        self.showSuccess(message: "Script '\(displayName)' updated successfully with group assignments.")
                                    } else {
                                        Logger.error("Script updated but failed to update assignments", category: .core, toUserDirectory: true)
                                        self.showError(message: "Script '\(displayName)' updated but failed to update group assignments.")
                                    }
                                    self.loadScripts()
                                }
                            }
                        } else {
                            Logger.info("Successfully updated script '\(displayName)'", category: .core, toUserDirectory: true)
                            self.showSuccess(message: "Script '\(displayName)' updated successfully.")
                            self.loadScripts()
                        }
                    } else {
                        Logger.error("Failed to update script '\(displayName)'", category: .core,toUserDirectory: true)
                        self.showError(message: "Failed to update script '\(displayName)'. Please check your connection and try again.")
                    }
                }
            }
        }
    }
    
    // MARK: - Double Click Table
    @objc func doubleClickTableRow(_ sender: AnyObject) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < allScripts.count else { return }
        let script = allScripts[selectedRow]
        openScriptEditor(for: script, isNew: false)
    }
    
    
    // MARK: - Action Buttons

    @IBAction func editSelectedScript(_ sender: Any) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < allScripts.count else {
            showError(message: "Please select a script to edit.")
            return
        }
        let script = allScripts[selectedRow]
        openScriptEditor(for: script, isNew: false)
    }
    
    @IBAction func deleteScriptFromIntune(_ sender: Any) {
        guard tableView.selectedRow >= 0, tableView.selectedRow < allScripts.count else {
            showError(message: "No script selected.")
            return
        }

        let script = allScripts[tableView.selectedRow]
        guard let scriptId = script["id"] as? String, !scriptId.isEmpty else {
            showError(message: "Selected script has no valid ID.")
            return
        }
        
        let scriptName = script["displayName"] as? String ?? "Unknown Script"

        let alert = NSAlert()
        alert.messageText = "Delete Script"
        alert.informativeText = "Are you sure you want to permanently delete '\(scriptName)' from Intune?\n\n⚠️ This action cannot be undone and will remove all device assignments."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Disable buttons during deletion
            deleteButton.isEnabled = false
            editButton.isEnabled = false
            
            XPCManager.shared.deleteShellScript(scriptId: scriptId) { success in
                DispatchQueue.main.async {
                    if success == true {
                        Logger.info("Successfully deleted script '\(scriptName)'", category: .core,toUserDirectory: true)
                        self.showSuccess(message: "Script '\(scriptName)' deleted successfully.")
                        self.loadScripts() // Refresh list after deletion
                    } else {
                        Logger.error("Failed to delete script '\(scriptName)'", category: .core,toUserDirectory: true)
                        self.showError(message: "Failed to delete script '\(scriptName)'. Please check your connection and try again.")
                        
                        // Re-enable buttons on failure
                        let selectedRow = self.tableView.selectedRow
                        let hasSelection = selectedRow >= 0 && selectedRow < self.allScripts.count
                        self.deleteButton.isEnabled = hasSelection
                        self.editButton.isEnabled = hasSelection
                    }
                }
            }
        }
    }
    
    @IBAction func addScriptToIntune(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.message = "Select a Script File"
        openPanel.allowedContentTypes = [.text, .shellScript, .sourceCode]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false

        openPanel.begin { response in
            if response == .OK, let fileURL = openPanel.url {
                do {
                    let scriptData = try Data(contentsOf: fileURL)
                    let scriptContent = scriptData.base64EncodedString()
                    let decodedString = String(data: scriptData, encoding: .utf8) ?? "Unable to decode script."

                    let scriptName = fileURL.deletingPathExtension().lastPathComponent

                    let newScript: [String: Any] = [
                        "displayName": scriptName,
                        "scriptContent": decodedString, // Use decoded content for editing
                        "fileName": "\(scriptName).sh",
                        "blockExecutionNotifications": false,
                        "executionFrequency": "PT0M",
                        "retryCount": 2,
                        "runAsAccount": "system",
                        "description": "",
                        "roleScopeTagIds": []
                    ]
                    
                    self.openScriptEditor(for: newScript, isNew: true)
                } catch {
                    self.showError(message: "Failed to load script file: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - User Feedback
    
    func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showSuccess(message: String) {
        let alert = NSAlert()
        alert.messageText = "Success"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
