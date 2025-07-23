//
//  AzureStorageSettingsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/23/25.
//

import Cocoa

/// View controller for managing Azure Storage configuration settings
/// Provides a table view interface for creating, editing, and managing multiple storage configurations
class AzureStorageSettingsViewController: NSViewController {
    
    // MARK: - UI Outlets
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var editButton: NSButton!
    @IBOutlet weak var testButton: NSButton!
    @IBOutlet weak var statusLabel: NSTextField!
    
    // MARK: - Properties
    
    /// Parent tabbed sheet view controller for coordination
    weak var parentTabbedSheetViewController: TabbedSheetViewController?
    
    /// Tracks whether any settings have been modified
    var hasUnsavedChanges = false
    
    /// Initial settings data
    private var initialData: [String: Any] = [:]
    
    /// Array of Azure Storage configurations
    private var storageConfigurations: [[String: Any]] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupButtons()
        loadStorageConfigurations()
    }
    
    // MARK: - Setup Methods
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
    }
    
    private func setupButtons() {
        updateButtonStates()
    }
    
    private func updateButtonStates() {
        let hasSelection = tableView.selectedRow >= 0
        removeButton.isEnabled = hasSelection
        editButton.isEnabled = hasSelection
        testButton.isEnabled = hasSelection
    }
    
    private func loadStorageConfigurations() {
        // Load configurations via XPC
        XPCManager.shared.getAzureStorageConfigurationSummaries { [weak self] summaries in
            DispatchQueue.main.async {
                self?.storageConfigurations = summaries
                self?.tableView.reloadData()
                self?.updateStatusLabel()
            }
        }
    }
    
    private func updateStatusLabel() {
        let count = storageConfigurations.count
        statusLabel.stringValue = "\(count) configuration\(count == 1 ? "" : "s")"
    }
    
    // MARK: - Actions
    
    @IBAction func addConfiguration(_ sender: NSButton) {
        presentConfigurationEditor(isNew: true, configuration: nil)
    }
    
    @IBAction func removeConfiguration(_ sender: NSButton) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < storageConfigurations.count else { return }
        
        let configuration = storageConfigurations[selectedRow]
        guard let name = configuration["name"] as? String else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Configuration"
        alert.informativeText = "Are you sure you want to delete the configuration '\(name)'? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            removeConfigurationWithName(name)
        }
    }
    
    @IBAction func editConfiguration(_ sender: NSButton) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < storageConfigurations.count else { return }
        
        let configuration = storageConfigurations[selectedRow]
        presentConfigurationEditor(isNew: false, configuration: configuration)
    }
    
    @IBAction func testConfiguration(_ sender: NSButton) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < storageConfigurations.count else { return }
        
        let configuration = storageConfigurations[selectedRow]
        guard let name = configuration["name"] as? String else { return }
        
        testButton.isEnabled = false
        testButton.title = "Testing..."
        
        XPCManager.shared.testAzureStorageConfiguration(name: name) { [weak self] success in
            DispatchQueue.main.async {
                self?.testButton.isEnabled = true
                self?.testButton.title = "Test"
                
                let alert = NSAlert()
                if let success = success, success {
                    alert.messageText = "Connection Successful"
                    alert.informativeText = "Successfully connected to Azure Storage configuration '\(name)'."
                    alert.alertStyle = .informational
                } else {
                    alert.messageText = "Connection Failed"
                    alert.informativeText = "Unable to connect to Azure Storage configuration '\(name)'. Please check the configuration and try again."
                    alert.alertStyle = .warning
                }
                alert.addButton(withTitle: "OK")
                alert.runModal()
                
                // Reload configurations to update status
                self?.loadStorageConfigurations()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func presentConfigurationEditor(isNew: Bool, configuration: [String: Any]?) {
        let storyboard = NSStoryboard(name: "Settings", bundle: nil)
        guard let editorVC = storyboard.instantiateController(withIdentifier: "AzureStorageConfigurationEditorViewController") as? AzureStorageConfigurationEditorViewController else {
            Logger.error("Failed to load AzureStorageConfigurationEditorViewController", category: .core, toUserDirectory: true)
            return
        }
        
        editorVC.isNewConfiguration = isNew
        editorVC.configurationData = configuration ?? [:]
        editorVC.saveHandler = { [weak self] savedConfiguration in
            self?.handleConfigurationSaved(savedConfiguration, isNew: isNew)
        }
        
        presentAsSheet(editorVC)
    }
    
    private func handleConfigurationSaved(_ configuration: [String: Any], isNew: Bool) {
        markAsChanged()
        loadStorageConfigurations() // Reload to get updated data
    }
    
    private func removeConfigurationWithName(_ name: String) {
        XPCManager.shared.removeAzureStorageConfiguration(name: name) { [weak self] success in
            DispatchQueue.main.async {
                if let success = success, success {
                    self?.markAsChanged()
                    self?.loadStorageConfigurations()
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Deletion Failed"
                    alert.informativeText = "Unable to delete the configuration '\(name)'. Please try again."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    private func markAsChanged() {
        hasUnsavedChanges = true
        parentTabbedSheetViewController?.updateSaveButtonState()
    }
}

// MARK: - TabbedSheetChildProtocol

extension AzureStorageSettingsViewController: TabbedSheetChildProtocol {
    
    func getDataForSave() -> [String: Any]? {
        // Azure Storage configurations are managed via XPC and don't need to be returned
        // The changes have already been saved when configurations were added/edited/removed
        return ["azureStorageConfigurationsManaged": true]
    }
    
    func setInitialData(_ data: [String: Any]) {
        self.initialData = data
        if isViewLoaded {
            loadStorageConfigurations()
        }
    }
    
    func updateFromOtherTabs(_ combinedData: [String: Any]) {
        // Azure Storage settings typically don't depend on other tabs
    }
    
    func validateData() -> String? {
        // No validation needed - configurations are validated when saved individually
        return nil
    }
}

// MARK: - NSTableViewDataSource

extension AzureStorageSettingsViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return storageConfigurations.count
    }
}

// MARK: - NSTableViewDelegate

extension AzureStorageSettingsViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < storageConfigurations.count else { return nil }
        
        let configuration = storageConfigurations[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("\(identifier)Cell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier
            
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            cell?.addSubview(textField)
            cell?.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 2),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }
        
        switch identifier {
        case "name":
            cell?.textField?.stringValue = configuration["name"] as? String ?? ""
        case "account":
            cell?.textField?.stringValue = configuration["accountName"] as? String ?? ""
        case "container":
            cell?.textField?.stringValue = configuration["containerName"] as? String ?? ""
        case "auth":
            cell?.textField?.stringValue = configuration["authMethod"] as? String ?? ""
        case "status":
            let isValid = configuration["isValid"] as? Bool ?? false
            cell?.textField?.stringValue = isValid ? "✅ Valid" : "❌ Invalid"
            cell?.textField?.textColor = isValid ? .systemGreen : .systemRed
        default:
            cell?.textField?.stringValue = ""
        }
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()
    }
}
