//
//  GroupAssignViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/11/25.
//

import Foundation
import Cocoa

/// View controller for managing Azure AD group assignments for application deployments
/// Handles configuration of Required, Available, and Uninstall assignments with support
/// for both virtual groups (All Users/All Devices) and real Azure AD security groups
///
/// **Key Features:**
/// - Manages three assignment types: Required, Available, and Uninstall
/// - Supports virtual groups (All Users, All Devices) and real Azure AD groups
/// - Integrates with Microsoft Intune assignment filters for advanced targeting
/// - Provides include/exclude assignment modes for granular control
/// - Tracks unsaved changes with visual feedback
/// - Validates assignment combinations to prevent conflicts
/// - Handles assignment persistence through XPC service
class GroupAssignViewController: NSViewController, Configurable, UnsavedChangesHandling, NSTableViewDelegate, NSTableViewDataSource {
    
    /// Table view displaying current group assignments (Required, Available, Uninstall).

    @IBOutlet weak var groupAssignmentsTableView: NSTableView!
    
    
    /// Button to assign Azure AD groups to the “Required” assignment type.
    @IBOutlet weak var assignRequiredGroupButton: NSButton!

    /// Button to assign Azure AD groups to the “Available” assignment type.
    @IBOutlet weak var assignAvailableGroupButton: NSButton!

    /// Button to assign Azure AD groups to the “Uninstall” assignment type.
    @IBOutlet weak var assignUninstallGroupButton: NSButton!

    /// Button to assign a filter to the selected group assignment (only for LOB apps).
    @IBOutlet weak var assignFilterButton: NSButton!

    /// Label displaying status or informational messages about group assignments.
    @IBOutlet weak var statusLabel: NSTextField!

    /// Holds the current application’s metadata (label, GUID, etc.) for which assignments apply.
    var appData: AppInfo?

    /// Reference to the parent TabViewController to notify about save button state.
    var parentTabViewController: TabViewController?

    /// Flag indicating whether group assignments have been modified and not yet saved.
    var hasUnsavedChanges = false
        
    /// Array of dictionaries representing current group assignments and their properties.
    var groupAssignments: [[String: Any]] = []

    /// Array of dictionaries representing filter assignments associated with groups.
    var filterAssignments: [[String: Any]] = []

    // MARK: - Data Properties
    /// Predefined virtual groups for Intune assignment: “All Users” and “All Devices”.
    let virtualGroups: [[String: String]] = [
        ["displayName": "All Users", "id": "acacacac-9df4-4c7d-9d50-4ef0226f57a9", "description": "Assign to all users"],
        ["displayName": "All Devices", "id": "adadadad-808e-44e2-905a-0b7873a8a531", "description": "Assign to all devices"]
    ]
    
    /// File URL for storing and loading the assignments.json file specific to this app.
    private var assignmentsFilePath: URL?
    
    /// Serial queue to synchronize access to groupAssignments for thread safety.
    private let syncQueue = DispatchQueue(label: "com.intuneomator.groupAssign.syncQueue")
    
    /// Reusable help popover for displaying contextual assistance.
    private let helpPopover = HelpPopover()
    
    /// Buffer to accumulate keyboard input for table row typing navigation.
    var searchBuffer: String = ""

    /// Timer to reset `searchBuffer` after a short delay between keystrokes.
    var searchTimer: Timer?
    
    
    // MARK: - Configurable Protocol
    /// Configures the view controller with `AppInfo` and parent TabViewController.
    /// - Parameters:
    ///   - data: Expected to be an `AppInfo` object containing label and GUID.
    ///   - parent: Reference to the parent TabViewController for save state updates.
    func configure(with data: Any, parent: TabViewController) {
        guard let appData = data as? AppInfo else {
//            print("Invalid data passed to GroupAssignViewController")
            return
        }
        self.appData = appData
        self.parentTabViewController = parent
        
        // Additional setup logic, if needed
        //        print("GroupAssignViewController configured with data: \(appData)")
    }
    
    /// Marks that the assignments have been changed, setting `hasUnsavedChanges` and
    /// notifying the parent to update the Save button.
    func markUnsavedChanges() {
        hasUnsavedChanges = true
        parentTabViewController?.updateSaveButtonState()
    }
    
