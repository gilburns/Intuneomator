//
//  ColumnSelectionViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 8/2/25.
//

import Cocoa

protocol ColumnSelectionDelegate: AnyObject {
    func columnSelectionDidComplete(_ selectedColumns: [String], displayNames: [String: String])
    func columnSelectionDidCancel()
}

class ColumnSelectionViewController: NSViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var selectionCountLabel: NSTextField!
    @IBOutlet weak var selectAllButton: NSButton!
    @IBOutlet weak var deselectAllButton: NSButton!
    @IBOutlet weak var confirmButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    
    // MARK: - Properties
    weak var delegate: ColumnSelectionDelegate?
    
    private var reportType: String = ""
    private var reportDisplayName: String = ""
    private var allColumns: [ReportRegistry.ColumnDefinition] = []
    private var filteredColumns: [ReportRegistry.ColumnDefinition] = []
    private var selectedColumnKeys: Set<String> = []
    private var preselectedColumns: [String] = []
    
    // MARK: - Initializers
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Public Configuration
    
    /// Configures the column selection dialog
    /// - Parameters:
    ///   - reportType: The report type identifier
    ///   - reportDisplayName: Display name for the report
    ///   - preselectedColumns: Array of column keys that should be pre-selected
    func configure(reportType: String, reportDisplayName: String, preselectedColumns: [String] = []) {
        self.reportType = reportType
        self.reportDisplayName = reportDisplayName
        self.preselectedColumns = preselectedColumns
        
        // Load column definitions from ReportRegistry
        if let reportDef = ReportRegistry.shared.getReportDefinition(for: reportType) {
            self.allColumns = reportDef.supportedColumns
        }
        
        // Set initial selection
        if preselectedColumns.isEmpty {
            // If no preselection, use default columns
            self.selectedColumnKeys = Set(ReportRegistry.shared.getDefaultColumns(for: reportType) ?? [])
        } else {
            self.selectedColumnKeys = Set(preselectedColumns)
        }
        
        // Initialize filtered columns
        self.filteredColumns = allColumns
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        updateUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        titleLabel.stringValue = "Select Columns for '\(reportDisplayName)' report"
        
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.placeholderString = "Search columns..."
        
        confirmButton.title = "OK"
        cancelButton.title = "Cancel"
        selectAllButton.title = "Select All"
        deselectAllButton.title = "Deselect All"
        
        updateSelectionCountLabel()
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        // Configure table view appearance
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        tableView.usesAlternatingRowBackgroundColors = true
        
        // Add columns to table view
        let checkboxColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("checkbox"))
        checkboxColumn.title = ""
        checkboxColumn.width = 30
        checkboxColumn.minWidth = 30
        checkboxColumn.maxWidth = 30
        tableView.addTableColumn(checkboxColumn)
        
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Column Name"
        nameColumn.width = 200
        nameColumn.minWidth = 150
        tableView.addTableColumn(nameColumn)
        
        let keyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("key"))
        keyColumn.title = "API Key"
        keyColumn.width = 150
        keyColumn.minWidth = 100
        tableView.addTableColumn(keyColumn)
    }
    
    private func updateUI() {
        updateSelectionCountLabel()
        tableView.reloadData()
        
        // Update button states
        let hasColumns = !filteredColumns.isEmpty
        let allSelected = !filteredColumns.isEmpty && filteredColumns.allSatisfy { selectedColumnKeys.contains($0.key) }
        let noneSelected = filteredColumns.allSatisfy { !selectedColumnKeys.contains($0.key) }
        
        selectAllButton.isEnabled = hasColumns && !allSelected
        deselectAllButton.isEnabled = hasColumns && !noneSelected
        confirmButton.isEnabled = !selectedColumnKeys.isEmpty
    }
    
    private func updateSelectionCountLabel() {
        let selectedCount = selectedColumnKeys.count
        let totalCount = allColumns.count
        selectionCountLabel.stringValue = "\(selectedCount) of \(totalCount) columns selected"
        
        if selectedCount == 0 {
            selectionCountLabel.textColor = .systemRed
        } else if selectedCount < 5 {
            selectionCountLabel.textColor = .systemOrange
        } else {
            selectionCountLabel.textColor = .labelColor
        }
    }
    
    // MARK: - Actions
    
    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        let searchText = sender.stringValue.lowercased()
        
        if searchText.isEmpty {
            filteredColumns = allColumns
        } else {
            filteredColumns = allColumns.filter { column in
                column.displayName.lowercased().contains(searchText) ||
                column.key.lowercased().contains(searchText)
            }
        }
        
        updateUI()
    }
    
    @IBAction func selectAllButtonClicked(_ sender: NSButton) {
        for column in filteredColumns {
            selectedColumnKeys.insert(column.key)
        }
        updateUI()
    }
    
    @IBAction func deselectAllButtonClicked(_ sender: NSButton) {
        for column in filteredColumns {
            selectedColumnKeys.remove(column.key)
        }
        updateUI()
    }
    
    @IBAction func confirmButtonClicked(_ sender: NSButton) {
        let selectedColumnsArray = Array(selectedColumnKeys)
        
        // Create display name mapping for selected columns
        var displayNames: [String: String] = [:]
        for column in allColumns {
            if selectedColumnKeys.contains(column.key) {
                displayNames[column.key] = column.displayName
            }
        }
        
        delegate?.columnSelectionDidComplete(selectedColumnsArray, displayNames: displayNames)
        dismissController()
    }
    
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        delegate?.columnSelectionDidCancel()
        dismissController()
    }
    
    private func dismissController() {
        if let window = view.window {
            if let parent = window.sheetParent {
                parent.endSheet(window)
            } else {
                window.close()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Gets the currently selected columns
    func getSelectedColumns() -> [String] {
        return Array(selectedColumnKeys)
    }
    
    /// Gets display names for selected columns
    func getSelectedDisplayNames() -> [String: String] {
        var displayNames: [String: String] = [:]
        for column in allColumns {
            if selectedColumnKeys.contains(column.key) {
                displayNames[column.key] = column.displayName
            }
        }
        return displayNames
    }
}

// MARK: - NSTableViewDataSource

extension ColumnSelectionViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredColumns.count
    }
}

