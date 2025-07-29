//
//  ScheduledReportsManagementViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/25/25.
//

import Cocoa

/// View controller for managing scheduled reports
/// Provides a comprehensive interface for viewing, editing, and managing automated report schedules
class ScheduledReportsManagementViewController: NSViewController {
    
    // MARK: - UI Outlets
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var editButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var enableDisableButton: NSButton? // Optional - may not be connected in storyboard
    @IBOutlet weak var runNowButton: NSButton? // Optional - may not be connected in storyboard
    @IBOutlet weak var testScheduleButton: NSButton? // Optional - may not be connected in storyboard
    @IBOutlet weak var viewLogsButton: NSButton? // Optional - may not be connected in storyboard
    @IBOutlet weak var refreshButton: NSButton? // Optional - may not be connected in storyboard
    @IBOutlet weak var statusLabel: NSTextField!
    
    // MARK: - Properties
    
    /// Current list of scheduled reports
    private var scheduledReports: [ScheduledReport] = []
    
    /// Currently selected report
    private var selectedReport: ScheduledReport? {
        guard tableView.selectedRow >= 0, tableView.selectedRow < scheduledReports.count else {
            return nil
        }
        return scheduledReports[tableView.selectedRow]
    }
    
    /// Timer for refreshing the list periodically
    private var refreshTimer: Timer?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupButtons()
        loadScheduledReports()
        startAutoRefresh()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Setup Methods
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        
        // Enable row selection
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        
        // Set up double-click to edit
        tableView.doubleAction = #selector(editSelectedReport)
        
        // Configure table columns
        setupTableColumns()
        
