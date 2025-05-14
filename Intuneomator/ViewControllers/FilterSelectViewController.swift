//
//  FilterSelectViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 4/24/25.
//

import Foundation
import Cocoa

protocol FilterSelectViewControllerDelegate: AnyObject {
    func filterSelectViewController(_ controller: FilterSelectViewController, didSelectFilter filter: [String: Any], forGroup group: String)
}

class FilterSelectViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    weak var delegate: FilterSelectViewControllerDelegate?

    var filterSelectionModes: [String: String] = [:] // key: filter id, value: “include” or “exclude”

    var existingFilter: [String: Any]?
    
    // MARK: - Outlets
    @IBOutlet weak var filterAssignTitleField: NSTextField!
    
    @IBOutlet weak var tableView: NSTableView!
        
    @IBOutlet weak var saveButton: NSButton!
    
    @IBOutlet weak var searchField: NSSearchField!
    
    @IBOutlet weak var clearAllButton: NSButton!

    
    // Input data
    var displayName: String = ""
    var assignment: String = ""
    var existingAssignment: [[String : Any]] = []

    // Full list of all filters fetched from Entra
    var allFilters: [[String: Any]] = []
    // This will hold the filtered filters based on search criteria
    var filteredFilters: [[String: Any]] = []
        
    // Create a reusable HelpPopover instance
    private let helpPopover = HelpPopover()

    
    // MARK: - View Lifecycle
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

    // MARK: - Actions
    
    @IBAction func clearAllButtonClicked(_ sender: NSButton) {
        // Clear all filter selections
        filterSelectionModes.removeAll()

        // Reload the table to update all checkboxes
        tableView.reloadData()
    }

    
    // MARK: - Data Source
    private func loadEntraFilters() {
        // Fetch cached Entra filters from AppDataManager
        allFilters = AppDataManager.shared.getEntraFilters()
        filteredFilters = allFilters
    }
    
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

    
    // MARK: - Table View Data Source
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredFilters.count
    }

    
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

    
    // The following methods to handle toggling the checkboxes for a given row:
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
