//
//  MainViewController+ContextMenu.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/11/25.
//

import Cocoa

/**
 * MainViewController+ContextMenu
 *
 * This extension implements the context menu functionality for table view rows.
 * It provides right-click actions for managing individual app automations and
 * integrates with Intune services for remote operations.
 *
 * ## Responsibilities:
 * - Build dynamic context menus based on app state
 * - Handle Intune integration actions (update, delete, run)
 * - Manage confirmation dialogs for destructive operations
 * - Provide status feedback through animated updates
 * - Support both ready and uploaded app states
 *
 * ## Menu Categories:
 * - **Table Actions**: Edit and delete local automation
 * - **Intune Actions**: Update metadata, scripts, assignments
 * - **Automation**: On-demand execution and management
 * - **Cleanup**: Remove automations from Intune tenant
 *
 * ## State-Based Menu Items:
 * Menu items are dynamically shown/hidden based on:
 * - Automation readiness (validation status)
 * - Upload status (whether app exists in Intune)
 * - Deployment type (affects script availability)
 */
// MARK: - Context Menu Delegate
extension MainViewController: NSMenuDelegate {
    
    /**
     * Dynamically builds the context menu based on the clicked table row.
     * 
     * This method is called by the system when a right-click occurs on the table.
     * It analyzes the selected app's state and builds an appropriate menu with
     * relevant actions for that specific app.
     * 
     * - Parameter menu: The menu to populate with items
     * 
     * ## Menu Structure:
     * 1. **Universal Actions**: New label, table row actions
     * 2. **Intune Actions**: Update operations (metadata, scripts, assignments)
     * 3. **Automation**: On-demand execution
     * 4. **Cleanup**: Remove from Intune
     * 
     * ## Dynamic Behavior:
     * - Menu items are shown/hidden based on automation readiness
     * - Script-related items only appear for PKG deployment type
     * - Actions require either ready status OR existing Intune upload
     * - Confirmation dialogs protect against accidental operations
     */
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Remove all items to rebuild dynamically
        menu.removeAllItems()
        
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0, clickedRow < filteredAppData.count else { return }
        
        // Get display name for menu
        let appItem = filteredAppData[clickedRow]
        let displayName = appItem.name
        
        // Check automation readiness
        let folderURL = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(appItem.label)_\(appItem.guid)")
        let isReady = AutomationCheck.validateFolder(at: folderURL.path)
        
        // Get metadata for deploymentType
        var metadata: Metadata!
        // Load metadata.json
        let labelMetaDataURL = folderURL
            .appendingPathComponent("metadata.json")
        do {
            let data = try Data(contentsOf: labelMetaDataURL)
            metadata = try JSONDecoder().decode(Metadata.self, from: data)
        } catch {
            Logger.info("Could not load metadata for context menu", category: .core, toUserDirectory: true)
        }
        
        let deploymentType = metadata.deploymentTypeTag
        var scriptsMenuIsVisible: Bool = false
        if deploymentType == 1 {
            scriptsMenuIsVisible = true
        }
        
        // Get Intune upload status
        let uploadStatusURL = folderURL.appendingPathComponent(".uploaded")
        let isUploaded: Bool = FileManager.default.fileExists(atPath: uploadStatusURL.path)
        
