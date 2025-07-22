//
//  ConfigReportingViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/14/25.
//

import Cocoa

/// View controller for displaying detailed device configuration profile deployment status for Intune profiles
/// Provides comprehensive reporting of profile deployment across assigned devices with sortable columns
/// and detailed deployment information including compliance status, errors, and user data
class ConfigReportingViewController: NSViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var profileNameLabel: NSTextField!
    @IBOutlet weak var summaryLabel: NSTextField!
    @IBOutlet weak var dateCreatedLabel: NSTextField!
    @IBOutlet weak var dateModifiedLabel: NSTextField!
    @IBOutlet weak var pieChartView: NSView!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var exportButton: NSButton!
    @IBOutlet weak var openInIntuneButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    // MARK: - Properties
    
    /// The Intune configuration profile data for which to display device deployment status
    var profileData: [String: Any]?
    
    /// Array of device deployment status dictionaries from Microsoft Graph reports API
    var deviceDeploymentStatus: [[String: Any]] = []
    
    /// Filtered and sorted device deployment status for table display
    var filteredDeviceDeploymentStatus: [[String: Any]] = []
    
    /// Current sort descriptor for table columns
    var currentSortDescriptor: NSSortDescriptor?
    
    /// Custom pie chart view for displaying deployment status
    private var deploymentStatusPieChart: InstallationStatusPieChartView?
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupUI()
        setupPieChart()
        loadDeviceDeploymentStatus()
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
            window.title = "Intune Configuration Profile Deployment Report"
            window.minSize = NSSize(width: 1000, height: 600)
            window.setContentSize(NSSize(width: 1300, height: 700))
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
    
    /// Sets up the pie chart view for deployment status visualization
    private func setupPieChart() {
        guard let pieChartView = pieChartView else { return }
        
        // Create custom pie chart view
        deploymentStatusPieChart = InstallationStatusPieChartView(frame: pieChartView.bounds)
        deploymentStatusPieChart?.autoresizingMask = [.width, .height]
        
        // Add to container view
        pieChartView.addSubview(deploymentStatusPieChart!)
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
        // Set profile name
        if let profileData = profileData,
           let displayName = profileData["displayName"] as? String,
           let createDateString = profileData["createdDateTime"] as? String,
           let lastModifiedDateString = profileData["lastModifiedDateTime"] as? String {
            profileNameLabel.stringValue = "Deployment Report for: \(displayName)"
            dateCreatedLabel.stringValue = "\(createDateString.formatIntuneDate())"
            dateModifiedLabel.stringValue = "\(lastModifiedDateString.formatIntuneDate())"

        } else {
            profileNameLabel.stringValue = "Deployment Report for Configuration Profile"
            dateCreatedLabel.stringValue = "Not Available"
            dateModifiedLabel.stringValue = "Not Available"
        }

        // Initial UI state
        summaryLabel.stringValue = "Loading device deployment status..."
        refreshButton.isEnabled = false
        exportButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
    }
    
    // MARK: - Data Loading
    
    /// Loads device deployment status from Microsoft Graph via XPC
    private func loadDeviceDeploymentStatus() {
        guard let profileData = profileData,
              let profileId = profileData["id"] as? String else {
            showError("No profile ID available for loading device deployment status")
            return
        }
        
        // Use configuration profile reporting endpoint for all profile types
        // Note: Compliance policy reporting API is not available/enabled in this environment
        XPCManager.shared.getDeviceConfigProfileDeploymentStatusReport(profileId: profileId) { [weak self] deploymentStatus in
            DispatchQueue.main.async {
                self?.handleDeviceDeploymentStatusResponse(deploymentStatus)
                print("Profile Report:", deploymentStatus ?? [])
            }
        }
    }
    
    /// Handles the response from the device deployment status API call
    /// - Parameter deploymentStatus: Array of device deployment status dictionaries or nil on failure
    private func handleDeviceDeploymentStatusResponse(_ deploymentStatus: [[String: Any]]?) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
        refreshButton.isEnabled = true
        
        if let deploymentStatus = deploymentStatus {
            self.deviceDeploymentStatus = deploymentStatus
            self.filteredDeviceDeploymentStatus = deploymentStatus
            updateSummaryLabel()
            updatePieChart()
            exportButton.isEnabled = !deploymentStatus.isEmpty
            tableView.reloadData()
        } else {
            showError("Failed to load device deployment status. Please check your connection and permissions.")
            summaryLabel.stringValue = "Failed to load deployment data"
        }
    }
    
    /// Updates the summary label with deployment statistics
    private func updateSummaryLabel() {
        let totalDevices = deviceDeploymentStatus.count
        
        let succeededCount = deviceDeploymentStatus.filter { 
            let reportStatusLoc = $0["ReportStatus_loc"] as? String ?? ""
            let reportStatus = $0["ReportStatus"] as? String ?? ""
            let status = !reportStatusLoc.isEmpty ? reportStatusLoc : reportStatus
            return status.lowercased().contains("succeed") || status.lowercased().contains("compliant")
        }.count
        
        let failedCount = deviceDeploymentStatus.filter { 
            let reportStatusLoc = $0["ReportStatus_loc"] as? String ?? ""
            let reportStatus = $0["ReportStatus"] as? String ?? ""
            let status = !reportStatusLoc.isEmpty ? reportStatusLoc : reportStatus
            return status.lowercased().contains("fail") || status.lowercased().contains("error")
        }.count
        
        let notApplicableCount = deviceDeploymentStatus.filter { 
            let reportStatusLoc = $0["ReportStatus_loc"] as? String ?? ""
            let reportStatus = $0["ReportStatus"] as? String ?? ""
            let status = !reportStatusLoc.isEmpty ? reportStatusLoc : reportStatus
            return status.lowercased().contains("not applicable") || status.lowercased().contains("notapplicable")
        }.count
        
        let otherCount = totalDevices - succeededCount - failedCount - notApplicableCount
        
        summaryLabel.stringValue = "Total: \(totalDevices) devices | Succeeded: \(succeededCount) | Failed: \(failedCount) | Not Applicable: \(notApplicableCount) | Other: \(otherCount)"
    }
    
    /// Updates the pie chart with current deployment status data
    private func updatePieChart() {
        guard let pieChart = deploymentStatusPieChart else { return }
        
        let totalDevices = deviceDeploymentStatus.count
        
        let succeededCount = deviceDeploymentStatus.filter { 
            let reportStatusLoc = $0["ReportStatus_loc"] as? String ?? ""
            let reportStatus = $0["ReportStatus"] as? String ?? ""
            let status = !reportStatusLoc.isEmpty ? reportStatusLoc : reportStatus
            return status.lowercased().contains("succeed") || status.lowercased().contains("compliant")
        }.count
        
        let failedCount = deviceDeploymentStatus.filter { 
            let reportStatusLoc = $0["ReportStatus_loc"] as? String ?? ""
            let reportStatus = $0["ReportStatus"] as? String ?? ""
            let status = !reportStatusLoc.isEmpty ? reportStatusLoc : reportStatus
            return status.lowercased().contains("fail") || status.lowercased().contains("error")
        }.count
        
        let notApplicableCount = deviceDeploymentStatus.filter { 
            let reportStatusLoc = $0["ReportStatus_loc"] as? String ?? ""
            let reportStatus = $0["ReportStatus"] as? String ?? ""
            let status = !reportStatusLoc.isEmpty ? reportStatusLoc : reportStatus
            return status.lowercased().contains("not applicable") || status.lowercased().contains("notapplicable")
        }.count
        
        let otherCount = totalDevices - succeededCount - failedCount - notApplicableCount
        
        // Update pie chart data - map deployment statuses to chart categories
        pieChart.updateData(
            installed: succeededCount,
            failed: failedCount,
            pending: otherCount,
            notApplicable: notApplicableCount,
            total: totalDevices,
            labels: (installed: "Succeeded", failed: "Failed", pending: "Other", notApplicable: "Not Applicable")
        )
    }
    
    // MARK: - Button Actions
    
    @IBAction func refreshButtonClicked(_ sender: NSButton) {
        loadDeviceDeploymentStatus()
    }
    
    @IBAction func exportButtonClicked(_ sender: NSButton) {
        exportDeploymentStatusToCSV()
    }
    
    @IBAction func openInIntuneButtonClicked(_ sender: NSButton) {
        guard let profileData = profileData,
              let profileId = profileData["id"] as? String else {
            showError("No profile ID available for opening in Intune")
            return
        }
        
        // Construct Intune portal URL for configuration profiles
        let intuneURL = "https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DeviceConfigurationMenuBlade/~/configurationProfiles"
        
        if let url = URL(string: intuneURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @IBAction func closeSheet(_ sender: Any) {
        if let window = view.window {
            window.sheetParent?.endSheet(window)
        }
    }
    
    // MARK: - Export Functionality
    
    /// Exports the device deployment status data to a CSV file
    private func exportDeploymentStatusToCSV() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "ConfigProfile_Deployment_Report"
        
        let profileName = profileData?["displayName"] as? String ?? "Unknown_Profile"
        let sanitizedProfileName = profileName.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        savePanel.nameFieldStringValue = "ConfigProfile_\(sanitizedProfileName)_Report"
        
        savePanel.beginSheetModal(for: view.window!) { response in
            if response == .OK, let url = savePanel.url {
                self.writeCSVFile(to: url)
            }
        }
    }
    
    /// Writes the deployment status data to a CSV file
    /// - Parameter url: The file URL to write to
    private func writeCSVFile(to url: URL) {
        var csvContent = "Device Name,Intune Device ID,User Principal Name,User ID,Report Status,Policy Type,Platform,Manufacturer,Model,Last Reported,Policy Status (Numeric)\n"
        
        for deviceStatus in deviceDeploymentStatus {
            let deviceName = deviceStatus["DeviceName"] as? String ?? ""
            let deviceId = deviceStatus["IntuneDeviceId"] as? String ?? ""
            let userPrincipalName = deviceStatus["UPN"] as? String ?? ""
            let userId = deviceStatus["UserId"] as? String ?? ""

            // Prioritize localized values
            let reportStatusLoc = deviceStatus["ReportStatus_loc"] as? String ?? ""
            let reportStatus = deviceStatus["ReportStatus"] as? String ?? ""
            let finalReportStatus = !reportStatusLoc.isEmpty ? reportStatusLoc : reportStatus
            
            let policyTypeLoc = deviceStatus["UnifiedPolicyType_loc"] as? String ?? ""
            let policyType = deviceStatus["UnifiedPolicyType"] as? String ?? ""
            let finalPolicyType = !policyTypeLoc.isEmpty ? policyTypeLoc : policyType
            
            let platformLoc = deviceStatus["UnifiedPolicyPlatformType_loc"] as? String ?? ""
            let platform = deviceStatus["UnifiedPolicyPlatformType"] as? String ?? ""
            let finalPlatform = !platformLoc.isEmpty ? platformLoc : platform
            
            let manufacturer = deviceStatus["Manufacturer"] as? String ?? ""
            let model = deviceStatus["Model"] as? String ?? ""
            let lastReported = (deviceStatus["PspdpuLastModifiedTimeUtc"] as? String ?? "").formatIntuneDate()
            let policyStatusNumeric = deviceStatus["PolicyStatus"] as? Int ?? 0
            
            // Escape commas and quotes in CSV data
            let escapedDeviceName = escapeCSVField(deviceName)
            let escapedDeviceId = escapeCSVField(deviceId)
            let escapedUserPrincipalName = escapeCSVField(userPrincipalName)
            let escapedUserId = escapeCSVField(userId)
            let escapedReportStatus = escapeCSVField(finalReportStatus)
            let escapedPolicyType = escapeCSVField(finalPolicyType)
            let escapedPlatform = escapeCSVField(finalPlatform)
            let escapedManufacturer = escapeCSVField(manufacturer)
            let escapedModel = escapeCSVField(model)
            let escapedLastReported = escapeCSVField(lastReported)
            
            csvContent += "\(escapedDeviceName),\(escapedDeviceId),\(escapedUserPrincipalName),\(escapedUserId),\(escapedReportStatus),\(escapedPolicyType),\(escapedPlatform),\(escapedManufacturer),\(escapedModel),\(escapedLastReported),\(policyStatusNumeric)\n"
        }
        
        do {
            try csvContent.write(to: url, atomically: true, encoding: .utf8)
            Logger.log("Configuration profile deployment report exported successfully to: \(url.path)", category: .core, toUserDirectory: true)
        } catch {
            showError("Failed to export deployment report: \(error.localizedDescription)")
            Logger.error("Failed to export configuration profile deployment report: \(error.localizedDescription)", category: .core, toUserDirectory: true)
        }
    }
    
    /// Escapes a field for CSV format
    /// - Parameter field: The field to escape
    /// - Returns: The escaped field
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
    
    // MARK: - Helper Methods
    
    /// Shows an error alert to the user
    /// - Parameter message: The error message to display
    private func showError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            
            if let window = self?.view.window {
                alert.beginSheetModal(for: window)
            } else {
                alert.runModal()
            }
        }
    }
    
    /// Maps compliance status to a user-friendly display string
    /// - Parameter status: The compliance status from the API
    /// - Returns: A user-friendly status string
    private func friendlyComplianceStatus(_ status: String) -> String {
        let lowercaseStatus = status.lowercased()
        
        if lowercaseStatus.contains("succeed") {
            return "✅ Succeeded"
        } else if lowercaseStatus.contains("compliant") {
            return "✅ Compliant"
        } else if lowercaseStatus.contains("fail") {
            return "❌ Failed"
        } else if lowercaseStatus.contains("error") {
            return "⚠️ Error"
        } else if lowercaseStatus.contains("not applicable") || lowercaseStatus.contains("notapplicable") {
            return "➖ Not Applicable"
        } else if lowercaseStatus.contains("pending") {
            return "⏳ Pending"
        } else if lowercaseStatus.contains("inprogress") || lowercaseStatus.contains("in progress") {
            return "🔄 In Progress"
        } else if lowercaseStatus.contains("unknown") {
            return "❓ Unknown"
        } else {
            return status.isEmpty ? "❓ Unknown" : status
        }
    }
    
    /// Interprets numeric PolicyStatus values into user-friendly strings
    /// Based on official PowerShell source mapping from Microsoft
    /// - Parameter policyStatus: The numeric policy status from the API
    /// - Returns: A user-friendly interpretation of the policy status
    private func interpretPolicyStatus(_ policyStatus: Int) -> String {
        switch policyStatus {
        case 1:
            return "➖ Not Applicable"
        case 2:
            return "✅ Succeeded (User)"
        case 3:
            return "✅ Succeeded (Device)"
        case 4:
            return "❌ Error (Device)"
        case 5:
            return "❌ Error (User)"
        case 6:
            return "⚠️ Conflict"
        default:
            return "❓ Unknown (\(policyStatus))"
        }
    }
    
    /// Configures the view controller with profile data
    /// - Parameter profileData: Dictionary containing app information
    func configure(with profileData: [String: Any]) {
        self.profileData = profileData
        print(profileData)
    }

}

