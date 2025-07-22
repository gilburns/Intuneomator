
//
//  GroupAssignmentViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/22/25.
//

import Foundation
import Cocoa

/// View controller for managing Azure AD group assignments for deployments
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
class GroupAssignmentViewController: NSViewController, Configurable, UnsavedChangesHandling, NSTableViewDelegate, NSTableViewDataSource, TabbedSheetChildProtocol {
    
    /// Table view displaying current group assignments (Required, Available, Uninstall).

    @IBOutlet weak var groupAssignmentsTableView: NSTableView!
    
    /// Button to assign Entra ID groups to the “Required” assignment type.
    @IBOutlet weak var assignRequiredGroupButton: NSButton!

    /// Button to assign Entra ID groups to the “Available” assignment type.
    @IBOutlet weak var assignAvailableGroupButton: NSButton!

    /// Button to assign Azure AD groups to the “Uninstall” assignment type.
    @IBOutlet weak var assignUninstallGroupButton: NSButton!

    /// Button to assign a filter to the selected group assignment (only for LOB apps).
    @IBOutlet weak var assignFilterButton: NSButton!
    
    /// Column to show group assignment mode
    @IBOutlet weak var modeColumn: NSTableColumn!

    /// Column to show group assignment type
    @IBOutlet weak var typeColumn: NSTableColumn!

    /// Column to show group assignment filter
    @IBOutlet weak var filterColumn: NSTableColumn!

    /// Label displaying status or informational messages about group assignments.
    @IBOutlet weak var statusLabel: NSTextField!

    /// Holds the current assignments.
    var currentAssignments: [[String: Any]]? = []

    /// Reference to the parent TabViewController to notify about save button state.
    var parentTabViewController: TabViewController?
    
    /// Reference to the parent TabbedSheetViewController to notify about save button state (for sheet context).
    var parentTabbedSheetViewController: TabbedSheetViewController?

    /// Flag indicating whether group assignments have been modified and not yet saved.
    var hasUnsavedChanges = false
    
    /// Original assignments data for change tracking
    var originalAssignments: [[String: Any]] = []
        
    /// Array of dictionaries representing current group assignments and their properties.
    var groupAssignments: [[String: Any]] = []
    
    /// Stores the initial data payload containing @odata.type and other metadata
    var initialData: [String: Any]?

    /// Array of dictionaries representing filter assignments associated with groups.
    var filterAssignments: [[String: Any]] = []

    // MARK: - Data Properties
    /// Predefined virtual groups for Intune assignment: “All Users” and “All Devices”.
    let virtualGroups: [[String: String]] = [
        ["displayName": "All Users", "id": "acacacac-9df4-4c7d-9d50-4ef0226f57a9", "description": "Assign to all users"],
        ["displayName": "All Devices", "id": "adadadad-808e-44e2-905a-0b7873a8a531", "description": "Assign to all devices"]
    ]
        
    /// Serial queue to synchronize access to groupAssignments for thread safety.
    private let syncQueue = DispatchQueue(label: "com.intuneomator.groupAssign.syncQueue")
    
    /// Reusable help popover for displaying contextual assistance.
    private let helpPopover = HelpPopover()
    
    /// Buffer to accumulate keyboard input for table row typing navigation.
    var searchBuffer: String = ""

    /// Timer to reset `searchBuffer` after a short delay between keystrokes.
    var searchTimer: Timer?
    
    
    // MARK: - Configurable Protocol
    /// Configures the view controller with data and parent TabViewController.
    /// - Parameters:
    ///   - data: Expected to be an currentAssignment object.
    ///   - parent: Reference to the parent TabViewController for save state updates.
    func configure(with data: Any, parent: TabViewController) {
        print("Configuring GroupAssignmentViewController")
        guard let currentAssignments = data as? [[String: Any]] else {
            return
        }
        self.currentAssignments = currentAssignments
        self.parentTabViewController = parent
        
        // Additional setup logic, if needed
    }
    
