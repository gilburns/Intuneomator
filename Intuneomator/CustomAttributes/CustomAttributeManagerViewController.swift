//
//  CustomAttributeManagerViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/22/25.
//

import Cocoa

class CustomAttributeManagerViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextViewDelegate {
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var editButton: NSButton!
    @IBOutlet weak var reportButton: NSButton!
        
    var allCustomAttributes: [[String: Any]] = []
    
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
        reportButton.isEnabled = false

        loadCustomAttributes()
    }
    
    func loadCustomAttributes() {
        // Show loading state
        DispatchQueue.main.async {
            self.deleteButton.isEnabled = false
            self.editButton.isEnabled = false
            self.reportButton.isEnabled = false
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
            
            // Now load custom attributes
            DispatchQueue.main.async {
                self.fetchAndLoadCustomAttributes()
            }
        }
    }
    
    private func fetchAndLoadCustomAttributes() {
        XPCManager.shared.fetchIntuneCustomAttributeShellScripts { customAttributes in
                DispatchQueue.main.async {
                    if let customAttributes = customAttributes {
                        Logger.info("Successfully loaded \(customAttributes.count) custom attributes ", category: .core, toUserDirectory: true)
                        self.allCustomAttributes = customAttributes
                        self.tableView.reloadData()

                        // Load assignments for each custom attribute
                        for (index, customAttribute) in self.allCustomAttributes.enumerated() {
                            if let customAttributeId = customAttribute["id"] as? String {
                                XPCManager.shared.getCustomAttributeShellScriptAssignments(scriptId: customAttributeId) { assignments in
                                    DispatchQueue.main.async {
                                        if let assignments = assignments {
                                            // Add assignments to the custom attribute data
                                            self.allCustomAttributes[index]["assignments"] = assignments
                                        } else {
                                            // Set empty assignments array if fetch failed
                                            self.allCustomAttributes[index]["assignments"] = []
                                            Logger.error("Failed to retrieve assignments for custom attribute: \(customAttribute["displayName"] as? String ?? "Unknown")", category: .core, toUserDirectory: true)
                                        }
                                        // Reload table to update assignment column
                                        self.tableView.reloadData()
                                    }
                                }
                            }
                        }


                        // Re-enable buttons based on selection
                        let selectedRow = self.tableView.selectedRow
                        let hasSelection = selectedRow >= 0 && selectedRow < customAttributes.count
                        self.deleteButton.isEnabled = hasSelection
                        self.editButton.isEnabled = hasSelection
                        self.reportButton.isEnabled = hasSelection

                    } else {
                        Logger.error("Failed to fetch custom attributes from Intune", category: .core, toUserDirectory: true)
                        self.showError(message: "Failed to load custom attributes from Intune. Please check your connection and authentication.")
                        self.allCustomAttributes = []
                    }
                }
            }
    }
    
    // MARK: - Group Assignment Handling
    
    /// Transforms group assignment data for Microsoft Graph API and handles assignment operations
    /// - Parameters:
    ///   - groupAssignments: Array of group assignment data from the UI
    ///   - scriptId: The custom attribute ID to assign groups to
    ///   - completion: Called when assignment operations are complete
    private func handleGroupAssignments(_ groupAssignments: [[String: Any]], for customAttributeId: String, completion: @escaping (Bool) -> Void) {
        // Always remove all existing assignments first, regardless of whether there are new assignments
        Logger.info("Removing existing assignments for custom attribute: \(customAttributeId)", category: .core, toUserDirectory: true)
        XPCManager.shared.removeAllCustomAttributeShellScriptAssignments(scriptId: customAttributeId) { removeSuccess in
            guard removeSuccess == true else {
                Logger.error("Failed to remove existing assignments for custom attribute: \(customAttributeId)", category: .core, toUserDirectory: true)
                completion(false)
                return
            }
            
            // If no new assignments, we're done (all assignments have been removed)
            guard !groupAssignments.isEmpty else {
                Logger.info("No new assignments to apply - all assignments removed for custom attribute: \(customAttributeId)", category: .core, toUserDirectory: true)
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
                Logger.info("No valid assignments to apply for custom attribute: \(customAttributeId)", category: .core, toUserDirectory: true)
                completion(true)
                return
            }
            
            // Apply new assignments
            Logger.info("Applying \(transformedAssignments.count) new assignments for custom attribute: \(customAttributeId)", category: .core, toUserDirectory: true)
            XPCManager.shared.assignGroupsToCustomAttributeShellScript(scriptId: customAttributeId, groupAssignments: transformedAssignments) { assignSuccess in
                if assignSuccess == true {
                    Logger.info("Successfully assigned groups to custom attribute: \(customAttributeId)", category: .core, toUserDirectory: true)
                    completion(true)
                } else {
                    Logger.error("Failed to assign groups to custom attribute: \(customAttributeId)", category: .core, toUserDirectory: true)
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
    
    // MARK: - Custom Attribute Editor Sheet
    func openCustomAttributeEditor(for customAttribute: [String: Any], isNew: Bool) {
        if isNew {
            // For new custom attributes, assignments will be empty
            var newScript = customAttribute
            newScript["groupAssignments"] = []
            presentEditor(with: newScript, isNew: true)
        } else if let customAttributeId = customAttribute["id"] as? String {
            // Show loading state - disable buttons during fetch
            deleteButton.isEnabled = false
            editButton.isEnabled = false
            reportButton.isEnabled = false

            XPCManager.shared.getCustomAttributeShellScriptDetails(scriptId: customAttributeId) { details in
                DispatchQueue.main.async {
                    // Re-enable buttons
                    let selectedRow = self.tableView.selectedRow
                    let hasSelection = selectedRow >= 0 && selectedRow < self.allCustomAttributes.count
                    self.deleteButton.isEnabled = hasSelection
                    self.editButton.isEnabled = hasSelection
                    self.reportButton.isEnabled = hasSelection

                    if let details = details {
                        Logger.info("Successfully loaded custom attribute details for: \(details["displayName"] as? String ?? "Unknown")", category: .core, toUserDirectory: true)
                        var customAttributeDetails = details
                        customAttributeDetails["id"] = customAttributeId

                        // Transform and add assignment data from allCustomAttributes array
                        if let assignments = customAttribute["assignments"] as? [[String: Any]] {
                            let transformedAssignments = self.transformAssignmentsForGroupView(assignments)
                            customAttributeDetails["groupAssignments"] = transformedAssignments
                            Logger.info("Added \(assignments.count) assignments to custom attribute data for editor", category: .core, toUserDirectory: true)
                        } else {
                            customAttributeDetails["groupAssignments"] = []
                            Logger.info("No assignments found for custom attribute, using empty array", category: .core, toUserDirectory: true)
                        }
                        
                        self.presentEditor(with: customAttributeDetails, isNew: false)
                    } else {
                        Logger.error("Failed to fetch custom attribute details for ID: \(customAttributeId)", category: .core, toUserDirectory: true)
                        self.showError(message: "Failed to load custom attribute details. Please try again.")
                    }
                }
            }
        } else {
            showError(message: "Custom Attribute ID not found.")
        }
    }
    
    private func presentEditor(with customAttribute: [String: Any], isNew: Bool) {
        guard let tabbedVC = TabbedSheetViewController.createCustomAttributeEditor(
            scriptData: customAttribute,
            isNewScript: isNew,
            saveHandler: { combinedData in
                self.handleCustomAttributeSave(combinedData, isNew: isNew)
            },
            cancelHandler: {
                // Optional: Handle cancel if needed
                Logger.info("User cancelled custom attribute editing", category: .core, toUserDirectory: true)
            }
        ) else {
            showError(message: "Failed to create custom attribute editor. Please try again.")
            return
        }
        
        self.presentAsSheet(tabbedVC)
    }
    
    // MARK: - NSTableView DataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return allCustomAttributes.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnIdentifier = tableColumn?.identifier.rawValue else { return nil }
        let customAttribute = allCustomAttributes[row]
        
        if columnIdentifier == "NameColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("NameCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = customAttribute["displayName"] as? String ?? "Unknown"
            return cell
        } else if columnIdentifier == "AssignedColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("AssignedCell"), owner: self) as? NSTableCellView
            
            // Check if assignments are loaded and show appropriate status
            if let assignments = customAttribute["assignments"] as? [[String: Any]] {
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
            cell?.textField?.stringValue = customAttribute["id"] as? String ?? "ID Pending"
            return cell
        } else if columnIdentifier == "RunAsColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("RunAsCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = customAttribute["runAsAccount"] as? String ?? "Unknown"
            return cell
        } else if columnIdentifier == "CreatedColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("CreatedCell"), owner: self) as? NSTableCellView
            let createdDate = customAttribute["createdDateTime"] as? String
            cell?.textField?.stringValue = formatDate(createdDate)
            return cell
        } else if columnIdentifier == "ModifiedColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ModifiedCell"), owner: self) as? NSTableCellView
            let modifiedDate = customAttribute["lastModifiedDateTime"] as? String
            cell?.textField?.stringValue = formatDate(modifiedDate)
            return cell
        }
        return nil
    }
        
    // MARK: - NSTableView Delegate
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        let hasSelection = selectedRow >= 0 && selectedRow < allCustomAttributes.count

        deleteButton.isEnabled = hasSelection
        editButton.isEnabled = hasSelection
        reportButton.isEnabled = hasSelection
    }
    
        
    func handleCustomAttributeSave(_ updatedCustomAttribute: [String: Any], isNew: Bool) {
        let displayName = updatedCustomAttribute["displayName"] as? String ?? "Unnamed Custom Attribute"
        Logger.info("Handling custom attribute save - Display Name: \(displayName), Is New: \(isNew)", category: .core, toUserDirectory: true)
        let scriptContent = updatedCustomAttribute["scriptContent"] as? String ?? ""
        
        if isNew {
            // Create new custom attribute
            let filename = "\(displayName).sh"
            let scriptData: [String: Any] = [
                "displayName": displayName,
                "description": updatedCustomAttribute["description"] as? String ?? "",
                "scriptContent": Data(scriptContent.utf8).base64EncodedString(),
                "fileName": filename,
                "runAsAccount": updatedCustomAttribute["runAsAccount"] as? String ?? "system",
                "customAttributeType": updatedCustomAttribute["customAttributeType"] as? String ?? "string",
                "roleScopeTagIds": updatedCustomAttribute["roleScopeTagIds"] as? [String] ?? []
            ]
            
            XPCManager.shared.createNewCustomAttributeShellScript(scriptData: scriptData) { scriptId in
                DispatchQueue.main.async {
                    if let scriptId = scriptId {
                        // Handle group assignments if any exist
                        if let groupAssignments = updatedCustomAttribute["groupAssignments"] as? [[String: Any]], !groupAssignments.isEmpty {
                            self.handleGroupAssignments(groupAssignments, for: scriptId) { assignmentSuccess in
                                DispatchQueue.main.async {
                                    if assignmentSuccess {
                                        Logger.info("Successfully created custom attribute '\(displayName)' with assignments", category: .core, toUserDirectory: true)
                                        self.showSuccess(message: "Custom attribute '\(displayName)' created successfully with group assignments.")
                                    } else {
                                        Logger.error("Custom attribute created but failed to assign groups", category: .core, toUserDirectory: true)
                                        self.showError(message: "Custom attribute '\(displayName)' created but failed to assign groups.")
                                    }
                                    self.loadCustomAttributes()
                                }
                            }
                        } else {
                            Logger.info("Successfully created custom attribute '\(displayName)' with ID: \(scriptId)", category: .core, toUserDirectory: true)
                            self.showSuccess(message: "Custom attribute '\(displayName)' created successfully.")
                            self.loadCustomAttributes()
                        }
                    } else {
                        Logger.error("Failed to create custom attribute '\(displayName)'", category: .core, toUserDirectory: true)
                        self.showError(message: "Failed to create custom attribute '\(displayName)'. Please check your connection and try again.")
                    }
                }
            }
        } else {
            // Update existing script
            guard let scriptId = updatedCustomAttribute["id"] as? String else {
                showError(message: "Script ID missing. Cannot update script.")
                return
            }
            
            // Build update data with only changed properties
            var updateData: [String: Any] = [:]
            
            if let description = updatedCustomAttribute["description"] as? String {
                updateData["description"] = description
            }
            
            // Always update custom attribute content
            updateData["scriptContent"] = Data(scriptContent.utf8).base64EncodedString()
            
            XPCManager.shared.updateCustomAttributeShellScript(scriptId: scriptId, updatedData: updateData) { success in
                DispatchQueue.main.async {
                    if success == true {
                        // Handle group assignments if they exist
                        if let groupAssignments = updatedCustomAttribute["groupAssignments"] as? [[String: Any]] {
                            self.handleGroupAssignments(groupAssignments, for: scriptId) { assignmentSuccess in
                                DispatchQueue.main.async {
                                    if assignmentSuccess {
                                        Logger.info("Successfully updated custom attribute '\(displayName)' with assignments", category: .core, toUserDirectory: true)
                                        self.showSuccess(message: "Custom attribute '\(displayName)' updated successfully with group assignments.")
                                    } else {
                                        Logger.error("Custom attribute updated but failed to update assignments", category: .core, toUserDirectory: true)
                                        self.showError(message: "Custom attribute '\(displayName)' updated but failed to update group assignments.")
                                    }
                                    self.loadCustomAttributes()
                                }
                            }
                        } else {
                            Logger.info("Successfully updated custom attribute '\(displayName)'", category: .core, toUserDirectory: true)
                            self.showSuccess(message: "Custom attribute '\(displayName)' updated successfully.")
                            self.loadCustomAttributes()
                        }
                    } else {
                        Logger.error("Failed to update custom attribute '\(displayName)'", category: .core,toUserDirectory: true)
                        self.showError(message: "Failed to update custom attribute '\(displayName)'. Please check your connection and try again.")
                    }
                }
            }
        }
    }
    
    // MARK: - Double Click Table
    @objc func doubleClickTableRow(_ sender: AnyObject) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < allCustomAttributes.count else { return }
        let customAttribute = allCustomAttributes[selectedRow]
        openCustomAttributeEditor(for: customAttribute, isNew: false)
    }
    
    
    // MARK: - Action Buttons

    @IBAction func editSelectedScript(_ sender: Any) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < allCustomAttributes.count else {
            showError(message: "Please select a custom attribute to edit.")
            return
        }
        let customAttribute = allCustomAttributes[selectedRow]
        openCustomAttributeEditor(for: customAttribute, isNew: false)
    }
    
    @IBAction func deleteScriptFromIntune(_ sender: Any) {
        guard tableView.selectedRow >= 0, tableView.selectedRow < allCustomAttributes.count else {
            showError(message: "No custom attribute selected.")
            return
        }

        let customAttribute = allCustomAttributes[tableView.selectedRow]
        guard let customAttributeId = customAttribute["id"] as? String, !customAttributeId.isEmpty else {
            showError(message: "Selected custom attribute has no valid ID.")
            return
        }
        
        let customAttributeName = customAttribute["displayName"] as? String ?? "Unknown Script"

        let alert = NSAlert()
        alert.messageText = "Delete Custom Attribute"
        alert.informativeText = "Are you sure you want to permanently delete '\(customAttributeName)' from Intune?\n\n⚠️ This action cannot be undone and will remove all device assignments."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Disable buttons during deletion
            deleteButton.isEnabled = false
            editButton.isEnabled = false
            reportButton.isEnabled = false

            XPCManager.shared.deleteCustomAttributeShellScript(scriptId: customAttributeId) { success in
                DispatchQueue.main.async {
                    if success == true {
                        Logger.info("Successfully deleted custom attribute '\(customAttributeName)'", category: .core,toUserDirectory: true)
                        self.showSuccess(message: "Script '\(customAttributeName)' deleted successfully.")
                        self.loadCustomAttributes() // Refresh list after deletion
                    } else {
                        Logger.error("Failed to delete custom attribute '\(customAttributeName)'", category: .core,toUserDirectory: true)
                        self.showError(message: "Failed to delete custom attribute '\(customAttributeName)'. Please check your connection and try again.")
                        
                        // Re-enable buttons on failure
                        let selectedRow = self.tableView.selectedRow
                        let hasSelection = selectedRow >= 0 && selectedRow < self.allCustomAttributes.count
                        self.deleteButton.isEnabled = hasSelection
                        self.editButton.isEnabled = hasSelection
                        self.reportButton.isEnabled = hasSelection
                    }
                }
            }
        }
    }
    
    @IBAction func addCustomAttributeToIntune(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.message = "Select a Custom Attribute File"
        openPanel.allowedContentTypes = [.text, .shellScript, .sourceCode]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false

        openPanel.begin { response in
            if response == .OK, let fileURL = openPanel.url {
                do {
                    let scriptData = try Data(contentsOf: fileURL)
                    let scriptContent = scriptData.base64EncodedString()
                    let decodedString = String(data: scriptData, encoding: .utf8) ?? "Unable to decode custom attribute."

                    let scriptName = fileURL.deletingPathExtension().lastPathComponent

                    let newScript: [String: Any] = [
                        "displayName": scriptName,
                        "scriptContent": decodedString,
                        "fileName": "\(scriptName).sh",
                        "runAsAccount": "system",
                        "description": "",
                        "roleScopeTagIds": []
                    ]
                    
                    self.openCustomAttributeEditor(for: newScript, isNew: true)
                } catch {
                    self.showError(message: "Failed to load custom attribute file: \(error.localizedDescription)")
                }
            }
        }
    }

    @IBAction func importJamfExtensionAttributeClicked(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.message = "Select a Jamf Extension Attribute file to import."
        openPanel.allowedFileTypes = ["sh", "bash", "zsh", "xml"]
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false

        openPanel.begin { [weak self] response in
            guard response == .OK, let fileURL = openPanel.url, let self = self else { return }

            do {
                let fileExtension = fileURL.pathExtension.lowercased()

                var scriptContent = ""
                var scriptData: [String: Any] = [
                    "displayName": fileURL.deletingPathExtension().lastPathComponent,
                    "description": "",
                    "customAttributeName": "",
                    "fileName": fileURL.lastPathComponent,
                    "runAsAccount": "system",
                    "customAttributeType": "string",
                    "scriptContent": ""
                ]

                if fileExtension == "xml" {
                    // Parse XML for scriptContentsMac
                    let xmlString = try String(contentsOf: fileURL, encoding: .utf8)
                    if let parsedData = self.parseJamfXML(xmlString) {
                        scriptContent = parsedData.scriptContent
                        scriptData["displayName"] = parsedData.displayName
                        scriptData["description"] = parsedData.description
                        scriptData["customAttributeType"] = self.matchCustomAttributeType(parsedData.dataType)
                    }
                } else {
                    // Assume it's a regular script file
                    scriptContent = try String(contentsOf: fileURL, encoding: .utf8)
                }

                // Process script to convert Jamf echo format to Intune format
                scriptData["scriptContent"] = self.convertJamfScriptForIntune(scriptContent)

                // Open the editor with pre-filled data
                self.openCustomAttributeEditor(for: scriptData, isNew: true)

            } catch {
                self.showErrorAlert("Failed to import Jamf Extension Attribute", info: error.localizedDescription)
            }
        }
    }

    @IBAction func showDeviceReport(_ sender: NSButton) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < allCustomAttributes.count else {
            showError(message: "Please select a custom attribute to edit.")
            return
        }
        let customAttribute = allCustomAttributes[selectedRow]

        let storyboard = NSStoryboard(name: "CustomAttributes", bundle: nil)
        let reportVC = storyboard.instantiateController(withIdentifier: "CustomAttributeReportingViewController") as! CustomAttributeReportingViewController

        reportVC.configure(with: customAttribute)
        presentAsSheet(reportVC)
    }

    // MARK: - JAMF Import Handling

        private func parseJamfXML(_ xmlString: String) -> (scriptContent: String, displayName: String, description: String, dataType: String)? {
            guard let xmlData = xmlString.data(using: .utf8) else { return nil }

            do {
                let xmlDoc = try XMLDocument(data: xmlData, options: [])

                let scriptContent = (try? xmlDoc.nodes(forXPath: "//scriptContentsMac").first?.stringValue) ?? ""
                let displayName = (try? xmlDoc.nodes(forXPath: "//displayName").first?.stringValue) ?? "Imported Script"
                let description = (try? xmlDoc.nodes(forXPath: "//description").first?.stringValue) ?? ""
                let dataType = (try? xmlDoc.nodes(forXPath: "//dataType").first?.stringValue) ?? "string"

                // Decode HTML-escaped content like "&lt;" -> "<" if needed
                let cleanedScriptContent = scriptContent
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")

                return (cleanedScriptContent, displayName, description, dataType)
            } catch {
                Logger.error("XML Parsing Error: \(error)", category: .core, toUserDirectory: true)
                return nil
            }
        }
        
        private func convertJamfScriptForIntune(_ script: String) -> String {
            let lines = script.components(separatedBy: .newlines)
            var convertedLines: [String] = []

            let resultRegex = try! NSRegularExpression(pattern: #"echo\s*["']?<result>(.*?)</result>["']?"#, options: .caseInsensitive)

            for line in lines {
                if let match = resultRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
                    // Extract and clean value inside <result>...</result>
                    let nsLine = line as NSString
                    let extractedValue = nsLine.substring(with: match.range(at: 1))
                    convertedLines.append("echo \"\(extractedValue)\"") // Intune format
                } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("echo") {
                    // Comment out other echo statements
                    convertedLines.append("# \(line)")
                } else {
                    convertedLines.append(line) // Leave all other lines untouched
                }
            }

            return convertedLines.joined(separator: "\n")
        }
    
    private func matchCustomAttributeType(_ jamfType: String) -> String {
        switch jamfType.lowercased() {
            case "integer": return "Integer"
            case "date": return "Date"
            default: return "String"
        }
    }

    // MARK: - User Feedback
    
    private func showErrorAlert(_ message: String, info: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

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
