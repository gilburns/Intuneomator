//
//  FilterSelectViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 4/24/25.
//

import Foundation
import Cocoa

/// Delegate to notify when a filter is selected for a specific group.
protocol FilterSelectViewControllerDelegate: AnyObject {
    func filterSelectViewController(_ controller: FilterSelectViewController, didSelectFilter filter: [String: Any], forGroup group: String)
}

/// Sheet view controller for selecting Microsoft Intune assignment filters
/// Allows users to configure device targeting filters for group assignments, enabling
/// granular control over which devices receive application deployments
/// 
/// **Key Features:**
/// - Displays available macOS assignment filters from Microsoft Intune
/// - Supports include/exclude filter modes for precise targeting
/// - Provides search functionality for filter discovery
/// - Maintains single filter selection per assignment
/// - Integrates with group assignment workflow
/// - Handles existing filter configurations for editing
class FilterSelectViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    /// Delegate to notify when a filter is selected for a specific group.
    weak var delegate: FilterSelectViewControllerDelegate?

    /// Tracks the include/exclude selection mode for each filter by ID.
    /// Key: filter ID, Value: "include" or "exclude".
    var filterSelectionModes: [String: String] = [:] // key: filter id, value: “include” or “exclude”

    /// The existing filter configuration for the current group, if any.
    /// Contains keys "id" (String) and "mode" ("include"/"exclude").
    var existingFilter: [String: Any]?
    
    /// Text field displaying the title for this filter assignment (e.g., which group is being filtered).
    @IBOutlet weak var filterAssignTitleField: NSTextField!
    
    /// Table view listing all available filters with include/exclude checkboxes.
    @IBOutlet weak var tableView: NSTableView!
        
    /// Button to save the selected filter and mode for the assignment.
    @IBOutlet weak var saveButton: NSButton!
    
    /// Search field to filter the list of available filters by name.
    @IBOutlet weak var searchField: NSSearchField!
    
    /// Button to clear any selected filter, resetting include/exclude states.
    @IBOutlet weak var clearAllButton: NSButton!

    
    /// The display name of the application or label for which the filter is being configured.
    var displayName: String = ""
    /// The name of the group assignment for which the filter is being applied.
    var assignment: String = ""
    /// Array containing any pre-existing assignments for this group (not directly used in filter selection).
    var existingAssignment: [[String : Any]] = []

    /// Full list of all filters fetched from Entra to display.
    var allFilters: [[String: Any]] = []
    /// Subset of `allFilters` matching the current search query.
    var filteredFilters: [[String: Any]] = []
        
    /// HelpPopover instance to show contextual help popovers.
    private let helpPopover = HelpPopover()

    
    /// Called after the view has loaded.
    /// Initializes the UI, loads filters, and applies any existing filter selection.
    override func viewDidLoad() {
        super.viewDidLoad()
        

        // Set the title for the filter assignment
        if assignment.isEmpty {
            filterAssignTitleField.stringValue = "Select a filter"
        } else {
            filterAssignTitleField.stringValue = "Filter assignment for \(assignment) for \(displayName)"
        }

        // Set up the table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = false
        tableView.selectionHighlightStyle = .none
        tableView.allowsColumnSelection = false
        tableView.rowHeight = 28
//        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.gridStyleMask = [.dashedHorizontalGridLineMask]
        tableView.gridColor = NSColor.lightGray
        tableView.backgroundColor = NSColor.clear
        
        
        // Set up the search field
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.placeholderString = "Search filters..."

        loadEntraFilters()

        clearAllButton.target = self
        clearAllButton.action = #selector(clearAllButtonClicked(_:))
        clearAllButton.title = "Clear Selection"

        if let filter = existingFilter, let id = filter["id"] as? String, let mode = filter["mode"] as? String {
            filterSelectionModes[id] = mode
        }
        
        // Reload the table view
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }

    }
    
    /// Called just before the view appears.
    /// Restores any saved sheet size from UserDefaults and applies minimum size constraints.
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
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "FilterSelectViewSheetSize") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
            return NSSize(width: width, height: height)
        }
        return nil
    }

    /// Clears any include/exclude selection so no filter is applied.
    /// Reloads the table view to reflect the cleared state.
    /// - Parameter sender: The "Clear Selection" button that was clicked.
    @IBAction func clearAllButtonClicked(_ sender: NSButton) {
        // Clear all filter selections
        filterSelectionModes.removeAll()

        // Reload the table to update all checkboxes
        tableView.reloadData()
    }

    
    /// Loads cached filters from AppDataManager and initializes `filteredFilters`.
    private func loadEntraFilters() {
        // Fetch cached Entra filters from AppDataManager
        allFilters = AppDataManager.shared.getEntraFilters()
        filteredFilters = allFilters
    }
    
    /// Called when the search field text changes.
    /// Filters `allFilters` by displayName containing the search text (case-insensitive).
    /// - Parameter sender: The search field whose value changed.
    @objc func searchFieldChanged(_ sender: NSSearchField) {
        let searchText = sender.stringValue.lowercased()
        
        if searchText.isEmpty {
            filteredFilters = allFilters
        } else {
            filteredFilters = allFilters.filter {
                let displayName = ($0["displayName"] as? String) ?? ""
                return displayName.lowercased().contains(searchText)
            }
        }
        
        tableView.reloadData()
    }

    
    /// Returns the number of rows in the table view, i.e., the number of filtered filters.
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredFilters.count
    }

    
    /// Provides the view for each table cell based on the column identifier:
    /// - "FilterNameColumn": shows the filter's displayName.
    /// - "FilterIncludeColumn": shows an "include" checkbox for this filter.
    /// - "FilterExcludeColumn": shows an "exclude" checkbox for this filter.
    /// Configures checkbox state and enables/disables based on current `filterSelectionModes`.
    /// - Parameters:
    ///   - tableView: The table view requesting the cell.
    ///   - tableColumn: The column for which a cell is needed.
    ///   - row: The row index in `filteredFilters`.
    /// - Returns: The configured cell view or nil.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let filter = filteredFilters[row]
        
        if tableColumn?.identifier.rawValue == "FilterNameColumn" {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("FilterNameCell"), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = filter["displayName"] as? String ?? ""
                cell.toolTip = filter["id"] as? String ?? ""
                return cell
            }
        } else if tableColumn?.identifier.rawValue == "FilterIncludeColumn" {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("FilterIncludeCell"), owner: self) as? NSTableCellView,
               let checkbox = cell.subviews.first(where: { $0 is NSButton }) as? NSButton {
                checkbox.target = self
                checkbox.action = #selector(includeCheckboxToggled(_:))
                checkbox.tag = row
                let filterId = filter["id"] as? String ?? ""
                
                // Check if this filter is used in another intent (excluded)
                let selectedMode = filterSelectionModes[filterId]
                
                // Set the checkbox state based on current selection
                checkbox.state = (selectedMode == "include") ? .on : .off
                
                // Enable only if not in "exclude" mode
                checkbox.isEnabled = selectedMode != "exclude"

                return cell
            }
        } else if tableColumn?.identifier.rawValue == "FilterExcludeColumn" {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("FilterExcludeCell"), owner: self) as? NSTableCellView,
               let checkbox = cell.subviews.first(where: { $0 is NSButton }) as? NSButton {
                checkbox.target = self
                checkbox.action = #selector(excludeCheckboxToggled(_:))
                checkbox.tag = row
                let filterId = filter["id"] as? String ?? ""
                
                let selectedMode = filterSelectionModes[filterId]
                
                // Set the checkbox state based on current selection
                checkbox.state = (selectedMode == "exclude") ? .on : .off
                
                // Enable only if not in "include" mode
                checkbox.isEnabled = selectedMode != "include"

                return cell
            }
        }
        return nil
    }

    
    /// Called when an "include" checkbox is toggled.
    /// Clears any previous selection, then sets the selected filter ID to "include" mode.
    /// Reloads the table view to update checkbox states.
    /// - Parameter sender: The checkbox button that was toggled.
    @objc func includeCheckboxToggled(_ sender: NSButton) {
        let row = sender.tag
        let filter = filteredFilters[row]
        guard let filterId = filter["id"] as? String else { return }
        
        // Clear previous selections
        filterSelectionModes.removeAll()
        
        if sender.state == .on {
            filterSelectionModes[filterId] = "include"
        }
        
        tableView.reloadData()
    }

    /// Called when an "exclude" checkbox is toggled.
    /// Clears any previous selection, then sets the selected filter ID to "exclude" mode.
    /// Reloads the table view to update checkbox states.
    /// - Parameter sender: The checkbox button that was toggled.
    @objc func excludeCheckboxToggled(_ sender: NSButton) {
        let row = sender.tag
        let filter = filteredFilters[row]
        guard let filterId = filter["id"] as? String else { return }
        
        // Clear previous selections
        filterSelectionModes.removeAll()
        
        if sender.state == .on {
            filterSelectionModes[filterId] = "exclude"
        }
        
        tableView.reloadData()
    }

    /// Saves the currently selected filter and mode by invoking the delegate callback.
    /// Constructs a result dictionary with "mode" ("include" or "exclude") and filter data.
    /// Dismisses the sheet after notifying the delegate.
    /// - Parameter sender: The "Save" button that was clicked.
    @IBAction func saveButtonClicked(_ sender: NSButton) {
        guard let selectedEntry = filterSelectionModes.first,
              let selectedFilter = allFilters.first(where: { ($0["id"] as? String) == selectedEntry.key }) else {
            return
        }
        
        var result = selectedFilter
        result["mode"] = selectedEntry.value // include or exclude
        
        delegate?.filterSelectViewController(self, didSelectFilter: result, forGroup: assignment)
        
        dismiss(self)
    }


    
    /// Shows a popover explaining built-in virtual groups (All Users/All Devices).
    /// - Parameter sender: The help button that was clicked.
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
    
    /// Shows a popover explaining real Azure AD groups (security, Office 365 groups, etc.).
    /// - Parameter sender: The help button that was clicked.
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