    /// Stores the original assignments for change comparison
    private func storeOriginalAssignments() {
        // Deep copy the current assignments
        originalAssignments = groupAssignments.map { assignment in
            var copy: [String: Any] = [:]
            for (key, value) in assignment {
                copy[key] = value
            }
            return copy
        }
    }
    
    /// Normalizes assignment data to ensure virtual groups have correct properties
    /// - Parameter assignments: Raw assignment data
    /// - Returns: Normalized assignment data with proper virtual group formatting
    private func normalizeAssignmentData(_ assignments: [[String: Any]]) -> [[String: Any]] {
        return assignments.map { assignment in
            var normalizedAssignment = assignment
            
            // Check if this assignment needs virtual group normalization
            if let groupId = assignment["groupId"] as? String {
                // Check for virtual group GUIDs and ensure proper formatting
                if groupId == "adadadad-808e-44e2-905a-0b7873a8a531" {
                    // All Devices virtual group
                    normalizedAssignment["displayName"] = "All Devices"
                    normalizedAssignment["isVirtual"] = true
                    // Preserve existing mode, but don't default assignmentType 
                    if normalizedAssignment["mode"] == nil {
                        normalizedAssignment["mode"] = "include"
                    }
                    // Don't default assignmentType - it should be explicitly set by the calling code
                } else if groupId == "acacacac-9df4-4c7d-9d50-4ef0226f57a9" {
                    // All Users virtual group
                    normalizedAssignment["displayName"] = "All Users"
                    normalizedAssignment["isVirtual"] = true
                    // Preserve existing mode, but don't default assignmentType 
                    if normalizedAssignment["mode"] == nil {
                        normalizedAssignment["mode"] = "include"
                    }
                    // Don't default assignmentType - it should be explicitly set by the calling code
                } else {
                    // Regular group - ensure isVirtual is false
                    if normalizedAssignment["isVirtual"] == nil {
                        normalizedAssignment["isVirtual"] = false
                    }
                    // Set defaults for mode if missing, but preserve existing assignmentType
                    if normalizedAssignment["mode"] == nil {
                        normalizedAssignment["mode"] = "include"
                    }
                    // Don't default assignmentType - it should be explicitly set by the calling code
                }
            }
            
            return normalizedAssignment
        }
    }
    
    /// Compares current assignments with original data and updates change tracking
    private func trackChanges() {
        // Compare assignment arrays
        let assignmentsChanged = !areAssignmentsEqual(originalAssignments, groupAssignments)
        
        if assignmentsChanged != hasUnsavedChanges {
            hasUnsavedChanges = assignmentsChanged
            updateTableViewAppearance()
            
            // Notify the appropriate parent controller
            if let parent = parentTabbedSheetViewController {
                parent.updateSaveButtonState()
            } else {
                parentTabViewController?.updateSaveButtonState()
            }
        }
    }
    
    /// Compares two assignment arrays for equality
    private func areAssignmentsEqual(_ assignments1: [[String: Any]], _ assignments2: [[String: Any]]) -> Bool {
        guard assignments1.count == assignments2.count else { return false }
        
        // Create sorted copies for comparison
        let sorted1 = assignments1.sorted { a1, a2 in
            let id1 = (a1["groupId"] as? String ?? "") + (a1["assignmentType"] as? String ?? "")
            let id2 = (a2["groupId"] as? String ?? "") + (a2["assignmentType"] as? String ?? "")
            return id1 < id2
        }
        
        let sorted2 = assignments2.sorted { a1, a2 in
            let id1 = (a1["groupId"] as? String ?? "") + (a1["assignmentType"] as? String ?? "")
            let id2 = (a2["groupId"] as? String ?? "") + (a2["assignmentType"] as? String ?? "")
            return id1 < id2
        }
        
        for (index, assignment1) in sorted1.enumerated() {
            let assignment2 = sorted2[index]
            
            // Compare key fields
            let keys = ["groupId", "displayName", "assignmentType", "mode", "isVirtual"]
            for key in keys {
                let value1 = assignment1[key] as? String ?? ""
                let value2 = assignment2[key] as? String ?? ""
                if value1 != value2 {
                    return false
                }
            }
            
            // Compare boolean values
            if let bool1 = assignment1["isVirtual"] as? Bool,
               let bool2 = assignment2["isVirtual"] as? Bool,
               bool1 != bool2 {
                return false
            }
            
            // Compare filter values
            if !areFiltersEqual(assignment1["filter"] as? [String: Any], assignment2["filter"] as? [String: Any]) {
                return false
            }
        }
        
        return true
    }
    