        menu.addItem(NSMenuItem(title: "New Label Item…", action: #selector(addRow(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Table Row Actions:", action: nil, keyEquivalent: ""))
        
        let editAutomationMenuItem = NSMenuItem(title: "Edit \(displayName) Automation Details…", action: #selector(editAppItem(_:)), keyEquivalent: "")
        editAutomationMenuItem.indentationLevel = 1
        menu.addItem(editAutomationMenuItem)
        
        let deleteAutomationMenuItem = NSMenuItem(title: "Delete \(displayName) Automation…", action: #selector(removeRow(_:)), keyEquivalent: "")
        deleteAutomationMenuItem.indentationLevel = 1
        menu.addItem(deleteAutomationMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        let intuneActionsMenuItem = NSMenuItem(title: "Intune Actions:", action: nil, keyEquivalent: "")
        intuneActionsMenuItem.isHidden = !isReady
        menu.addItem(intuneActionsMenuItem)
        
        
        let updateMetadataAutomationMenuItem = NSMenuItem(title: "Update Intune Metadata for \(displayName)…", action: #selector(updateIntuneMetadata(_:)), keyEquivalent: "")
        updateMetadataAutomationMenuItem.indentationLevel = 1
        updateMetadataAutomationMenuItem.isHidden = !isReady && !isUploaded
        menu.addItem(updateMetadataAutomationMenuItem)
        
        let updateScriptsAutomationMenuItem = NSMenuItem(title: "Update Intune Pre/Post Scripts for \(displayName)…", action: #selector(updateIntuneScripts(_:)), keyEquivalent: "")
        updateScriptsAutomationMenuItem.indentationLevel = 1
        updateScriptsAutomationMenuItem.isHidden = (!scriptsMenuIsVisible || !isReady) && (!scriptsMenuIsVisible || !isUploaded)
        menu.addItem(updateScriptsAutomationMenuItem)
        
        let updateAssignmentsAutomationMenuItem = NSMenuItem(title: "Update Intune Group Assignments for \(displayName)…", action: #selector(updateIntuneAssigments(_:)), keyEquivalent: "")
        updateAssignmentsAutomationMenuItem.indentationLevel = 1
        updateAssignmentsAutomationMenuItem.isHidden = !isReady && !isUploaded
        menu.addItem(updateAssignmentsAutomationMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        let runNowTitle = "Start an on-demand automation run for \(displayName)…"
        let runNowItem = NSMenuItem(title: runNowTitle, action: #selector(onDemandScriptAutomation(_:)), keyEquivalent: "")
        runNowItem.indentationLevel = 1
        runNowItem.isHidden = !isReady && !isUploaded
        menu.addItem(runNowItem)
        
        menu.addItem(NSMenuItem.separator())
        let deleteAutomationTitle = "Delete \(displayName) automation items from Intune…"
        let deleteAutomationItem = NSMenuItem(title: deleteAutomationTitle, action: #selector(deleteAutomationsFromIntune(_:)), keyEquivalent: "")
        deleteAutomationItem.indentationLevel = 1
        deleteAutomationItem.isHidden = !isReady && !isUploaded
        menu.addItem(deleteAutomationItem)
    }
    
    // MARK: - Intune Integration Actions
    
    /**
     * Updates the Intune metadata for the selected app automation.
     * 
     * This action synchronizes the local app configuration with the Intune tenant,
     * updating display name, description, and other metadata properties without
     * affecting the actual app package.
     * 
     * - Parameter sender: The menu item that triggered this action
     * 
     * ## Confirmation Process:
     * 1. Shows confirmation dialog with app details
     * 2. Calls XPC service to perform Intune API updates
     * 3. Displays animated status update with results
     * 4. Logs cancellation if user declines
     * 
     * ## XPC Operation:
     * Uses `updateAppMetaData()` which handles authentication and API calls
     * to update the app's metadata in the Intune tenant.
     */
    @objc func updateIntuneMetadata(_ sender: Any) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }
        
        // Get the name of the selected item for the confirmation dialog
        let itemToRemove = filteredAppData[selectedRow]
        let itemName = itemToRemove.name
        let itemLabel = itemToRemove.label
        let displayName = itemToRemove.name
        
        // Create a confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Confirm Update"
        alert.informativeText = "Are you sure you want to update the Intune metadata for '\(itemName) - \(itemLabel)'?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Cancel")
        
        // Show the dialog and handle the response
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            
            // Update metadata associated with the item
            let folderName = "\(itemToRemove.label)_\(itemToRemove.guid)"
            
            XPCManager.shared.updateAppMetaData(folderName, displayName) { updateResult in
                DispatchQueue.main.async {
                    if updateResult != nil {
                        self.animateStatusUpdate(updateResult ?? "No result provided.")
                    } else {
                        Logger.info("Failed to update label content", category: .core, toUserDirectory: true)
                    }
                }
            }
            
        } else {
            // User canceled update
            Logger.info("User canceled", category: .core, toUserDirectory: true)
        }
    }
    
    
    /**
     * Updates the Intune pre/post installation scripts for the selected app.
     * 
     * This action uploads or updates the installation and uninstallation scripts
     * associated with the app in the Intune tenant. Only available for PKG
     * deployment type apps.
     * 
     * - Parameter sender: The menu item that triggered this action
     * 
     * ## Script Types:
     * - **Pre-installation**: Scripts run before app installation
     * - **Post-installation**: Scripts run after successful installation
     * - **Detection**: Scripts to verify installation status
     * - **Uninstallation**: Scripts to remove the application
     * 
     * ## Availability:
     * This action is only visible and enabled for apps with deployment type 1 (PKG),
     * as script support is specific to this delivery method.
     */
    @objc func updateIntuneScripts(_ sender: Any) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }
        
        // Get the name of the selected item for the confirmation dialog
        let itemToRemove = filteredAppData[selectedRow]
        let itemName = itemToRemove.name
        let itemLabel = itemToRemove.label
        let displayName = itemToRemove.name
        
        // Create a confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Confirm Update"
        alert.informativeText = "Are you sure you want to update the Intune Pre/Post scripts for '\(itemName) - \(itemLabel)'?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Cancel")
        
        // Show the dialog and handle the response
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            
            // Update scripts associated with the item
            let folderName = "\(itemToRemove.label)_\(itemToRemove.guid)"
            
            XPCManager.shared.updateAppScripts(folderName, displayName) { updateResult in
                DispatchQueue.main.async {
                    if updateResult != nil {
                        self.animateStatusUpdate(updateResult ?? "No result provided.")
                    } else {
                        Logger.info("Failed to update label content", category: .core, toUserDirectory: true)
                    }
                }
            }
            
        } else {
            // User canceled update
            Logger.info("User canceled", category: .core, toUserDirectory: true)
        }
    }
    
    
    /**
     * Updates the Intune group assignments for the selected app.
     * 
     * This action modifies which Azure AD groups receive the app assignment,
     * controlling app deployment scope and targeting within the organization.
     * 
     * - Parameter sender: The menu item that triggered this action
     * 
     * ## Assignment Types:
     * - **Available**: App appears in Company Portal for user installation
     * - **Required**: App is automatically installed for assigned users/devices
     * - **Uninstall**: App is removed from assigned users/devices
     * 
     * ## Group Targeting:
     * - Supports both user and device group assignments
     * - Can include or exclude specific groups
     * - Honors existing group membership and policies
     */
    @objc func updateIntuneAssigments(_ sender: Any) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }
        
        // Get the name of the selected item for the confirmation dialog
        let itemToRemove = filteredAppData[selectedRow]
        let itemName = itemToRemove.name
        let itemLabel = itemToRemove.label
        let displayName = itemToRemove.name
        
        // Create a confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Confirm Update"
        alert.informativeText = "Are you sure you want to update the Intune group assignemnts for '\(itemName) - \(itemLabel)'?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Cancel")
        
