//
//  CustomAttributeReportingViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/11/25.
//

import Cocoa

/// View controller for displaying detailed device run states for custom attribute shell scripts
/// Provides comprehensive reporting of script execution across assigned devices with sortable columns
/// and detailed execution information including status, output, and timing data
class CustomAttributeReportingViewController: NSViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var scriptNameLabel: NSTextField!
    @IBOutlet weak var summaryLabel: NSTextField!
    @IBOutlet weak var dateCreatedLabel: NSTextField!
    @IBOutlet weak var dateModifiedLabel: NSTextField!
    @IBOutlet weak var pieChartView: NSView!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var exportButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    // MARK: - Properties
    
    /// The custom attribute script data for which to display device run states
    var scriptData: [String: Any]?
    
    /// Array of device run state dictionaries from Microsoft Graph API
    var deviceRunStates: [[String: Any]] = []
    
    /// Filtered and sorted device run states for table display
    var filteredDeviceRunStates: [[String: Any]] = []
    
    /// Current sort descriptor for table columns
    var currentSortDescriptor: NSSortDescriptor?
    
    /// Custom pie chart view for displaying script execution status
    private var installationStatusPieChart: InstallationStatusPieChartView?
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupUI()
        setupPieChart()
        loadDeviceRunStates()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        let effectView = NSVisualEffectView(frame: view.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.blendingMode = .withinWindow
        effectView.material = .windowBackground
        effectView.state = .active
        
        self.view.addSubview(effectView, positioned: .below, relativeTo: nil)

        // Set up sheet window properties
        if let window = view.window {
            window.title = "Custom Attribute Device Report"
            window.minSize = NSSize(width: 900, height: 600)
            window.setContentSize(NSSize(width: 1200, height: 700))
        }
        
        // Make view accept key events for ESC handling
        view.window?.makeFirstResponder(self)
    }
    
    // MARK: - Key Event Handling
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        // Handle ESC key to close the sheet
        if event.keyCode == 53 { // ESC key code
            closeSheet(self)
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Setup Methods
    
    /// Configures the table view with appropriate columns and delegates
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        // Configure table appearance
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = true
        tableView.allowsColumnSelection = false
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = [.solidVerticalGridLineMask, .solidHorizontalGridLineMask]
        
        // Setup column sorting
        setupColumnSorting()
    }
    
    /// Sets up column sorting for all table columns
    private func setupColumnSorting() {
        for column in tableView.tableColumns {
            let sortDescriptor = NSSortDescriptor(key: column.identifier.rawValue, ascending: true)
            column.sortDescriptorPrototype = sortDescriptor
        }
    }
    
    /// Configures the user interface elements
    private func setupUI() {
        // Set script name
        if let scriptData = scriptData,
           let displayName = scriptData["displayName"] as? String,
           let createDateString = scriptData["createdDateTime"] as? String,
           let lastModifiedDateString = scriptData["lastModifiedDateTime"] as? String {
            scriptNameLabel.stringValue = "Device Report for: \(displayName)"
            dateCreatedLabel.stringValue = "\(createDateString.formatIntuneDate())"
            dateModifiedLabel.stringValue = "\(lastModifiedDateString.formatIntuneDate())"
        } else {
            scriptNameLabel.stringValue = "Device Report for Custom Attribute"
            dateCreatedLabel.stringValue = "Not Available"
            dateModifiedLabel.stringValue = "Not Available"
        }
        
        // Initial UI state
        summaryLabel.stringValue = "Loading device run states..."
        refreshButton.isEnabled = false
        exportButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
    }
    
    /// Sets up the pie chart for script execution status visualization
    private func setupPieChart() {
        guard let pieChartView = pieChartView else { return }
        
        // Create custom pie chart view
        installationStatusPieChart = InstallationStatusPieChartView(frame: pieChartView.bounds)
        installationStatusPieChart?.autoresizingMask = [.width, .height]
        
        // Add to container view
        pieChartView.addSubview(installationStatusPieChart!)
    }
    
    /// Updates the pie chart with current script execution status data
    private func updatePieChart() {
        guard let pieChart = installationStatusPieChart else { return }
        
        let totalDevices = deviceRunStates.count
        let successCount = deviceRunStates.filter { ($0["runState"] as? String) == "success" }.count
        let failureCount = deviceRunStates.filter { 
            let state = $0["runState"] as? String ?? ""
            return state == "fail" || state == "scriptError"
        }.count
        let pendingCount = deviceRunStates.filter { ($0["runState"] as? String) == "pending" }.count
        
        // Update pie chart data
        pieChart.updateData(
            installed: successCount,
            failed: failureCount,
            pending: pendingCount,
            notApplicable: 0, // Custom attributes don't have "not applicable" state
            total: totalDevices,
            labels: (installed: "Success", failed: "Failed", pending: "Pending", notApplicable: "")
        )
    }
    
    // MARK: - Data Loading
    
    /// Loads device run states from Microsoft Graph via XPC
    private func loadDeviceRunStates() {
        guard let scriptData = scriptData,
              let scriptId = scriptData["id"] as? String else {
            showError("No script ID available for loading device run states")
            return
        }
        
        XPCManager.shared.getCustomAttributeShellScriptDeviceRunStates(scriptId: scriptId) { [weak self] deviceStates in
            DispatchQueue.main.async {
                self?.handleDeviceRunStatesResponse(deviceStates)
            }
        }
    }
    
    /// Handles the response from the device run states API call
    /// - Parameter deviceStates: Array of device run state dictionaries or nil on failure
    private func handleDeviceRunStatesResponse(_ deviceStates: [[String: Any]]?) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
        refreshButton.isEnabled = true
        
        if let deviceStates = deviceStates {
            self.deviceRunStates = deviceStates
            self.filteredDeviceRunStates = deviceStates
            updateSummaryLabel()
            updatePieChart()
            exportButton.isEnabled = !deviceStates.isEmpty
            tableView.reloadData()
        } else {
            showError("Failed to load device run states. Please check your connection and permissions.")
            summaryLabel.stringValue = "Failed to load device data"
        }
    }
    
    /// Updates the summary label with execution statistics
    private func updateSummaryLabel() {
        let totalDevices = deviceRunStates.count
        let successCount = deviceRunStates.filter { ($0["runState"] as? String) == "success" }.count
        let failureCount = deviceRunStates.filter { 
            let state = $0["runState"] as? String ?? ""
            return state == "fail" || state == "scriptError"
        }.count
        let pendingCount = deviceRunStates.filter { ($0["runState"] as? String) == "pending" }.count
        
        summaryLabel.stringValue = "Total: \(totalDevices) devices | Success: \(successCount) | Failures: \(failureCount) | Pending: \(pendingCount)"
    }
    
    // MARK: - Actions
    
    /// Refreshes the device run states data
    @IBAction func refreshData(_ sender: NSButton) {
        refreshButton.isEnabled = false
        exportButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        summaryLabel.stringValue = "Refreshing device run states..."
        
        loadDeviceRunStates()
    }
    
    /// Exports the device run states data to CSV
    @IBAction func exportData(_ sender: NSButton) {
        exportToCSV()
    }
    
    /// Closes the reporting sheet
    @IBAction func closeSheet(_ sender: Any) {
        dismiss(self)
    }
    
    /// Opens the selected app in the Intune web console
    @IBAction func openInIntuneButtonClicked(_ sender: NSButton) {
        guard let scriptData = scriptData,
              let scriptId = scriptData["id"] as? String,
              let scriptDisplayName = scriptData["displayName"] as? String else {
            showError("No app ID available for Intune console link")
            return
        }
        
        openAppInIntuneConsole(scriptId: scriptId, scriptDisplayName: scriptDisplayName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "Unknown")
    }
    
    /// Opens the specified app in the Intune web console using the default browser
    /// - Parameter appId: The app GUID to open in the console
    private func openAppInIntuneConsole(scriptId: String, scriptDisplayName: String) {
        let intuneURL = "https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/ConfigureCustomAttributesPolicyMenuBladeViewModel/~/deviceExecutionStatus/id/\(scriptId)/displayName/\(scriptDisplayName)"
        
        guard let url = URL(string: intuneURL) else {
            showError("Failed to create valid Intune console URL")
            return
        }
        
        NSWorkspace.shared.open(url)
        Logger.info("Opened app \(scriptId) in Intune console: \(intuneURL)", category: .core)
    }

    // MARK: - Export Functionality
    
    /// Exports device run states data to CSV format
    private func exportToCSV() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Device Run States"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        
        // Generate default filename
        let scriptName = (scriptData?["displayName"] as? String ?? "CustomAttribute").replacingOccurrences(of: " ", with: "")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        savePanel.nameFieldStringValue = "\(scriptName)_DeviceReport_\(timestamp).csv"
        
        savePanel.begin { [weak self] response in
            if response == .OK, let url = savePanel.url {
                self?.writeCSVFile(to: url)
            }
        }
    }
    
    /// Writes device run states data to CSV file
    /// - Parameter url: The file URL to write to
    private func writeCSVFile(to url: URL) {
        var csvContent = "Device Name,Device ID,User Principal Name,User ID,OS Version,Run State,Result Message,Last Update,Error Code,Error Description\n"
        
        for deviceState in deviceRunStates {
            let deviceInfo = deviceState["managedDevice"] as? [String: Any] ?? [:]
            
            let deviceName = csvEscaped(deviceInfo["deviceName"] as? String ?? "Unknown")
            let deviceID = csvEscaped(deviceInfo["id"] as? String ?? "Unknown")
            let userPrincipalName = csvEscaped(deviceInfo["userPrincipalName"] as? String ?? "")
            let userID = csvEscaped(deviceInfo["userId"] as? String ?? "")
            let osVersion = csvEscaped(deviceInfo["osVersion"] as? String ?? "")
            let runState = csvEscaped(deviceState["runState"] as? String ?? "unknown")
            let resultMessage = csvEscaped(deviceState["resultMessage"] as? String ?? "")
            let lastUpdate = csvEscaped((deviceState["lastStateUpdateDateTime"] as? String ?? "").formatIntuneDate())
            let errorCode = csvEscaped(String(deviceState["errorCode"] as? Int ?? 0))
            let errorDescription = csvEscaped(deviceState["errorDescription"] as? String ?? "")
            
            csvContent += "\(deviceName),\(deviceID),\(userPrincipalName),\(userID),\(osVersion),\(runState),\(resultMessage),\(lastUpdate),\(errorCode),\(errorDescription)\n"
        }
        
        do {
            try csvContent.write(to: url, atomically: true, encoding: .utf8)
            showSuccess("Device report exported successfully to \(url.lastPathComponent)")
        } catch {
            showError("Failed to export device report: \(error.localizedDescription)")
        }
    }
    
    /// Escapes a string for CSV format
    /// - Parameter string: The string to escape
    /// - Returns: CSV-safe string with quotes and escaping
    private func csvEscaped(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    
    // MARK: - Helper Methods
    
    /// Displays an error alert
    /// - Parameter message: The error message to display
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Error"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Displays a success alert
    /// - Parameter message: The success message to display
    private func showSuccess(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Success"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Configures the view controller with script data
    /// - Parameter scriptData: Dictionary containing script information
    func configure(with scriptData: [String: Any]) {
        self.scriptData = scriptData
    }
}

// MARK: - NSTableViewDataSource

extension CustomAttributeReportingViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredDeviceRunStates.count
    }
}