    // MARK: - View Lifecycle
    /// Lifecycle callback invoked when the view loads.
    /// Sets up the assignments file path, table view delegate/data source, and loads existing assignments.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let appData = appData else {
//            print("App data is not set.")
            return
        }
        
        
        // Set up assignments file path
        assignmentsFilePath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(appData.label)_\(appData.guid)")
            .appendingPathComponent("assignments.json")
                
        // Set up table views
        groupAssignmentsTableView.delegate = self
        groupAssignmentsTableView.dataSource = self
        groupAssignmentsTableView.doubleAction = #selector(tableViewDoubleClicked(_:))
        
        // Load the current assignments, if any
        loadAssignments()
        
        // Load the table
        groupAssignmentsTableView.reloadData()
        
        
        updateAssignFilterButtonVisibility()
        updateInstallTypeButtonVisibility()
        
    }
    
    /// Lifecycle callback invoked after the view appears.
    /// Updates visibility of filter and uninstall buttons based on current app type.
    override func viewDidAppear() {
        super.viewDidAppear()
        updateAssignFilterButtonVisibility()
        updateInstallTypeButtonVisibility()
    }
    
    
    /// Toggles the filter assignment button visibility based on whether the app is a LOB app.
    private func updateAssignFilterButtonVisibility() {
        let appType = AppDataManager.shared.currentAppType
        assignFilterButton.isHidden = (appType != "macOSLobApp")
    }

    /// Toggles the uninstall assignment button visibility based on app type (LOB vs. PKG vs. DMG).
    private func updateInstallTypeButtonVisibility() {
        let appType = AppDataManager.shared.currentAppType
        switch appType {
        case "macOSLobApp":
            assignUninstallGroupButton.isHidden = false
        case "macOSPkgApp":
            assignUninstallGroupButton.isHidden = true
        case "macOSDmgApp":
            assignUninstallGroupButton.isHidden = false
        default:
            assignUninstallGroupButton.isHidden = true
        }
    }

    // MARK: - Actions
    /// Handles Cancel button: if there are unsaved changes, prompts the user before dismissing.
    /// - Parameter sender: The Cancel button that was clicked.
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        if hasUnsavedChanges {
            let alert = NSAlert()
            alert.messageText = "Unsaved Changes"
            alert.informativeText = "You have unsaved changes. Are you sure you want to discard them?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Discard Changes")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // User chose to discard changes
                self.dismiss(self)
            }
        } else {
            self.dismiss(self)
        }
    }
    
    
    // MARK: - Group Selection Actions
    /// Initiates group selection modal for Required, Available, or Uninstall assignments.
    /// Determines the assignment type based on which button was clicked.
    /// - Parameter sender: The assignment button clicked.
    @IBAction func selectGroupsForAssignment(_ sender: NSButton) {
        guard let appData = appData else {
//            print("Error: appData is missing.")
            return
        }
        
        // Determine the assignment type based on the button clicked
        var assignmentType: String
        let displayName = appData.name
        
        switch sender {
        case assignRequiredGroupButton:
            assignmentType = "Required"
        case assignAvailableGroupButton:
            assignmentType = "Available"
        case assignUninstallGroupButton:
            assignmentType = "Uninstall"
        default:
//            print("Unknown button clicked")
            return
        }
        
        // Get the groups already assigned for the current type
        let existingAssignments = groupAssignments.filter { ($0["assignmentType"] as? String) == assignmentType }
        
        // Get the groups assigned to other types that should be excluded
        let excludedGroups = groupAssignments.filter { ($0["assignmentType"] as? String) != assignmentType }
        
        
        // Present the modal for required group selection
        self.presentGroupSelectModal(displayName: displayName, assignmentType: assignmentType, existingAssignments: existingAssignments, excludedGroups: excludedGroups)
        
    }
    
    /// Presents the `GroupSelectViewController` as a modal sheet for selecting groups.
    /// - Parameters:
    ///   - displayName: The human-readable name of the app for display in the modal.
    ///   - assignmentType: One of "Required", "Available", or "Uninstall".
    ///   - existingAssignments: Assignments already set for this type to be pre-selected.
    ///   - excludedGroups: Assignments for other types to be excluded from selection.
    private func presentGroupSelectModal(displayName: String, assignmentType: String, existingAssignments: [[String: Any]] = [], excludedGroups: [[String: Any]] = []) {
        
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let groupSelectVC = storyboard.instantiateController(withIdentifier: "GroupSelectViewController") as! GroupSelectViewController
        
        // Pass data to the modal
        groupSelectVC.displayName = displayName
        groupSelectVC.assignmentType = assignmentType
        groupSelectVC.existingAssignments = existingAssignments
        groupSelectVC.excludedGroups = excludedGroups
        groupSelectVC.delegate = self
        
        // Show the modal
        presentAsSheet(groupSelectVC)
    }

    
    
    // MARK: - Filter Selection Actions
    /// Initiates filter selection modal for the selected group assignment.
    /// - Parameter sender: The Filter button that was clicked.
    @IBAction func selectFilterForAssignment(_ sender: NSButton) {
        guard let appData = appData else {
//            print("Error: appData is missing.")
            return
        }
        
        guard groupAssignmentsTableView.selectedRow >= 0 else {
            return
        }
        
        

        // Determine the assignment type based on the selected row
        let assignment = (groupAssignments[groupAssignmentsTableView.selectedRow]["displayName"])
        let displayName = appData.name
        
        
        // Present the modal for required group selection
        self.presentFilterSelectModal(displayName: displayName, assignment: assignment as! String)
        
    }

    /// Presents the `FilterSelectViewController` as a modal sheet for selecting a filter.
    /// - Parameters:
    ///   - displayName: The human-readable name of the app for display in the modal.
    ///   - assignment: The displayName of the selected group assignment to filter.
    private func presentFilterSelectModal(displayName: String, assignment: String) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let filterSelectVC = storyboard.instantiateController(withIdentifier: "FilterSelectViewController") as! FilterSelectViewController

        // Pass data to the modal
        filterSelectVC.displayName = displayName
        filterSelectVC.assignment = assignment
        filterSelectVC.delegate = self

        // Pass the current filter assigned to this group, if one exists
        if let current = groupAssignments.first(where: { ($0["displayName"] as? String) == assignment }),
           let filter = current["filter"] as? [String: Any] {
            filterSelectVC.existingFilter = filter
        }

        // Show the modal
        presentAsSheet(filterSelectVC)
    }
    
    
    
    // MARK: - Load data
    /// Loads group assignments from the `assignments.json` file if it exists.
    /// Parses the JSON array into `groupAssignments` and sorts them for display.
    private func loadAssignments() {
//        print("loading assignments...")
//        print("assignments file path: \(assignmentsFilePath?.path ?? "nil")")
        guard let filePath = assignmentsFilePath else { return }
        guard FileManager.default.fileExists(atPath: filePath.path) else { return }
        
        do {
            let data = try Data(contentsOf: filePath)
//            print("Data loaded successfully")
            // Parse the JSON as an array of dictionaries
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                groupAssignments = json
                sortGroupAssignments()
//                print("Loaded \(groupAssignments.count) group assignments")
//                print("Group assignments: \(groupAssignments)")
            } else {
//                print("JSON format is invalid")
            }
        } catch {
//            print("Failed to load assignments: \(error)")
        }
    }
    
    
    
    // MARK: - Help Buttons
    /// Displays help popover explaining differences between Required and Available assignments.
    /// - Parameter sender: The help button that was clicked.
    @IBAction func showHelpForAssignmentTypes(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: """
        Required:

        Means the app will automatically be installed on the devices that are members of the assigned groups.


        Available:

        Means the app will be accessible for users to install from the Company Portal, but they are not obligated to do so.
        """)

        let fullRange = NSRange(location: 0, length: helpText.length)

        // Define the base font and bold font
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)

        // Apply base font to entire string
        helpText.addAttribute(.font, value: font, range: fullRange)

        // Helper function to apply bold to keyword
        func bold(_ keyword: String) {
            let range = (helpText.string as NSString).range(of: keyword)
            if range.location != NSNotFound {
                helpText.addAttribute(.font, value: boldFont, range: range)
            }
        }

        // Apply bold to keywords
        bold("Required:")
        bold("Available:")
        
        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)

    }
    
    
    /// Displays help popover specifically for the Required assignment meaning.
    /// - Parameter sender: The help button that was clicked.
    @IBAction func showHelpForRequiredAssignment(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Required:\n\nMeans the app will automatically be installed on the selected devices.")
        
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))
        
        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }
    
    /// Displays help popover specifically for the Available assignment meaning.
    /// - Parameter sender: The help button that was clicked.
    @IBAction func showHelpForAvailableAssignment(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Available:\n\nMeans the app will be accessible for users to install from the Company Portal, but they are not obligated to do so.")
        
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))
        
        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }
    
    
    // MARK: - TableView Delegate & DataSource
    /// NSTableViewDataSource: Returns the number of rows for the group assignments table.
    func numberOfRows(in tableView: NSTableView) -> Int {
        return syncQueue.sync {
            switch tableView {
            case groupAssignmentsTableView:
                return groupAssignments.count
            default:
                return 0
            }
        }
    }
    
    /// NSTableViewDelegate/DataSource: Provides the view for each cell in the group assignments table.
    /// Configures columns: Assignment (with icon), Mode (Include/Exclude), Type (Required/Available/Uninstall), and Filter display.
    /// - Parameters:
    ///   - tableView: The table view requesting the cell.
    ///   - tableColumn: The table column for which a cell view is needed.
    ///   - row: The row index in `groupAssignments`.
    /// - Returns: A configured `NSTableCellView` or nil if no view is available.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let group = groupAssignments[row]
        
        if tableColumn?.identifier.rawValue == "AssignmentColumn" {
            let displayName = group["displayName"] as? String ?? ""
            let isVirtual = group["isVirtual"] as? Bool ?? false
            let emoji = isVirtual ? "🌐" : "👥"
            let text = "\(emoji) \(displayName)"
            
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("AssignmentCell"), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = text
                return cell
            }
        } else if tableColumn?.identifier.rawValue == "ModeColumn" {
            let mode = (group["mode"] as? String ?? "").capitalized
            // Set the text color based on the mode
            let cellColor: NSColor
            switch mode {
            case "Include":
                cellColor = NSColor.systemGreen
            case "Exclude":
                cellColor = NSColor.systemRed
            default:
                cellColor = NSColor.controlTextColor
            }
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ModeCell"), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = mode
                cell.textField?.textColor = cellColor
                return cell
            }
        } else if tableColumn?.identifier.rawValue == "TypeColumn" {
            let assignmentType = group["assignmentType"] as? String ?? ""
            // Set the text color based on the assignment type
            let cellColor: NSColor
            switch assignmentType {
            case "Required":
                cellColor = NSColor.systemBlue
            case "Available":
                cellColor = NSColor.systemYellow
            case "Uninstall":
                cellColor = NSColor.systemBrown
            default:
                cellColor = NSColor.controlTextColor
            }
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("TypeCell"), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = assignmentType
                cell.textField?.textColor = cellColor
                return cell
            }
        } else if tableColumn?.identifier.rawValue == "FilterColumn" {
                let filter = group["filter"] as? [String: Any]
                var filterDisplayName = "None"
                var cellColor: NSColor = NSColor.disabledControlTextColor

                if let filter = filter,
                   let mode = filter["mode"] as? String,
                   let name = filter["displayName"] as? String {
                    let emoji = (mode.lowercased() == "include") ? "✅" : (mode.lowercased() == "exclude") ? "❌" : ""
                    filterDisplayName = "\(emoji) \(name)"
                    cellColor = NSColor.controlTextColor
                }

                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("FilterCell"), owner: self) as? NSTableCellView {
                    cell.textField?.stringValue = filterDisplayName
                    cell.textField?.textColor = cellColor
                    return cell
                }
            }
            
        return nil
    }
    
    
    /// NSTableViewDelegate: Called when the user changes the selection in the table.
    /// Enables or disables the Assign Filter button based on whether a row is selected.
    /// - Parameter notification: Notification containing the table view.
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        
        let selectedRow = tableView.selectedRow
        let isEnabled = selectedRow >= 0
        assignFilterButton.isEnabled = isEnabled
    }
    
    
    // MARK: - Table Double Click
    /// NSTableViewDelegate: Handles double-click on a table row to re-open the group select modal for that assignment.
    /// - Parameter sender: The table view that was double-clicked.
    @objc func tableViewDoubleClicked(_ sender: Any) {
        let row = groupAssignmentsTableView.clickedRow
        guard row >= 0 && row < groupAssignments.count else { return }
        if let assignmentType = groupAssignments[row]["assignmentType"] as? String {
            // Gather existing and excluded assignments for the selected type:
            let existingForType = groupAssignments.filter { ($0["assignmentType"] as? String) == assignmentType }
            let excludedForType = groupAssignments.filter { ($0["assignmentType"] as? String) != assignmentType }
            // Use a display name from your appData if available; otherwise, use a default
            let displayName = appData?.name ?? "Title"
            // Open the group selection modal for the selected assignment type:
            presentGroupSelectModal(displayName: displayName, assignmentType: assignmentType, existingAssignments: existingForType, excludedGroups: excludedForType)
        }
    }
    
    
    // MARK: - Table Sorting
    /// Sorts `groupAssignments` first by assignment type order (Required, Available, Uninstall)
    /// then alphabetically by displayName for consistent display.
    func sortGroupAssignments() {
        let assignmentOrder = ["Required", "Available", "Uninstall"]
        groupAssignments.sort {
            let type1 = $0["assignmentType"] as? String ?? ""
            let type2 = $1["assignmentType"] as? String ?? ""
            let index1 = assignmentOrder.firstIndex(of: type1) ?? 999
            let index2 = assignmentOrder.firstIndex(of: type2) ?? 999
            if index1 != index2 {
                return index1 < index2
            } else {
                let name1 = $0["displayName"] as? String ?? ""
                let name2 = $1["displayName"] as? String ?? ""
                return name1.localizedCompare(name2) == .orderedAscending
            }
        }
    }
    
    
    // MARK: - Alert Helper
    /// Displays an NSAlert with a warning style and an OK button.
    /// - Parameters:
    ///   - title: The alert’s title text.
    ///   - message: The alert’s informative message text.
    func showAlert(withTitle title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    
}

