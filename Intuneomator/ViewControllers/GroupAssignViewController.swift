//
//  GroupAssignViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/11/25.
//

import Foundation
import Cocoa

class GroupAssignViewController: NSViewController, Configurable, UnsavedChangesHandling, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet weak var groupAssignmentsTableView: NSTableView!
    
    
    @IBOutlet weak var assignRequiredGroupButton: NSButton!
    @IBOutlet weak var assignAvailableGroupButton: NSButton!
    @IBOutlet weak var assignUninstallGroupButton: NSButton!
    
    @IBOutlet weak var assignFilterButton: NSButton!
    
    @IBOutlet weak var statusLabel: NSTextField!
    
    var appData: AppInfo?
    var parentTabViewController: TabViewController?
    var hasUnsavedChanges = false
        
    var groupAssignments: [[String: Any]] = []
    var filterAssignments: [[String: Any]] = []

    // MARK: - Data Properties
    // Setup Virtual Intune Groups
    let virtualGroups: [[String: String]] = [
        ["displayName": "All Users", "id": "acacacac-9df4-4c7d-9d50-4ef0226f57a9", "description": "Assign to all users"],
        ["displayName": "All Devices", "id": "adadadad-808e-44e2-905a-0b7873a8a531", "description": "Assign to all devices"]
    ]
    
    private var assignmentsFilePath: URL?
    
    private let syncQueue = DispatchQueue(label: "com.intuneomator.groupAssign.syncQueue")
    
    // Create a reusable HelpPopover instance
    private let helpPopover = HelpPopover()
    
    // table typing
    var searchBuffer: String = ""
    var searchTimer: Timer?
    
    
    // MARK: - Configurable Protocol
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
    
    func markUnsavedChanges() {
        hasUnsavedChanges = true
        parentTabViewController?.updateSaveButtonState()
    }
    
    // MARK: - View Lifecycle
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
    
    override func viewDidAppear() {
        super.viewDidAppear()
        updateAssignFilterButtonVisibility()
        updateInstallTypeButtonVisibility()
    }
    
    
    private func updateAssignFilterButtonVisibility() {
        let appType = AppDataManager.shared.currentAppType
        assignFilterButton.isHidden = (appType != "macOSLobApp")
    }

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
    
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        
        let selectedRow = tableView.selectedRow
        let isEnabled = selectedRow >= 0
        assignFilterButton.isEnabled = isEnabled
    }
    
    
    // MARK: - Table Double Click
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
    func showAlert(withTitle title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    
}

extension GroupAssignViewController: TabSaveable {
    
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

extension GroupAssignViewController: GroupSelectViewControllerDelegate {
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


extension GroupAssignViewController: FilterSelectViewControllerDelegate {
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