    /// Compares two filter dictionaries for equality
    /// - Parameters:
    ///   - filter1: First filter dictionary (can be nil)
    ///   - filter2: Second filter dictionary (can be nil)
    /// - Returns: True if both filters are equivalent
    private func areFiltersEqual(_ filter1: [String: Any]?, _ filter2: [String: Any]?) -> Bool {
        // Handle nil cases
        if filter1 == nil && filter2 == nil {
            return true
        }
        
        // Handle empty dictionary cases (which are equivalent to nil for our purposes)
        let isEmpty1 = filter1 == nil || filter1!.isEmpty
        let isEmpty2 = filter2 == nil || filter2!.isEmpty
        
        if isEmpty1 && isEmpty2 {
            return true
        }
        
        if isEmpty1 != isEmpty2 {
            return false
        }
        
        // Both are non-empty, compare the actual filter contents
        guard let f1 = filter1, let f2 = filter2 else {
            return false
        }
        
        // Compare filter ID
        let id1 = f1["id"] as? String ?? ""
        let id2 = f2["id"] as? String ?? ""
        if id1 != id2 {
            return false
        }
        
        // Compare filter mode
        let mode1 = f1["mode"] as? String ?? ""
        let mode2 = f2["mode"] as? String ?? ""
        if mode1 != mode2 {
            return false
        }
        
        // Compare display name (optional, but good for completeness)
        let name1 = f1["displayName"] as? String ?? ""
        let name2 = f2["displayName"] as? String ?? ""
        if name1 != name2 {
            return false
        }
        
        return true
    }
    