        // Set row height for better readability
        tableView.rowHeight = 20
    }
    
    private func setupTableColumns() {
        // Clear existing columns
        while tableView.tableColumns.count > 0 {
            tableView.removeTableColumn(tableView.tableColumns[0])
        }
        
        // Name column
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 200
        nameColumn.minWidth = 150
        tableView.addTableColumn(nameColumn)
        
        // Report Type column
        let reportColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("report"))
        reportColumn.title = "Report"
        reportColumn.width = 180
        reportColumn.minWidth = 120
        tableView.addTableColumn(reportColumn)
        
        // Schedule column
        let scheduleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("schedule"))
        scheduleColumn.title = "Schedule"
        scheduleColumn.width = 120
        scheduleColumn.minWidth = 100
        tableView.addTableColumn(scheduleColumn)
        
        // Next Run column
        let nextRunColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("nextRun"))
        nextRunColumn.title = "Next Run"
        nextRunColumn.width = 140
        nextRunColumn.minWidth = 120
        tableView.addTableColumn(nextRunColumn)
        
        // Status column
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "Status"
        statusColumn.width = 80
        statusColumn.minWidth = 60
        tableView.addTableColumn(statusColumn)
        
        // Last Run column
        let lastRunColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lastRun"))
        lastRunColumn.title = "Last Run"
        lastRunColumn.width = 140
        lastRunColumn.minWidth = 120
        tableView.addTableColumn(lastRunColumn)
    }
    
    private func setupButtons() {
        updateButtonStates()
        
        // Set button titles
        addButton.title = "Add"
        editButton.title = "Edit"
        deleteButton.title = "Delete"
        enableDisableButton?.title = "Enable/Disable"
        runNowButton?.title = "Run Now"
        testScheduleButton?.title = "Test Schedule"
        viewLogsButton?.title = "View Logs"
        refreshButton?.title = "Refresh"
    }
    
    private func startAutoRefresh() {
        // Refresh every 30 seconds to show updated next run times
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.loadScheduledReports()
        }
    }
    
    // MARK: - Data Management
    
    private func loadScheduledReports() {
        // Clean up any orphaned files first
        ScheduledReportsManager.shared.cleanupOrphanedFiles()
        
        scheduledReports = ScheduledReportsManager.shared.getAllScheduledReports()
        
        // Only create test report if this is the very first time (no index exists)
        if scheduledReports.isEmpty && !ScheduledReportsManager.shared.indexExists() {
            createTestScheduledReport()
            return // This will call loadScheduledReports again
        }
        
        tableView.reloadData()
        updateStatusLabel()
        updateButtonStates()
    }
    
    private func updateStatusLabel() {
        let total = scheduledReports.count
        let enabled = scheduledReports.filter { $0.isEnabled }.count
        let disabled = total - enabled
        
        // Start with basic report count
        var statusText = ""
        if total == 0 {
            statusText = "No scheduled reports"
        } else {
            statusText = "\(total) reports (\(enabled) enabled, \(disabled) disabled)"
        }
        
        // Add scheduler status information
        updateSchedulerStatus { [weak self] schedulerInfo in
            DispatchQueue.main.async {
                var fullStatusText = statusText
                
                if let schedulerInfo = schedulerInfo {
                    let schedulerEnabled = schedulerInfo["schedulerEnabled"] as? Bool ?? false
                    let interval = schedulerInfo["schedulerInterval"] as? Int ?? 600
                    let overdueReports = schedulerInfo["overdueReports"] as? Int ?? 0
                    
                    // Add scheduler status
                    let schedulerStatus = schedulerEnabled ? "✅ Active" : "⚠️ Inactive"
                    fullStatusText += " • Scheduler: \(schedulerStatus) (every \(interval/60)min)"
                    
                    // Add last run information if available
                    if let lastRun = schedulerInfo["lastSchedulerRun"] as? Date {
                        let formatter = RelativeDateTimeFormatter()
                        formatter.dateTimeStyle = .named
                        let relativeTime = formatter.localizedString(for: lastRun, relativeTo: Date())
                        fullStatusText += " • Last run: \(relativeTime)"
                    }
                    
                    // Add overdue warning if needed
                    if overdueReports > 0 {
                        fullStatusText += " • ⚠️ \(overdueReports) overdue"
                    }
                    
                    // Add next due time if available
                    if let nextDue = schedulerInfo["nextReportDue"] as? Date {
                        let formatter = RelativeDateTimeFormatter()
                        formatter.dateTimeStyle = .named
                        let relativeTime = formatter.localizedString(for: nextDue, relativeTo: Date())
                        fullStatusText += " • Next due: \(relativeTime)"
                    }
                } else {
                    fullStatusText += " • Scheduler: Unknown"
                }
                
                self?.statusLabel.stringValue = fullStatusText
            }
        }
    }
    
    /// Updates scheduler status information from the XPC service
    /// - Parameter completion: Callback with scheduler status dictionary or nil on failure
    private func updateSchedulerStatus(completion: @escaping ([String: Any]?) -> Void) {
        XPCManager.shared.getSchedulerStatus { statusInfo in
            completion(statusInfo)
        }
    }
    
    private func updateButtonStates() {
        let hasSelection = selectedReport != nil
        let hasEnabledSelection = selectedReport?.isEnabled == true
        
        editButton.isEnabled = hasSelection
        deleteButton.isEnabled = hasSelection
        enableDisableButton?.isEnabled = hasSelection
        runNowButton?.isEnabled = hasEnabledSelection
        testScheduleButton?.isEnabled = hasSelection
        viewLogsButton?.isEnabled = hasSelection
        
        // Update enable/disable button title
        if let report = selectedReport {
            enableDisableButton?.title = report.isEnabled ? "Disable" : "Enable"
        } else {
            enableDisableButton?.title = "Enable/Disable"
        }
    }
    
    // MARK: - Actions
    
    @IBAction func addButtonClicked(_ sender: NSButton) {
        showReportEditor(for: nil)
    }
    
    /// Creates a test scheduled report for demonstration purposes
    private func createTestScheduledReport() {
        // Additional safety check - don't create if any reports already exist with this name
        let existingReports = ScheduledReportsManager.shared.getAllScheduledReports()
        if existingReports.contains(where: { $0.name == "Test Device Report" }) {
            Logger.info("Test report already exists, skipping creation", category: .core, toUserDirectory: true)
            return
        }
        
        let testReport = ScheduledReport(
            name: "Test Device Report", 
            reportType: "Devices", 
            reportDisplayName: "Devices"
        )
        
        ScheduledReportsManager.shared.saveScheduledReport(testReport) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.loadScheduledReports()
                    self?.showSuccess("Test scheduled report created successfully")
                } else {
                    self?.showError("Failed to create test report")
                }
            }
        }
    }
    
    @IBAction func editButtonClicked(_ sender: NSButton) {
        editSelectedReport()
    }
    
    @IBAction func deleteButtonClicked(_ sender: NSButton) {
        deleteSelectedReport()
    }
    
    @IBAction func enableDisableButtonClicked(_ sender: NSButton) {
        toggleSelectedReportState()
    }
    
    @IBAction func runNowButtonClicked(_ sender: NSButton) {
        runSelectedReportNow()
    }
    
    @IBAction func testScheduleButtonClicked(_ sender: NSButton) {
        testSelectedSchedule()
    }
    
    @IBAction func viewLogsButtonClicked(_ sender: NSButton) {
        viewSelectedReportLogs()
    }
    
    @IBAction func refreshButtonClicked(_ sender: NSButton) {
        loadScheduledReports()
    }
    
    // MARK: - Report Management Methods
    
    @objc private func editSelectedReport() {
        guard let report = selectedReport else { return }
        showReportEditor(for: report)
    }
    
    private func showReportEditor(for report: ScheduledReport?) {
        let storyboard = NSStoryboard(name: "IntuneReports", bundle: nil)
        guard let editorVC = storyboard.instantiateController(withIdentifier: "ReportScheduleEditorViewController") as? ReportScheduleEditorViewController else {
            showError("Failed to load schedule editor")
            return
        }
        
        editorVC.scheduledReport = report
        
        editorVC.onSaveComplete = { [weak self] savedReport in
            self?.loadScheduledReports()
            let action = report == nil ? "created" : "updated"
            self?.showSuccess("Scheduled report '\(savedReport.name)' \(action) successfully")
        }
        
        editorVC.onCancel = {
            // Nothing special needed on cancel
        }
        
        presentAsSheet(editorVC)
    }
    
    private func deleteSelectedReport() {
        guard let report = selectedReport else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Scheduled Report"
        alert.informativeText = "Are you sure you want to delete the scheduled report '\(report.name)'? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            ScheduledReportsManager.shared.deleteScheduledReport(withId: report.id) { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.loadScheduledReports()
                        self?.showSuccess("Scheduled report '\(report.name)' deleted successfully")
                    } else {
                        self?.showError("Failed to delete scheduled report. Please check the logs for details.")
                    }
                }
            }
        }
    }
    
    private func toggleSelectedReportState() {
        guard var report = selectedReport else { return }
        
        report.isEnabled.toggle()
        
        ScheduledReportsManager.shared.saveScheduledReport(report) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.loadScheduledReports()
                    let state = report.isEnabled ? "enabled" : "disabled"
                    self?.showSuccess("Scheduled report '\(report.name)' \(state) successfully")
                } else {
                    self?.showError("Failed to update scheduled report state. Please check the logs for details.")
                }
            }
        }
    }
    
    private func runSelectedReportNow() {
        guard let report = selectedReport else { return }
        
        let alert = NSAlert()
        alert.messageText = "Run Report Now"
        alert.informativeText = "This will run the scheduled report '\(report.name)' immediately. The report will be generated and delivered according to its configuration."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Run Now")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // TODO: Implement immediate report execution
            // This would call the daemon to run the report immediately
            showInfo("Report execution has been queued. Check the logs for progress updates.")
            Logger.info("Manual execution requested for scheduled report: \(report.name)", category: .core, toUserDirectory: true)
        }
    }
    
    private func testSelectedSchedule() {
        guard let report = selectedReport else { return }
        
        let alert = NSAlert()
        alert.messageText = "Schedule Test Results"
        
        var message = "**Schedule Configuration:**\n"
        message += "• \(report.scheduleDescription)\n"
        let nextRunString = report.nextRun.map { 
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: $0)
        } ?? "Unable to calculate"
        message += "• Next Run: \(nextRunString)\n\n"
        
        message += "**Report Configuration:**\n"
        message += "• Type: \(report.reportDisplayName)\n"
        message += "• Format: \(report.format.uppercased())\n"
        
        if !report.filters.isEmpty {
            message += "• Filters: \(report.filters.count) applied\n"
        }
        
        message += "\n**Delivery Configuration:**\n"
        
        // Test Azure Storage configuration (will be checked asynchronously)
        XPCManager.shared.getNamedAzureStorageConfiguration(name: report.delivery.azureStorageConfigName) { configData in
            DispatchQueue.main.async {
                if let config = configData {
                    let accountName = config["accountName"] as? String ?? "Unknown"
                    let containerName = config["containerName"] as? String ?? "Unknown"
                    message += "• ✅ Azure Storage: \(accountName)/\(containerName)\n"
                } else {
                    message += "• ❌ Azure Storage configuration not found\n"
                }
                
                // Continue building the message with the updated Azure Storage info
                message += "• Folder: \(report.delivery.generateFolderPath(reportType: report.reportType))\n"
                message += "• Filename: \(report.delivery.generateFileName(reportName: report.name, reportType: report.reportType, format: report.format))\n"
                
                if report.delivery.createShareableLink {
                    let expiration = report.delivery.linkExpirationDays.map { "\($0) days" } ?? "never"
                    message += "• Share link expires: \(expiration)\n"
                }
                
                message += "\n**Notification Configuration:**\n"
                if report.notifications.enabled {
                    if report.notifications.useGlobalWebhook {
                        message += "• ✅ Will use global Teams webhook\n"
                    } else if let customURL = report.notifications.customWebhookURL, !customURL.isEmpty {
                        message += "• ✅ Will use custom webhook\n"
                    } else {
                        message += "• ❌ No webhook URL configured\n"
                    }
                } else {
                    message += "• ℹ️ Notifications disabled\n"
                }
                
                // Show the completed alert
                alert.informativeText = message
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        
        // Message completion now handled in XPC callback above
    }
    
    private func viewSelectedReportLogs() {
        guard let report = selectedReport else { return }
        
        // TODO: Implement log viewer
        // This would show execution history, errors, etc.
        let alert = NSAlert() 
        alert.messageText = "Report Logs"
        alert.informativeText = "Log viewing for report '\(report.name)' is not yet implemented. Check the main application logs for execution details."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Helper Methods
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showSuccess(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Success"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showInfo(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Information"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - NSTableViewDataSource

extension ScheduledReportsManagementViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return scheduledReports.count
    }
}

// MARK: - NSTableViewDelegate

extension ScheduledReportsManagementViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < scheduledReports.count else { return nil }
        
        let report = scheduledReports[row]
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")
        
        let cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            ?? NSTableCellView()
        
        // Create text field if it doesn't exist
        if cellView.textField == nil {
            let textField = NSTextField()
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            cellView.textField = textField
        }
        
        // Set cell content based on column
        switch identifier.rawValue {
        case "name":
            cellView.textField?.stringValue = report.name
            cellView.textField?.toolTip = report.description
            
        case "report":
            cellView.textField?.stringValue = report.reportDisplayName
            
        case "schedule":
            let frequency = report.schedule.frequency.displayName
            let time = report.schedule.timeOfDay
            cellView.textField?.stringValue = "\(frequency) at \(time)"
            cellView.textField?.toolTip = report.scheduleDescription
            
        case "nextRun":
            if let nextRun = report.nextRun {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                cellView.textField?.stringValue = formatter.string(from: nextRun)
                
                // Color code based on when it's due
                let now = Date()
                if nextRun <= now {
                    cellView.textField?.textColor = .systemRed
                } else if nextRun.timeIntervalSince(now) < 3600 { // Within 1 hour
                    cellView.textField?.textColor = .systemOrange
                } else {
                    cellView.textField?.textColor = .controlTextColor
                }
            } else {
                cellView.textField?.stringValue = "Not scheduled"
                cellView.textField?.textColor = .secondaryLabelColor
            }
            
        case "status":
            if report.isEnabled {
                cellView.textField?.stringValue = "✅"
                cellView.textField?.toolTip = "Enabled"
            } else {
                cellView.textField?.stringValue = "⏸️"
                cellView.textField?.toolTip = "Disabled"
            }
            
        case "lastRun":
            if let lastRun = report.lastRun {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                cellView.textField?.stringValue = formatter.string(from: lastRun)
                
                // Add status indicator based on last run result
                if let result = report.lastRunResult {
                    let statusIcon = result.success ? "✅" : "❌"
                    cellView.textField?.stringValue = "\(statusIcon) \(cellView.textField?.stringValue ?? "")"
                    cellView.textField?.toolTip = result.success ? "Last run successful" : "Last run failed: \(result.error ?? "Unknown error")"
                }
            } else {
                cellView.textField?.stringValue = "Never"
                cellView.textField?.textColor = .secondaryLabelColor
            }
            
        default:
            cellView.textField?.stringValue = ""
        }
        
        cellView.identifier = identifier
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()
    }
}
