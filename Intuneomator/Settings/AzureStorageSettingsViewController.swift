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
        tableView.doubleAction = #selector(tableViewDoubleClicked(_:))
        tableView.target = self
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
        
        // Check for dependent scheduled reports first
        XPCManager.shared.getScheduledReportsUsingAzureStorageConfiguration(name: name) { [weak self] dependentReports in
            DispatchQueue.main.async {
                self?.showDeleteConfirmation(for: name, dependentReports: dependentReports ?? [])
            }
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
    
    @objc private func tableViewDoubleClicked(_ sender: NSTableView) {
        let clickedRow = sender.clickedRow
        guard clickedRow >= 0, clickedRow < storageConfigurations.count else { return }
        
        let configuration = storageConfigurations[clickedRow]
        presentConfigurationEditor(isNew: false, configuration: configuration)
    }
    
    // MARK: - Helper Methods
    
    private func presentConfigurationEditor(isNew: Bool, configuration: [String: Any]?) {
        let storyboard = NSStoryboard(name: "Settings", bundle: nil)
        guard let editorVC = storyboard.instantiateController(withIdentifier: "AzureStorageConfigurationEditorViewController") as? AzureStorageConfigurationEditorViewController else {
            Logger.error("Failed to load AzureStorageConfigurationEditorViewController", category: .core, toUserDirectory: true)
            return
        }
        
        editorVC.isNewConfiguration = isNew
        
        // Pass existing configuration names for validation
        let existingNames = storageConfigurations.compactMap { $0["name"] as? String }
        editorVC.existingConfigurationNames = existingNames
        
        if isNew {
            // For new configurations, use empty data
            editorVC.configurationData = [:]
        } else {
            // For existing configurations, fetch the full configuration including sensitive data
            guard let configName = configuration?["name"] as? String else {
                Logger.error("Configuration name missing for editing", category: .core, toUserDirectory: true)
                return
            }
            
            // Fetch full configuration data including credentials
            XPCManager.shared.getNamedAzureStorageConfiguration(name: configName) { [weak self] fullConfigData in
                DispatchQueue.main.async {
                    editorVC.configurationData = fullConfigData ?? [:]
                    editorVC.saveHandler = { [weak self] savedConfiguration in
                        self?.handleConfigurationSaved(savedConfiguration, isNew: isNew)
                    }
                    self?.presentAsSheet(editorVC)
                }
            }
            return
        }
        
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
    
    private func showDeleteConfirmation(for configName: String, dependentReports: [String]) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        
        if dependentReports.isEmpty {
            // No dependencies - standard delete confirmation
            alert.messageText = "Delete Configuration"
            alert.informativeText = "Are you sure you want to delete the configuration '\(configName)'? This action cannot be undone."
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
        } else {
            // Has dependencies - show warning with options
            let reportCount = dependentReports.count
            let reportList = dependentReports.prefix(5).joined(separator: "\n• ")
            let truncated = dependentReports.count > 5 ? "\n• ... and \(dependentReports.count - 5) more" : ""
            
            alert.messageText = "Configuration In Use"
            alert.informativeText = """
            The configuration '\(configName)' is currently used by \(reportCount) scheduled report\(reportCount == 1 ? "" : "s"):
            
            • \(reportList)\(truncated)
            
            Choose how to handle the dependent reports:
            """
            
            alert.addButton(withTitle: "Delete & Disable Reports")
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Delete Anyway")
            alert.addButton(withTitle: "View Reports")
            
            // Make "Cancel" the default button for safety
            alert.buttons[0].keyEquivalent = ""  // Remove default from first button
            alert.buttons[1].keyEquivalent = "\r"  // Make Cancel the default
            alert.buttons[2].keyEquivalent = ""  // Ensure Delete Anyway is not default
            alert.buttons[3].keyEquivalent = ""  // Ensure View Reports is not default
        }
        
        let response = alert.runModal()
        
        if dependentReports.isEmpty {
            // No dependencies - simple delete
            if response == .alertFirstButtonReturn {
                removeConfigurationWithName(configName)
            }
        } else {
            // Has dependencies - handle different responses
            switch response {
            case .alertFirstButtonReturn: // Delete & Disable Reports
                deleteConfigurationAndDisableReports(configName: configName, dependentReports: dependentReports)
            case .alertSecondButtonReturn: // Cancel
                break
            case .alertThirdButtonReturn: // Delete Anyway
                removeConfigurationWithName(configName)
            case NSApplication.ModalResponse(rawValue: 1003): // View Reports (4th button)
                showDependentReports(dependentReports)
            default:
                break
            }
        }
    }
    
    private func showDependentReports(_ reportNames: [String]) {
        // Open the Scheduled Reports Manager to show the dependent reports
        // This gives users a way to easily find and modify the dependent reports
        let alert = NSAlert()
        alert.messageText = "Dependent Scheduled Reports"
        alert.informativeText = """
        The following scheduled reports use this Azure Storage configuration:
        
        \(reportNames.map { "• \($0)" }.joined(separator: "\n"))
        
        To safely delete this configuration, first edit these reports to use a different storage destination, or delete the reports entirely.
        
        Would you like to open the Scheduled Reports Manager?
        """
        alert.addButton(withTitle: "Open Reports Manager")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            WindowManager.shared.openWindow(
                identifier: "ScheduledReportsManagementViewController",
                storyboardName: "IntuneReports",
                controllerType: ScheduledReportsManagementViewController.self,
                windowTitle: "Scheduled Reports Manager",
                defaultSize: NSSize(width: 800, height: 600),
                restoreKey: "ScheduledReportsManagementViewController"
            )
        }
    }
    
    private func deleteConfigurationAndDisableReports(configName: String, dependentReports: [String]) {
        // First disable the dependent reports
        XPCManager.shared.disableScheduledReports(reportNames: dependentReports) { [weak self] success in
            DispatchQueue.main.async {
                if let success = success, success {
                    // Reports disabled successfully, now delete the configuration
                    self?.removeConfigurationWithName(configName)
                    
                    let alert = NSAlert()
                    alert.messageText = "Configuration Deleted"
                    alert.informativeText = """
                    The Azure Storage configuration '\(configName)' has been deleted.
                    
                    The following scheduled reports have been disabled to prevent failures:
                    \(dependentReports.map { "• \($0)" }.joined(separator: "\n"))
                    
                    You can re-enable these reports after configuring a new storage destination.
                    """
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                } else {
                    // Failed to disable reports
                    let alert = NSAlert()
                    alert.messageText = "Failed to Disable Reports"
                    alert.informativeText = """
                    Unable to disable the dependent scheduled reports. The configuration was not deleted to prevent report failures.
                    
                    Please try again or manually disable the reports before deleting the configuration.
                    """
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
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
        case "cleanup":
            cell?.textField?.stringValue = configuration["cleanupSummary"] as? String ?? "Disabled"
            let cleanupEnabled = configuration["cleanupEnabled"] as? Bool ?? false
            cell?.textField?.textColor = cleanupEnabled ? .systemBlue : .secondaryLabelColor
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