    /// Updates the table view appearance based on unsaved changes
    private func updateTableViewAppearance() {
        if hasUnsavedChanges {
            // Highlight table view with subtle background change
            groupAssignmentsTableView.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.1)
        } else {
            // Restore normal appearance
            groupAssignmentsTableView.backgroundColor = NSColor.controlBackgroundColor
        }
    }
    
    /// Marks that the assignments have been changed, setting `hasUnsavedChanges` and
    /// notifying the parent to update the Save button.
    func markUnsavedChanges() {
        trackChanges()
    }
    
    // MARK: - View Lifecycle
    /// Lifecycle callback invoked when the view loads.
    /// Sets up the assignments file path, table view delegate/data source, and loads existing assignments.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let currentAssignments = currentAssignments else {
            return
        }
        
        // Set up table views
        groupAssignmentsTableView.delegate = self
        groupAssignmentsTableView.dataSource = self
        groupAssignmentsTableView.doubleAction = #selector(tableViewDoubleClicked(_:))
        
        // Load the table
        groupAssignmentsTableView.reloadData()
        
        
        updateGUIElementVisibility()

    }
    
    /// Lifecycle callback invoked after the view appears.
    /// Updates visibility of filter and uninstall buttons based on current app type.
    override func viewDidAppear() {
        super.viewDidAppear()
        updateGUIElementVisibility()
    }
    
    /// Toggles the install assignment buttons and filter assignment button visibility based on @odata.type from the payload.
    private func updateGUIElementVisibility() {
        // Get the @odata.type from the initial data payload
        guard let initialData = self.initialData,
              let odataType = initialData["@odata.type"] as? String else {
            // Fallback to hiding uninstall and available buttons if no @odata.type is found
            assignUninstallGroupButton.isHidden = true
            assignAvailableGroupButton.isHidden = true
            
            assignFilterButton.isHidden = true
            
            modeColumn.isHidden = false
            typeColumn.isHidden = true
            filterColumn.isHidden = true
            return
        }
        
        switch odataType {
        case "#microsoft.graph.macOSLobApp":
            assignUninstallGroupButton.isHidden = false
            assignAvailableGroupButton.isHidden = false
            
            assignFilterButton.isHidden = false
            
            modeColumn.isHidden = false
            typeColumn.isHidden = false
            filterColumn.isHidden = false
        case "#microsoft.graph.macOSPkgApp":
            assignUninstallGroupButton.isHidden = true
            assignAvailableGroupButton.isHidden = false
            
            assignFilterButton.isHidden = true
            
            modeColumn.isHidden = false
            typeColumn.isHidden = false
            filterColumn.isHidden = true
        case "#microsoft.graph.macOSDmgApp":
            assignUninstallGroupButton.isHidden = false
            assignAvailableGroupButton.isHidden = false
            
            assignFilterButton.isHidden = true
            
            modeColumn.isHidden = false
            typeColumn.isHidden = false
            filterColumn.isHidden = true
        case "#microsoft.graph.deviceManagementScript":
            assignUninstallGroupButton.isHidden = true
            assignAvailableGroupButton.isHidden = true
            
            assignFilterButton.isHidden = true
            
            modeColumn.isHidden = false
            typeColumn.isHidden = true
            filterColumn.isHidden = true
        case "#microsoft.graph.deviceManagementConfigurationPolicy":
            assignUninstallGroupButton.isHidden = true
            assignAvailableGroupButton.isHidden = true
            
            assignFilterButton.isHidden = true
            
            modeColumn.isHidden = false
            typeColumn.isHidden = true
            filterColumn.isHidden = true
        case "#microsoft.graph.macOSWebClip":
            assignUninstallGroupButton.isHidden = false
            assignAvailableGroupButton.isHidden = false
            
            assignFilterButton.isHidden = false
            
            modeColumn.isHidden = false
            typeColumn.isHidden = false
            filterColumn.isHidden = false
        default:
            assignUninstallGroupButton.isHidden = true
            assignAvailableGroupButton.isHidden = true
            
            assignFilterButton.isHidden = true
            
            modeColumn.isHidden = false
            typeColumn.isHidden = true
            filterColumn.isHidden = true
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
        guard let currentAssignments = currentAssignments else {
            return
        }
        
        // Determine the assignment type based on the button clicked
        var assignmentType: String
//        let displayName = currentAssignments["displayName"] as! String
        
        switch sender {
        case assignRequiredGroupButton:
            assignmentType = "Required"
        case assignAvailableGroupButton:
            assignmentType = "Available"
        case assignUninstallGroupButton:
            assignmentType = "Uninstall"
        default:
            return
        }
        
        // Get the groups already assigned for the current type
        let existingAssignments = groupAssignments.filter { ($0["assignmentType"] as? String) == assignmentType }
        
        // Get the groups assigned to other types that should be excluded
        let excludedGroups = groupAssignments.filter { ($0["assignmentType"] as? String) != assignmentType }
        
        let displayName = ""
        
        // Present the modal for required group selection
        self.presentGroupSelectionModal(displayName: displayName, assignmentType: assignmentType, existingAssignments: existingAssignments, excludedGroups: excludedGroups)
        
    }
    
    /// Presents the `GroupSelectionViewController` as a modal sheet for selecting groups.
    /// - Parameters:
    ///   - displayName: The human-readable name of the app for display in the modal.
    ///   - assignmentType: One of "Required", "Available", or "Uninstall".
    ///   - existingAssignments: Assignments already set for this type to be pre-selected.
    ///   - excludedGroups: Assignments for other types to be excluded from selection.
    private func presentGroupSelectionModal(displayName: String, assignmentType: String, existingAssignments: [[String: Any]] = [], excludedGroups: [[String: Any]] = []) {
        
        let storyboard = NSStoryboard(name: "GroupAssignment", bundle: nil)
        let groupSelectVC = storyboard.instantiateController(withIdentifier: "GroupSelectionViewController") as! GroupSelectionViewController
        
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
        guard groupAssignmentsTableView.selectedRow >= 0 else {
            return
        }
        
        // Get the selected assignment and extract its displayName
        let selectedAssignment = groupAssignments[groupAssignmentsTableView.selectedRow]
        let assignmentDisplayName = selectedAssignment["displayName"] as? String ?? ""
        let displayName = ""
        
        // Present the modal for filter selection, passing the selected assignment directly
        self.presentFilterSelectionModal(displayName: displayName, assignment: assignmentDisplayName, selectedAssignment: selectedAssignment)
        
    }

    /// Presents the `FilterSelectViewController` as a modal sheet for selecting a filter.
    /// - Parameters:
    ///   - displayName: The human-readable name of the app for display in the modal.
    ///   - assignment: The displayName of the selected group assignment to filter.
    ///   - selectedAssignment: The complete assignment object that was selected.

    private func presentFilterSelectionModal(displayName: String, assignment: String, selectedAssignment: [String: Any]) {
        let storyboard = NSStoryboard(name: "GroupAssignment", bundle: nil)
        let filterSelectVC = storyboard.instantiateController(withIdentifier: "FilterSelectionViewController") as! FilterSelectionViewController

        // Pass data to the modal
        filterSelectVC.displayName = displayName
        filterSelectVC.assignment = assignment
        filterSelectVC.delegate = self

        // Pass the current filter assigned to this group, if one exists
        // Use the selected assignment directly instead of searching for it
        if let filter = selectedAssignment["filter"] as? [String: Any] {
            filterSelectVC.existingFilter = filter
            Logger.info("🔎 Found existing filter for assignment: \(filter)", toUserDirectory: true)
        } else {
            Logger.info("ℹ️ No existing filter found for assignment: \(assignment)", toUserDirectory: true)
        }

        // Show the modal
        presentAsSheet(filterSelectVC)
    }
    
    // MARK: - Help Buttons
    /// Displays help popover explaining differences between Required and Available assignments.
    /// - Parameter sender: The help button that was clicked.
    @IBAction func showHelpForAssignmentTypes(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: """
        Required:

        Means the item will automatically be processed on the devices that are members of the assigned groups.

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
            let displayName = ""
            // Open the group selection modal for the selected assignment type:
            presentGroupSelectionModal(displayName: displayName, assignmentType: assignmentType, existingAssignments: existingForType, excludedGroups: excludedForType)
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
extension GroupAssignmentViewController: TabSaveable {
    
    /// Implements saving of `groupAssignments` by calling the XPCManager to persist data.
    /// - Uses `appData.label` and `appData.guid` to determine the file folder for assignments.
    func saveMetadata() {
//        // Save logic for the Group Assignments tab
//
//        guard let appData = appData else {
//            return
//        }
//
//        // Define the file path to save the assignments
//        let labelFolder = "\(appData.label)_\(appData.guid)"
//
//        XPCManager.shared.assignGroupsToLabel(groupAssignments, labelFolder) { reply in
//            if let reply = reply, reply {
//                DispatchQueue.main.async {
//
//                    // Reset the unsaved changes flag
//                    self.hasUnsavedChanges = false
//
//                    // Notify the TabViewController to update the Save button state
//                    self.parentTabViewController?.updateSaveButtonState()
//
//                }
//            } else {
//            }
//        }
    }
}

/// Conformance to `GroupSelectionViewControllerDelegate` to receive selected groups.
extension GroupAssignmentViewController: GroupSelectionViewControllerDelegate {
    /// Callback when user finishes selecting groups in the group picker modal.
    /// Replaces existing assignments for the given `type` with the new `groups`, then reloads the table and marks unsaved changes.
    /// - Parameters:
    ///   - controller: The `GroupSelectViewController` instance.
    ///   - groups: Array of selected group dictionaries.
    ///   - type: The assignment type (Required, Available, Uninstall).
    func groupSelectionViewController(_ controller: GroupSelectionViewController, didSelectGroups groups: [[String: Any]], forAssignmentType type: String) {
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
extension GroupAssignmentViewController: FilterSelectionViewControllerDelegate {
    /// Callback when user finishes selecting a filter for a specific group.
    /// Updates the `filter` field in the matching `groupAssignments` entry and reloads the table.
    /// - Parameters:
    ///   - controller: The `FilterSelectViewController` instance.
    ///   - filter: Dictionary representing the chosen filter.
    ///   - group: The displayName of the group for which the filter was selected.
    func filterSelectionViewController(_ controller: FilterSelectionViewController, didSelectFilter filter: [String: Any], forGroup group: String) {
        
        // Find the index of the group assignment matching the type
        if let index = groupAssignments.firstIndex(where: { ($0["displayName"] as? String) == group }) {
            let oldFilter = groupAssignments[index]["filter"] as? [String: Any]
            
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

// MARK: - TabbedSheetChildProtocol

extension GroupAssignmentViewController {
    
    /// Cleans up filters from assignments to prevent API issues
    /// Ensures that empty filter dictionaries are removed completely
    /// - Parameter assignments: Array of group assignments to clean
    /// - Returns: Cleaned assignments array with proper filter handling
    private func cleanupFiltersFromAssignments(_ assignments: [[String: Any]]) -> [[String: Any]] {
        return assignments.map { assignment in
            var cleanedAssignment = assignment
            
            // Check if there's a filter field
            if let filter = assignment["filter"] as? [String: Any] {
                // If the filter is empty or missing required fields, remove it completely
                let filterId = filter["id"] as? String ?? ""
                let filterMode = filter["mode"] as? String ?? ""
                
                if filterId.isEmpty || filterMode.isEmpty {
                    // Remove the filter completely if it's empty or incomplete
                    cleanedAssignment.removeValue(forKey: "filter")
                } else {
                    // Keep the filter as-is if it has valid data
                }
            }
            
            return cleanedAssignment
        }
    }
    
    func getDataForSave() -> [String: Any]? {
        // Clean up any remaining filters from assignments that might cause API issues
        let cleanedAssignments = cleanupFiltersFromAssignments(groupAssignments)
        
        // Return the current group assignments
        return ["groupAssignments": cleanedAssignments]
    }
    
    func setInitialData(_ data: [String: Any]) {
        // Store the initial data payload for @odata.type access
        self.initialData = data
        
        // Load existing group assignments if available
        if let assignments = data["groupAssignments"] as? [[String: Any]] {
            // Validate and normalize assignment data to ensure virtual groups are properly formatted
            self.groupAssignments = normalizeAssignmentData(assignments)
        } else {
            self.groupAssignments = []
        }
        
        // Store original assignments for change tracking
        storeOriginalAssignments()
        
        // Extract script ID for potential assignment operations
        if let scriptId = data["id"] as? String {
            // Store script ID for future assignment operations
            // Note: This would be used when implementing actual assignment calls
        }
        
        // Initialize change tracking state
        hasUnsavedChanges = false
        
        // If view is already loaded, reload the table and update appearance
        if isViewLoaded {
            DispatchQueue.main.async {
                self.groupAssignmentsTableView.reloadData()
                self.updateTableViewAppearance()
                self.updateGUIElementVisibility()

            }
        }
    }
    
    func updateFromOtherTabs(_ combinedData: [String: Any]) {
        // Update display name in status if script name changed
        if let scriptName = combinedData["displayName"] as? String {
            DispatchQueue.main.async {
                self.statusLabel.stringValue = "Groups for: \(scriptName)"
            }
        }
    }
    
    func validateData() -> String? {
        // Groups are optional for shell scripts, so no validation required
        // Could add validation here if needed (e.g., prevent conflicting assignments)
        return nil
    }
}
