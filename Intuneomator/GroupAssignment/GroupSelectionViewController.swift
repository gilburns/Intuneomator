//
//  GroupSelectionViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/25/25.
//

import Foundation
import Cocoa

protocol GroupSelectionViewControllerDelegate: AnyObject {
    func groupSelectionViewController(_ controller: GroupSelectionViewController, didSelectGroups groups: [[String: Any]], forAssignmentType type: String)
}

/// Sheet view controller for selecting Azure AD groups for application assignments
/// Provides interface for selecting groups with include/exclude modes while preventing
/// conflicts with existing assignments across different deployment types
/// 
/// **Key Features:**
/// - Displays Azure AD security groups with search functionality
/// - Supports virtual groups (All Users, All Devices) with mutual exclusion
/// - Implements include/exclude assignment modes for precise targeting
/// - Prevents conflicts by disabling groups assigned to other assignment types
/// - Maintains assignment type restrictions (e.g., All Devices not available for Available assignments)
/// - Handles existing assignment editing with proper state restoration
/// - Provides clear visual feedback for group selection status
class GroupSelectionViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    weak var delegate: GroupSelectionViewControllerDelegate?
    var groupSelectionModes: [String: String] = [:] // key: group id, value: “include” or “exclude”
    var userHasToggledVirtualCheckbox = false

    
    // MARK: - Outlets
    
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var allDevicesButton: NSButton!
    @IBOutlet weak var allUsersButton: NSButton!
    
    @IBOutlet weak var saveButton: NSButton!
    
    @IBOutlet weak var searchField: NSSearchField!
    
    @IBOutlet weak var clearAllButton: NSButton!
    
    @IBOutlet weak var groupCountLabel: NSTextField!

    
    // Input data
    var displayName: String = ""
    var assignmentType: String = ""
    var existingAssignments: [[String : Any]] = []
    var excludedGroups: [[String : Any]] = []
    
    // Full list of all groups fetched from Entra
    var allGroups: [[String: Any]] = []
    // This will hold the filtered groups based on search criteria
    var filteredGroups: [[String: Any]] = []
        
    // Create a reusable HelpPopover instance
    private let helpPopover = HelpPopover()
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize user toggle flag
        userHasToggledVirtualCheckbox = false

        // Set up the table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = false
        tableView.selectionHighlightStyle = .none
        tableView.allowsColumnSelection = false
        tableView.rowHeight = 22
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.gridStyleMask = [.dashedHorizontalGridLineMask]
        tableView.gridColor = NSColor.lightGray
        tableView.backgroundColor = NSColor.clear
        
        
        // Set up the search field
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.placeholderString = "Search groups..."

        loadEntraGroups()

        
        // Pre-populate groupSelectionModes with existing real assignments:
        for assignment in existingAssignments {
            if let groupId = assignment["groupId"] as? String,
               let mode = assignment["mode"] as? String,
               (assignment["isVirtual"] as? Bool) == false {
                // Store using the groupId (which matches the "id" field in Entra groups)
                groupSelectionModes[groupId] = mode
            }
        }

        clearAllButton.target = self
        clearAllButton.action = #selector(clearAllButtonClicked(_:))
        clearAllButton.title = "Clear All"

        
        // Reload the table view
        DispatchQueue.main.async {
            self.setGroupCountLabel()
            self.tableView.reloadData()
            self.updateVirtualCheckboxState()
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()

        // Load the saved size or use the default size
        let defaultSize = NSSize(width: 550, height: 520)
        let savedSize = loadSavedSheetSize() ?? defaultSize

        if let sheetWindow = view.window {
            sheetWindow.setContentSize(savedSize) // Apply the saved or default size
            sheetWindow.minSize = NSSize(width: 550, height: 520) // Set minimum size
        }
    }

    // Load the size from UserDefaults
    private func loadSavedSheetSize() -> NSSize? {
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "GroupSelectViewSheetSize") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
            return NSSize(width: width, height: height)
        }
        return nil
    }

    
    // MARK: - Actions
    @IBAction func clearAllButtonClicked(_ sender: NSButton) {
        // Clear all group selections
        groupSelectionModes.removeAll()
        
        // Uncheck virtual groups
        allDevicesButton.state = .off
        allUsersButton.state = .off
        
        // Set the flag to indicate user explicitly changed virtual checkbox state
        userHasToggledVirtualCheckbox = true
        
        // Check if All Devices should be available based on assignment type
        let allDevicesAvailable = assignmentType != "Available"
        
        // Check if virtual groups are excluded by other assignment types
        let allDevicesExcluded = excludedGroups.contains { ($0["displayName"] as? String) == "All Devices" }
        let allUsersExcluded = excludedGroups.contains { ($0["displayName"] as? String) == "All Users" }
        
        // Enable/disable based on assignment type restrictions and exclusions
        allDevicesButton.isEnabled = allDevicesAvailable && !allDevicesExcluded
        allUsersButton.isEnabled = !allUsersExcluded
                
        // Reload the table to update all checkboxes
        tableView.reloadData()
    }
    
    // MARK: - Data Source
    private func loadEntraGroups() {
        // Fetch cached Entra groups from AppDataManager
        allGroups = AppDataManager.shared.getEntraGroups()
        filteredGroups = allGroups
    }
    
    @objc func searchFieldChanged(_ sender: NSSearchField) {
        let searchText = sender.stringValue.lowercased()
        
        if searchText.isEmpty {
            filteredGroups = allGroups
        } else {
            filteredGroups = allGroups.filter {
                let displayName = ($0["displayName"] as? String) ?? ""
                return displayName.lowercased().contains(searchText)
            }
        }
        
        setGroupCountLabel()
        tableView.reloadData()
    }
    
    func setGroupCountLabel() {
        let filteredGroupsCount = filteredGroups.count
        let allGroupsCount = allGroups.count
        groupCountLabel.stringValue = String(format: "%d of %d", filteredGroupsCount, allGroupsCount)
    }
    
    // MARK: - Actions
    // IBAction for the Save button to gather the selections and pass them back via the delegate:
    @IBAction func saveButtonClicked(_ sender: NSButton) {
        
        // Gather the selected groups and their modes
        var selections = [[String: Any]]()
        if allDevicesButton.state == .on {
            selections.append(["displayName": "All Devices", "mode": "include", "isVirtual": true])
        }
        if allUsersButton.state == .on {
            selections.append(["displayName": "All Users", "mode": "include", "isVirtual": true])
        }
        
        for group in filteredGroups {
            guard let groupId = group["id"] as? String else { continue }
            if let mode = groupSelectionModes[groupId] {
                selections.append([
                    "id": groupId,
                    "displayName": group["displayName"] as? String ?? "",
                    "mode": mode,
                    "isVirtual": false
                ])
            }
        }
        
        delegate?.groupSelectionViewController(self, didSelectGroups: selections, forAssignmentType: assignmentType)
        self.dismiss(self)
    }

        
    
    
    // MARK: - Table View Data Source
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredGroups.count
    }

    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let group = filteredGroups[row]
        
        if tableColumn?.identifier.rawValue == "GroupNameColumn" {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("GroupNameCell"), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = group["displayName"] as? String ?? ""
                cell.toolTip = group["id"] as? String ?? ""
                return cell
            }
        } else if tableColumn?.identifier.rawValue == "GroupIncludeColumn" {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("GroupIncludeCell"), owner: self) as? NSTableCellView,
               let checkbox = cell.subviews.first(where: { $0 is NSButton }) as? NSButton {
                checkbox.target = self
                checkbox.action = #selector(includeCheckboxToggled(_:))
                checkbox.tag = row
                let groupId = group["id"] as? String ?? ""
                
                // Check if this group is used in another intent (excluded)
                let isExcluded = excludedGroups.contains { ($0["groupId"] as? String) == groupId }
                let selectedMode = groupSelectionModes[groupId]
                
                if isExcluded {
                    // Groups already assigned to other intents can't be selected
                    checkbox.isEnabled = false
                    checkbox.state = .off
                } else {
                    // Set the checkbox state based on current selection
                    checkbox.state = (selectedMode == "include") ? .on : .off
                    
                    // Enable only if not in "exclude" mode
                    checkbox.isEnabled = selectedMode != "exclude"
                }
                return cell
            }
        } else if tableColumn?.identifier.rawValue == "GroupExcludeColumn" {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("GroupExcludeCell"), owner: self) as? NSTableCellView,
               let checkbox = cell.subviews.first(where: { $0 is NSButton }) as? NSButton {
                checkbox.target = self
                checkbox.action = #selector(excludeCheckboxToggled(_:))
                checkbox.tag = row
                let groupId = group["id"] as? String ?? ""
                
                let isExcluded = excludedGroups.contains { ($0["groupId"] as? String) == groupId }
                let selectedMode = groupSelectionModes[groupId]
                
                if isExcluded {
                    // Groups already assigned to other intents can't be selected
                    checkbox.isEnabled = false
                    checkbox.state = .off
                } else {
                    // Set the checkbox state based on current selection
                    checkbox.state = (selectedMode == "exclude") ? .on : .off
                    
                    // Enable only if not in "include" mode
                    checkbox.isEnabled = selectedMode != "include"
                }
                return cell
            }
        }
        return nil
    }

    
    // The following methods to handle toggling the checkboxes for a given row:
    @objc func includeCheckboxToggled(_ sender: NSButton) {
        let row = sender.tag
        let group = filteredGroups[row]
        guard let groupId = group["id"] as? String else { return }
        
        if sender.state == .on {
            // Set this group to include mode
            groupSelectionModes[groupId] = "include"
        } else {
            // Remove the selection
            groupSelectionModes.removeValue(forKey: groupId)
        }
        
        tableView.reloadData()
        // Mark that user has made changes
        userHasToggledVirtualCheckbox = true
    }

    @objc func excludeCheckboxToggled(_ sender: NSButton) {
        let row = sender.tag
        let group = filteredGroups[row]
        guard let groupId = group["id"] as? String else { return }
        
        if sender.state == .on {
            // Set this group to exclude mode
            groupSelectionModes[groupId] = "exclude"
        } else {
            // Remove the selection
            groupSelectionModes.removeValue(forKey: groupId)
        }
        
        tableView.reloadData()
        // Mark that user has made changes
        userHasToggledVirtualCheckbox = true
    }

    // Add a helper method to update the virtual group checkboxes based on table selections:
    func updateVirtualCheckboxState() {
        // Check if All Devices should be available based on assignment type
        let allDevicesAvailable = assignmentType != "Available"
        
        // Check if virtual groups are excluded by other assignment types
        let allDevicesExcluded = excludedGroups.contains { ($0["displayName"] as? String) == "All Devices" }
        let allUsersExcluded = excludedGroups.contains { ($0["displayName"] as? String) == "All Users" }
        
        // Enable/disable based on assignment type restrictions and exclusions
        allDevicesButton.isEnabled = allDevicesAvailable && !allDevicesExcluded
        allUsersButton.isEnabled = !allUsersExcluded
        
        // If this is the initial state and we haven't toggled yet
        if !userHasToggledVirtualCheckbox {
            // Set initial states based on existing assignments
            if existingAssignments.first(where: {
                ($0["isVirtual"] as? Bool) == true &&
                ($0["displayName"] as? String) == "All Devices"
            }) != nil {
                allDevicesButton.state = .on
            } else {
                allDevicesButton.state = .off
            }
            
            if existingAssignments.first(where: {
                ($0["isVirtual"] as? Bool) == true &&
                ($0["displayName"] as? String) == "All Users"
            }) != nil {
                allUsersButton.state = .on
            } else {
                allUsersButton.state = .off
            }
        }
    }

    
    // IBAction for the virtual checkboxes (All Devices / All Users) so that only one can be selected:
    @IBAction func virtualCheckboxToggled(_ sender: NSButton) {
        // Mark that the user has explicitly changed a virtual checkbox
        userHasToggledVirtualCheckbox = true
        
        // Only allow one virtual group to be selected at a time
//        if sender == allDevicesButton && sender.state == .on {
//            allUsersButton.state = .off
//        } else if sender == allUsersButton && sender.state == .on {
//            allDevicesButton.state = .off
//        }
        
        // No need to clear real group selections anymore
        tableView.reloadData()
    }

    
    // MARK: - Help Buttons
    @IBAction func showHelpForVirtualGroups(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Built-In groups:\n\nThese are not manually created groups in your Azure Active Directory, but rather built-in virtual groups that automatically update with all relevant users or devices.")
        
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))
        
        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }
    
    @IBAction func showHelpForRealGroups(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Real groups:\n\nThese are manually created groups in your Azure Active Directory. The might be static group or dynamic groups.\n\nThese can also be any type of group that is 'Security Group' enabled. That includes traditional security groups, 365 groups, or even security enabled distribution groups.")
        
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))
        
        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }
    
    
}