// MARK: - NSTableViewDelegate

extension ColumnSelectionViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredColumns.count else { return nil }
        
        let column = filteredColumns[row]
        let identifier = tableColumn?.identifier
        
        if identifier?.rawValue == "checkbox" {
            let cellView = NSTableCellView()
            
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxToggled(_:)))
            checkbox.state = selectedColumnKeys.contains(column.key) ? .on : .off
            checkbox.tag = row
            
            cellView.addSubview(checkbox)
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                checkbox.centerXAnchor.constraint(equalTo: cellView.centerXAnchor),
                checkbox.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            return cellView
            
        } else if identifier?.rawValue == "name" {
            let cellView = NSTableCellView()
            
            let textField = NSTextField(labelWithString: column.displayName)
            textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            
            cellView.addSubview(textField)
            cellView.textField = textField
            
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            return cellView
            
        } else if identifier?.rawValue == "key" {
            let cellView = NSTableCellView()
            
            let textField = NSTextField(labelWithString: column.key)
            textField.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            textField.textColor = .secondaryLabelColor
            
            cellView.addSubview(textField)
            cellView.textField = textField
            
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            return cellView
        }
        
        return nil
    }
    
    @objc private func checkboxToggled(_ sender: NSButton) {
        let row = sender.tag
        guard row < filteredColumns.count else { return }
        
        let column = filteredColumns[row]
        
        if sender.state == .on {
            selectedColumnKeys.insert(column.key)
        } else {
            selectedColumnKeys.remove(column.key)
        }
        
        updateUI()
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 24
    }
}