// MARK: - NSTableViewDelegate

extension CustomAttributeReportingViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn,
              let cell = tableView.makeView(withIdentifier: column.identifier, owner: self) as? NSTableCellView,
              row < filteredDeviceRunStates.count else {
            return nil
        }
        
        let deviceState = filteredDeviceRunStates[row]
        let deviceInfo = deviceState["managedDevice"] as? [String: Any] ?? [:]
        
        switch column.identifier.rawValue {
        case "deviceName":
            cell.textField?.stringValue = deviceInfo["deviceName"] as? String ?? "Unknown Device"
            
        case "userPrincipalName":
            cell.textField?.stringValue = deviceInfo["userPrincipalName"] as? String ?? ""
            
        case "osVersion":
            cell.textField?.stringValue = deviceInfo["osVersion"] as? String ?? ""
            
        case "runState":
            let runState = deviceState["runState"] as? String ?? "unknown"
            cell.textField?.stringValue = runState.capitalized
            
            // Color code the run state
            switch runState.lowercased() {
            case "success":
                cell.textField?.textColor = NSColor.systemGreen
            case "fail", "scripterror":
                cell.textField?.textColor = NSColor.systemRed
            case "pending":
                cell.textField?.textColor = NSColor.systemOrange
            default:
                cell.textField?.textColor = NSColor.labelColor
            }
            
        case "resultMessage":
            let message = deviceState["resultMessage"] as? String ?? ""
            cell.textField?.stringValue = message.isEmpty ? "No output" : message
            cell.textField?.toolTip = message // Full message in tooltip
            
        case "lastStateUpdateDateTime":
            let dateString = deviceState["lastStateUpdateDateTime"] as? String ?? ""
            cell.textField?.stringValue = dateString.formatIntuneDate()
            
        default:
            cell.textField?.stringValue = ""
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }
        
        currentSortDescriptor = sortDescriptor
        sortDeviceRunStates(by: sortDescriptor)
        tableView.reloadData()
    }
    
    /// Sorts the device run states array by the given sort descriptor
    /// - Parameter sortDescriptor: The sort descriptor to apply
    private func sortDeviceRunStates(by sortDescriptor: NSSortDescriptor) {
        filteredDeviceRunStates.sort { deviceState1, deviceState2 in
            let deviceInfo1 = deviceState1["managedDevice"] as? [String: Any] ?? [:]
            let deviceInfo2 = deviceState2["managedDevice"] as? [String: Any] ?? [:]
            
            var value1: Any?
            var value2: Any?
            
            switch sortDescriptor.key {
            case "deviceName":
                value1 = deviceInfo1["deviceName"] as? String ?? ""
                value2 = deviceInfo2["deviceName"] as? String ?? ""
            case "userPrincipalName":
                value1 = deviceInfo1["userPrincipalName"] as? String ?? ""
                value2 = deviceInfo2["userPrincipalName"] as? String ?? ""
            case "osVersion":
                value1 = deviceInfo1["osVersion"] as? String ?? ""
                value2 = deviceInfo2["osVersion"] as? String ?? ""
            case "runState":
                value1 = deviceState1["runState"] as? String ?? ""
                value2 = deviceState2["runState"] as? String ?? ""
            case "resultMessage":
                value1 = deviceState1["resultMessage"] as? String ?? ""
                value2 = deviceState2["resultMessage"] as? String ?? ""
            case "lastStateUpdateDateTime":
                value1 = deviceState1["lastStateUpdateDateTime"] as? String ?? ""
                value2 = deviceState2["lastStateUpdateDateTime"] as? String ?? ""
            default:
                return false
            }
            
            if let string1 = value1 as? String, let string2 = value2 as? String {
                let result = string1.localizedCaseInsensitiveCompare(string2)
                return sortDescriptor.ascending ? (result == .orderedAscending) : (result == .orderedDescending)
            }
            
            return false
        }
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 20.0 // Standard row height
    }
}