        // Show the dialog and handle the response
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            
            // Update group assignments associated with the item
            let folderName = "\(itemToRemove.label)_\(itemToRemove.guid)"
            
            XPCManager.shared.updateAppAssigments(folderName, displayName) { updateResult in
                DispatchQueue.main.async {
                    if updateResult != nil {
                        self.animateStatusUpdate(updateResult ?? "No result provided.")
                    } else {
                        Logger.info("Failed to update label content", category: .core, toUserDirectory: true)
                    }
                }
            }
            
        } else {
            // User canceled update
            Logger.info("User canceled", category: .core, toUserDirectory: true)
        }
    }
    
    
    /**
     * Removes all automation items for the selected app from the Intune tenant.
     * 
     * This is a destructive operation that completely removes the app and all
     * associated resources (scripts, assignments, metadata) from Intune.
     * Requires double confirmation due to irreversible nature.
     * 
     * - Parameter sender: The menu item that triggered this action
     * 
     * ## Deletion Scope:
     * - Application package and metadata
     * - All associated scripts (install, uninstall, detection)
     * - Group assignments and targeting rules
     * - Detection rules and requirements
     * 
     * ## Safety Measures:
     * 1. Initial confirmation dialog
     * 2. Secondary "Are you absolutely sure?" confirmation
     * 3. Detailed logging of the operation
     * 4. Cannot be undone once executed
     * 
     * ## Post-Deletion:
     * The local automation configuration remains intact - only the Intune
     * tenant resources are removed. The app can be re-uploaded if needed.
     */
    @objc func deleteAutomationsFromIntune(_ sender: Any) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }
        
        // Get the name of the selected item for the confirmation dialog
        let itemToRemove = filteredAppData[selectedRow]
        let itemName = itemToRemove.name
        let itemLabel = itemToRemove.label
        let displayName = itemToRemove.name
        
        // Create a confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Confirm Full Delete"
        alert.informativeText = "Are you sure you want to delete all of the automation items associated with:\n'\(itemName) - \(itemLabel)'?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        // Show the dialog and handle the response
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            
            // Second confirmation before destructive delete
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Are you absolutely sure?"
            confirmAlert.informativeText = "This action cannot be undone. Do you really want to delete all Intune automations for '\(itemName) - \(itemLabel)'?"
            confirmAlert.alertStyle = .critical
            confirmAlert.addButton(withTitle: "Really Delete")
            confirmAlert.addButton(withTitle: "Cancel")
            let confirmResponse = confirmAlert.runModal()
            guard confirmResponse == .alertFirstButtonReturn else {
                Logger.info("User canceled full delete", category: .core, toUserDirectory: true)
                return
            }
            
            // Remove the automation items associated with the item
            let folderName = "\(itemToRemove.label)_\(itemToRemove.guid)"
            
            XPCManager.shared.deleteAutomationsFromIntune(folderName, displayName) { updateResult in
                DispatchQueue.main.async {
                    if updateResult != nil {
                        self.animateStatusUpdate(updateResult ?? "No result provided.")
                    } else {
                        Logger.info("Failed to update label content", category: .core, toUserDirectory: true)
                    }
                }
            }
            
        } else {
            // User canceled update
            Logger.info("User canceled", category: .core, toUserDirectory: true)
        }
    }
    
    
    /**
     * Triggers an on-demand automation run for the selected app.
     * 
     * This action immediately starts the automation process for a single app,
     * bypassing any scheduled execution. Useful for testing configurations or
     * urgent updates that can't wait for the next scheduled run.
     * 
     * - Parameter sender: The menu item that triggered this action
     * 
     * ## Automation Process:
     * 1. Downloads latest app version (if configured)
     * 2. Processes and packages the application
     * 3. Uploads to Intune tenant
     * 4. Updates metadata and assignments
     * 5. Configures detection rules
     * 
     * ## Execution Context:
     * - Runs immediately in background via XPC service
     * - Uses same logic as scheduled automation
     * - Results displayed via animated status updates
     * - Full logging of the operation
     * 
     * ## Prerequisites:
     * - App must pass automation readiness validation
     * - Valid Intune authentication must be configured
     * - Sufficient system resources for processing
     */
    @objc func onDemandScriptAutomation(_ sender: Any) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }
        
        // Get the name of the selected item for the confirmation dialog
        let itemToRemove = filteredAppData[selectedRow]
        let itemName = itemToRemove.name
        let itemLabel = itemToRemove.label
        let displayName = itemToRemove.name
        
        // Create a confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Confirm Run Automation"
        alert.informativeText = "Are you sure you want to run the Intune automation for '\(itemName) - \(itemLabel)'?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Run Automation")
        alert.addButton(withTitle: "Cancel")
        
        // Show the dialog and handle the response
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            
            // Update scripts associated with the item
            let folderName = "\(itemToRemove.label)_\(itemToRemove.guid)"
            
            XPCManager.shared.onDemandLabelAutomation(folderName, displayName) { updateResult in
                DispatchQueue.main.async {
                    if updateResult != nil {
                        self.animateStatusUpdate(updateResult ?? "No result provided.")
                    } else {
                        Logger.info("Failed to start automation", category: .core, toUserDirectory: true)
                    }
                }
            }
        } else {
            // User canceled update
            Logger.info("User canceled automation run", category: .core, toUserDirectory: true)
        }
    }
}