/// Conforms to `TabSaveable` to save group assignment metadata via XPC service.
extension GroupAssignViewController: TabSaveable {
    
    /// Implements saving of `groupAssignments` by calling the XPCManager to persist data.
    /// - Uses `appData.label` and `appData.guid` to determine the file folder for assignments.
    func saveMetadata() {
        // Save logic for the Group Assignments tab
//        print("Saving data for GroupAssignmentsView...")
        
        guard let appData = appData else {
//            print("No app data available to save assignments.")
            return
        }
        
        // Define the file path to save the assignments
        let labelFolder = "\(appData.label)_\(appData.guid)"
        
        XPCManager.shared.assignGroupsToLabel(groupAssignments, labelFolder) { reply in
            if let reply = reply, reply {
                DispatchQueue.main.async {
                    
                    // Reset the unsaved changes flag
                    self.hasUnsavedChanges = false
                    
                    // Notify the TabViewController to update the Save button state
                    self.parentTabViewController?.updateSaveButtonState()
                    
//                    print("Group assignments saved successfully.")
                }
            } else {
//                print("Failed to save group assignments.")
            }
        }
    }
}

/// Conformance to `GroupSelectViewControllerDelegate` to receive selected groups.
extension GroupAssignViewController: GroupSelectViewControllerDelegate {
    /// Callback when user finishes selecting groups in the group picker modal.
    /// Replaces existing assignments for the given `type` with the new `groups`, then reloads the table and marks unsaved changes.
    /// - Parameters:
    ///   - controller: The `GroupSelectViewController` instance.
    ///   - groups: Array of selected group dictionaries.
    ///   - type: The assignment type (Required, Available, Uninstall).
    func groupSelectViewController(_ controller: GroupSelectViewController, didSelectGroups groups: [[String: Any]], forAssignmentType type: String) {
        // Remove any existing assignments for this type
        groupAssignments = groupAssignments.filter { ($0["assignmentType"] as? String) != type }
        
        // Append new assignments with the assignmentType added
        for var group in groups {
            group["assignmentType"] = type
            groupAssignments.append(group)
        }
        
        // Reload the table view on the main thread and mark unsaved changes
        DispatchQueue.main.async {
            self.groupAssignmentsTableView.reloadData()
            self.markUnsavedChanges()
        }
    }
}

/// Conformance to `FilterSelectViewControllerDelegate` to receive selected filters.
extension GroupAssignViewController: FilterSelectViewControllerDelegate {
    /// Callback when user finishes selecting a filter for a specific group.
    /// Updates the `filter` field in the matching `groupAssignments` entry and reloads the table.
    /// - Parameters:
    ///   - controller: The `FilterSelectViewController` instance.
    ///   - filter: Dictionary representing the chosen filter.
    ///   - group: The displayName of the group for which the filter was selected.
    func filterSelectViewController(_ controller: FilterSelectViewController, didSelectFilter filter: [String: Any], forGroup group: String) {
        
        // Find the index of the group assignment matching the type
        if let index = groupAssignments.firstIndex(where: { ($0["displayName"] as? String) == group }) {
            // Update the assignment with the filter dictionary
            groupAssignments[index]["filter"] = filter
        }

        // Reload the table view on the main thread and mark unsaved changes
        DispatchQueue.main.async {
            self.groupAssignmentsTableView.reloadData()
            self.markUnsavedChanges()
        }
    }
}