// MARK: - NSTableViewDataSource

extension ConfigReportingViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredDeviceDeploymentStatus.count
    }
}

// MARK: - NSTableViewDelegate

extension ConfigReportingViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredDeviceDeploymentStatus.count else { return nil }
        
        let deviceStatus = filteredDeviceDeploymentStatus[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""
        
        // Create or reuse cell view
        let cellIdentifier = NSUserInterfaceItemIdentifier("ConfigDeploymentCell")
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView
        
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = cellIdentifier
            
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.cell?.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            cellView?.addSubview(textField)
            cellView?.textField = textField
            
            // Set up constraints
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }
        
        // Configure cell content based on column
        switch identifier {
        case "DeviceNameColumn":
            cellView?.textField?.stringValue = deviceStatus["DeviceName"] as? String ?? "Unknown"
            cellView?.textField?.toolTip = deviceStatus["IntuneDeviceId"] as? String ?? "Unknown"

        case "UserPrincipalNameColumn":
            cellView?.textField?.stringValue = deviceStatus["UPN"] as? String ?? "Unknown"
            cellView?.textField?.toolTip = deviceStatus["UserId"] as? String ?? "Unknown"

        case "ReportStatusColumn":
            // Prioritize localized version if available
            let reportStatusLoc = deviceStatus["ReportStatus_loc"] as? String ?? ""
            let reportStatus = deviceStatus["ReportStatus"] as? String ?? ""
            let status = !reportStatusLoc.isEmpty ? reportStatusLoc : reportStatus
            cellView?.textField?.stringValue = friendlyComplianceStatus(status)
            
        case "PolicyTypeColumn":
            // Prioritize localized version if available
            let policyTypeLoc = deviceStatus["UnifiedPolicyType_loc"] as? String ?? ""
            let policyType = deviceStatus["UnifiedPolicyType"] as? String ?? ""
            let type = !policyTypeLoc.isEmpty ? policyTypeLoc : policyType
            cellView?.textField?.stringValue = type
            
        case "PlatformColumn":
            // Prioritize localized version if available
            let platformLoc = deviceStatus["UnifiedPolicyPlatformType_loc"] as? String ?? ""
            let platform = deviceStatus["UnifiedPolicyPlatformType"] as? String ?? ""
            let platformType = !platformLoc.isEmpty ? platformLoc : platform
            cellView?.textField?.stringValue = platformType
            
        case "ManufacturerColumn":
            cellView?.textField?.stringValue = deviceStatus["Manufacturer"] as? String ?? "Unknown"
            
        case "ModelColumn":
            cellView?.textField?.stringValue = deviceStatus["Model"] as? String ?? "Unknown"
            
        case "LastReportedColumn":
            let lastReported = deviceStatus["PspdpuLastModifiedTimeUtc"] as? String ?? ""
            cellView?.textField?.stringValue = lastReported.formatIntuneDate()
            
        case "PolicyStatusColumn":
            // PolicyStatus is numeric - provide meaningful interpretation
            let policyStatusNum = deviceStatus["PolicyStatus"] as? Int ?? 0
            cellView?.textField?.stringValue = interpretPolicyStatus(policyStatusNum)
            
        default:
            cellView?.textField?.stringValue = ""
        }
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }
        
        currentSortDescriptor = sortDescriptor
        
        filteredDeviceDeploymentStatus.sort { item1, item2 in
            let key = sortDescriptor.key ?? ""
            let ascending = sortDescriptor.ascending
            
            var value1: String = ""
            var value2: String = ""
            
            switch key {
            case "DeviceNameColumn":
                value1 = item1["DeviceName"] as? String ?? ""
                value2 = item2["DeviceName"] as? String ?? ""
            case "UserPrincipalNameColumn":
                value1 = item1["UPN"] as? String ?? ""
                value2 = item2["UPN"] as? String ?? ""
            case "ReportStatusColumn":
                let reportStatusLoc1 = item1["ReportStatus_loc"] as? String ?? ""
                let reportStatus1 = item1["ReportStatus"] as? String ?? ""
                value1 = !reportStatusLoc1.isEmpty ? reportStatusLoc1 : reportStatus1
                
                let reportStatusLoc2 = item2["ReportStatus_loc"] as? String ?? ""
                let reportStatus2 = item2["ReportStatus"] as? String ?? ""
                value2 = !reportStatusLoc2.isEmpty ? reportStatusLoc2 : reportStatus2
            case "PolicyTypeColumn":
                let policyTypeLoc1 = item1["UnifiedPolicyType_loc"] as? String ?? ""
                let policyType1 = item1["UnifiedPolicyType"] as? String ?? ""
                value1 = !policyTypeLoc1.isEmpty ? policyTypeLoc1 : policyType1
                
                let policyTypeLoc2 = item2["UnifiedPolicyType_loc"] as? String ?? ""
                let policyType2 = item2["UnifiedPolicyType"] as? String ?? ""
                value2 = !policyTypeLoc2.isEmpty ? policyTypeLoc2 : policyType2
            case "PlatformColumn":
                let platformLoc1 = item1["UnifiedPolicyPlatformType_loc"] as? String ?? ""
                let platform1 = item1["UnifiedPolicyPlatformType"] as? String ?? ""
                value1 = !platformLoc1.isEmpty ? platformLoc1 : platform1
                
                let platformLoc2 = item2["UnifiedPolicyPlatformType_loc"] as? String ?? ""
                let platform2 = item2["UnifiedPolicyPlatformType"] as? String ?? ""
                value2 = !platformLoc2.isEmpty ? platformLoc2 : platform2
            case "ManufacturerColumn":
                value1 = item1["Manufacturer"] as? String ?? ""
                value2 = item2["Manufacturer"] as? String ?? ""
            case "ModelColumn":
                value1 = item1["Model"] as? String ?? ""
                value2 = item2["Model"] as? String ?? ""
            case "LastReportedColumn":
                value1 = item1["PspdpuLastModifiedTimeUtc"] as? String ?? ""
                value2 = item2["PspdpuLastModifiedTimeUtc"] as? String ?? ""
            case "PolicyStatusColumn":
                let policyStatus1 = item1["PolicyStatus"] as? Int ?? 0
                let policyStatus2 = item2["PolicyStatus"] as? Int ?? 0
                return ascending ? policyStatus1 < policyStatus2 : policyStatus1 > policyStatus2
            default:
                return false
            }
            
            let comparison = value1.localizedCaseInsensitiveCompare(value2)
            return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
        
        tableView.reloadData()
    }
}
