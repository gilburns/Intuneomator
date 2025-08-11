//
//  IntuneReportsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/17/25.
//

import Cocoa

/// Structure to hold export parameters during column selection
private struct PendingExportParameters {
    let reportName: String
    let reportType: String
    let format: String
    let filters: [String: String]
}

class IntuneReportsViewController: NSViewController {
    
    @IBOutlet weak var reportNamePopUp: NSPopUpButton!
    @IBOutlet weak var runReportButton: NSButton!
    @IBOutlet weak var scheduleReportButton: NSButton!
    @IBOutlet weak var manageSchedulesButton: NSButton!
    
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var cancelButton: NSButton!
    
    // MARK: - Properties
    
    /// Current export job ID for cancellation tracking
    private var currentJobId: String?
    
    /// Export operation cancellation flag
    private var isExportCancelled: Bool = false
    
    /// Set of cancelled job IDs to ignore when they complete
    private var cancelledJobIds: Set<String> = []
    
    /// Timer for polling progress updates
    private var progressTimer: Timer?
    
    /// Export start time for elapsed time tracking
    private var exportStartTime: Date?
    
    /// Currently selected report type
    private var selectedReportType: String?
    
    /// Variable to set so the popup reports menu selects that menu item when the view opens
    var preselectedReport: String?
    
    /// Filters to pre-populate when the export dialog opens (key = filter field name, value = filter value)
    var preselectedFilters: [String: String]?
    
    /// Temporary storage for export parameters during column selection
    private var pendingExportParameters: PendingExportParameters?
    
    // MARK: - View Lifecycle
    /// Lifecycle callback invoked when the view loads.
    /// Sets up the assignments file path, table view delegate/data source, and loads existing assignments.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    @objc func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            saveWindowFrame(window, forElement: "IntuneReportsViewController")
        }
    }

    
    // MARK: - UI Setup
    private func setupUI() {
        setupPopups()
        setupStatusControls()
        setupScheduleButtons()
    }
    
    private func setupStatusControls() {
        // Initialize status label
        statusLabel.stringValue = "Ready to export reports"
        statusLabel.textColor = .secondaryLabelColor
        
        // Initialize cancel button
        cancelButton.isHidden = true
        cancelButton.title = "Cancel"
        
        // Set progress indicator to determinate mode
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.doubleValue = 0
        progressIndicator.isHidden = true
    }
    
    private func setupPopups() {
        reportNamePopUp.removeAllItems()
        
        // Add a placeholder item to show current selection
        let placeholderItem = NSMenuItem(title: "Select Report Type...", action: nil, keyEquivalent: "")
        placeholderItem.isEnabled = false
        reportNamePopUp.menu?.addItem(placeholderItem)
        
        // Add separator
        reportNamePopUp.menu?.addItem(NSMenuItem.separator())
        
        // Get all reports from registry and populate popup with categories as submenus
        let categories = ReportRegistry.shared.getCategories()
        
        for category in categories {
            // Create category submenu
            let categoryMenu = NSMenu()
            let categoryMenuItem = NSMenuItem(title: category, action: nil, keyEquivalent: "")
            categoryMenuItem.submenu = categoryMenu
            
            // Add reports for this category
            let reportsInCategory = ReportRegistry.shared.getReportsForCategory(category)
            for report in reportsInCategory {
                let reportMenuItem = NSMenuItem(title: report.displayName, action: #selector(reportSelectionChanged(_:)), keyEquivalent: "")
                reportMenuItem.toolTip = report.formattedTooltip()
                reportMenuItem.target = self
                reportMenuItem.representedObject = report.type // Store the report type for identification
                categoryMenu.addItem(reportMenuItem)
            }
            
            reportNamePopUp.menu?.addItem(categoryMenuItem)
        }
        
        // Check if there's a preselected report to set
        if let preselectedReport = preselectedReport {
            // Try to find and select the preselected report
            var foundMatch = false
            
            // Search through category submenus
            for categoryItem in reportNamePopUp.menu?.items ?? [] {
                if let submenu = categoryItem.submenu {
                    for reportItem in submenu.items {
                        // Check both display name and report type ID
                        let displayName = reportItem.title
                        let reportType = reportItem.representedObject as? String ?? ""
                        
                        if displayName == preselectedReport || reportType == preselectedReport {
                            // Found a match - select it by simulating the normal selection process
                            selectedReportType = reportType
                            
                            // Update the placeholder item title and enable it
                            if let placeholderItem = reportNamePopUp.menu?.item(at: 0) {
                                placeholderItem.title = displayName
                                placeholderItem.isEnabled = true
                            }
                            
                            // Ensure the placeholder item remains selected
                            reportNamePopUp.selectItem(at: 0)
                            
                            // Trigger the same UI state updates that happen during normal selection
                            updateScheduleButtonsState()
                            
                            Logger.info("Preselected report: \(displayName) (\(reportType))", category: .core, toUserDirectory: true)
                            foundMatch = true
                            break
                        }
                    }
                    if foundMatch { break }
                }
            }
            
            if !foundMatch {
                Logger.warning("Could not find preselected report: \(preselectedReport)", category: .core, toUserDirectory: true)
            }
            
            // Clear the preselected report variable after processing
            self.preselectedReport = nil
        }
        
        // If no preselected report or not found, select the placeholder item by default
        if selectedReportType == nil {
            reportNamePopUp.selectItem(at: 0)
        }
    }
    
    private func setupScheduleButtons() {
        // Set initial button states
        updateScheduleButtonsState()
        
        // Set up button appearance
        scheduleReportButton.title = "Schedule Report…"
        manageSchedulesButton.title = "Manage Schedules"
        
        // Update button state when report selection changes
        reportNamePopUp.target = self
        reportNamePopUp.action = #selector(reportSelectionChanged(_:))
    }
    
    @objc private func reportSelectionChanged(_ sender: Any) {
        // Handle selection from submenu items
        if let menuItem = sender as? NSMenuItem,
           let reportType = menuItem.representedObject as? String {
            selectedReportType = reportType
            
            // Update the placeholder item title and enable it (first item in the menu)
            if let placeholderItem = reportNamePopUp.menu?.item(at: 0) {
                placeholderItem.title = menuItem.title
                placeholderItem.isEnabled = true
            }
            
            // Ensure the placeholder item remains selected
            reportNamePopUp.selectItem(at: 0)
        }
        updateScheduleButtonsState()
    }

    
    // MARK: - Actions
    @IBAction func runReportButtonClicked(_ sender: Any) {
        showExportFullReportDialog()
    }
    
    @IBAction func scheduleReportButtonClicked(_ sender: Any) {
        showScheduleReportDialog()
    }
    
    @IBAction func manageSchedulesButtonClicked(_ sender: Any) {
        openReportsScheduleManager()
    }
    
    @IBAction func cancelButtonClicked(_ sender: Any) {
        cancelCurrentExport()
    }
    
    private func openReportsScheduleManager() {
        WindowManager.shared.openWindow(
            identifier: "ScheduledReportsManagementViewController",
            storyboardName: "IntuneReports",
            controllerType: ScheduledReportsManagementViewController.self,
            windowTitle: "Scheduled Reports Manager",
            defaultSize: NSSize(width: 800, height: 600),
            restoreKey: "ScheduledReportsManagementViewController"
        )
    }

    /// Cancels the current export operation
    private func cancelCurrentExport() {
        isExportCancelled = true
        
        // Add current job ID to cancelled set
        if let jobId = currentJobId {
            cancelledJobIds.insert(jobId)
            Logger.info("Export operation cancelled by user for job ID: \(jobId)", category: .core, toUserDirectory: true)
        } else {
            Logger.info("Export operation cancelled by user (no job ID yet)", category: .core, toUserDirectory: true)
        }
        
        progressTimer?.invalidate()
        progressTimer = nil
        
        updateStatusLabel("Export cancelled by user", color: .systemOrange)
        resetUIState()
    }

    private func getReportNameAndType() -> (reportName: String, reportType: String)? {
        guard let reportType = selectedReportType,
              let reportDef = ReportRegistry.shared.getReportDefinition(for: reportType) else { 
            return nil 
        }
        
        return (reportName: reportDef.displayName, reportType: reportType)
    }
    
    
    
    // MARK: - Export Full Report Functionality
    
    /// Shows the export full report dialog with format and save location options
    private func showExportFullReportDialog() {
        
        let reportNameAndType = getReportNameAndType()
        guard reportNameAndType != nil else {
            return
        }
        
        guard let reportType = reportNameAndType?.reportType else {
            return
        }
        
        guard let reportName = reportNameAndType?.reportName else {
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Export Full Report"
        alert.informativeText = "Export the '\(reportName)' report from Microsoft Graph."
        
        // Check if this report type supports filtering using ReportRegistry
        let reportDefinition = ReportRegistry.shared.getReportDefinition(for: reportType)
        let hasFilters = reportDefinition?.supportedFilters.isEmpty == false
        
        // Calculate dialog dimensions based on filter support
        let dialogWidth: CGFloat = hasFilters ? 560 : 450 // Wider for two-column layout
        var dialogHeight: CGFloat = 50
        
        if hasFilters, let filterCount = reportDefinition?.supportedFilters.count {
            // Calculate height based on number of filters (two-column layout)
            let filtersPerColumn = Int(ceil(Double(filterCount) / 2.0))
            let filterAreaHeight = CGFloat(filtersPerColumn) * 28 + 45 // 28px spacing + padding + title space
            dialogHeight = max(120, filterAreaHeight + 60) // Minimum height + space for format controls
        }
        
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: dialogWidth, height: dialogHeight))
        
        // Format label and popup - position at top of dialog
        let formatLabelY = dialogHeight - 30
        let formatPopupY = dialogHeight - 32
        
        let formatLabel = NSTextField(labelWithString: "Export Format:")
        formatLabel.frame = NSRect(x: 0, y: formatLabelY, width: 100, height: 20)
        formatLabel.font = NSFont.boldSystemFont(ofSize: 13)
        accessoryView.addSubview(formatLabel)
        
        let formatPopup = NSPopUpButton(frame: NSRect(x: 110, y: formatPopupY, width: 80, height: 25))
        formatPopup.addItem(withTitle: "CSV")
        formatPopup.addItem(withTitle: "JSON")
        formatPopup.selectItem(at: 0) // Default to CSV
        accessoryView.addSubview(formatPopup)
        
        // Create filter controls dynamically using ReportRegistry
        var filterControls: [String: NSControl] = [:]
        
        if hasFilters {
            // Create a container view for filters
            let filterContainerHeight = dialogHeight - 50
            let filterContainer = NSView(frame: NSRect(x: 0, y: 5, width: dialogWidth, height: filterContainerHeight))
            accessoryView.addSubview(filterContainer)
            
            // Use ReportRegistry to create filter controls dynamically
            filterControls = ReportRegistry.shared.createFilterControls(for: reportType, in: filterContainer)
            
            // Populate filter controls with preselected values if available
            if let preselectedFilters = preselectedFilters {
                populateFilterControls(filterControls, with: preselectedFilters, for: reportType)
                
                // Clear the preselected filters after use
                self.preselectedFilters = nil
            }
        }
        
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: "Next")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let format = formatPopup.titleOfSelectedItem?.lowercased() ?? "csv"
            
            // Extract filter values using ReportRegistry for proper API value mapping
            let filters = ReportRegistry.shared.extractFilterValues(from: filterControls, for: reportType)
            
            // Show column selection dialog
            showColumnSelectionDialog(reportName: reportName, reportType: reportType, format: format, filters: filters)
        }
    }
    
    /// Shows column selection dialog for report export
    /// - Parameters:
    ///   - reportName: The report name for display
    ///   - reportType: The report type for API calls
    ///   - format: Export format (csv or json)
    ///   - filters: Dictionary of filter values to apply
    private func showColumnSelectionDialog(reportName: String, reportType: String, format: String, filters: [String: String] = [:]) {
        let columnSelectionVC = ColumnSelectionViewController(nibName: "ColumnSelectionViewController", bundle: nil)
        
        // Get default columns as preselection
        let defaultColumns = ReportRegistry.shared.getDefaultColumns(for: reportType) ?? []
        columnSelectionVC.configure(reportType: reportType, reportDisplayName: reportName, preselectedColumns: defaultColumns)
        
        columnSelectionVC.delegate = self
        
        // Store the current export parameters for use in delegate callback
        self.pendingExportParameters = PendingExportParameters(
            reportName: reportName,
            reportType: reportType,
            format: format,
            filters: filters
        )
        
        // Present as sheet
        presentAsSheet(columnSelectionVC)
    }
    
    /// Shows save panel for full report export
    /// - Parameters:
    ///   - reportName: The report name for display
    ///   - reportType: The report type for API calls
    ///   - format: Export format (csv or json)
    ///   - filters: Dictionary of filter values to apply
    ///   - selectedColumns: Array of selected column keys
    private func showSavePanelForFullReport(reportName: String, reportType: String, format: String, filters: [String: String] = [:], selectedColumns: [String]) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export '\(reportName)' Report"
        
        // Set appropriate file type based on format
        if format == "csv" {
            savePanel.allowedContentTypes = [.commaSeparatedText]
        } else {
            savePanel.allowedContentTypes = [.json]
        }
        
        // Generate default filename
        let reportName = (reportName).replacingOccurrences(of: " ", with: "")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let fileExtension = format == "csv" ? "csv" : "json"
        savePanel.nameFieldStringValue = "\(reportName)_FullReport_\(timestamp).\(fileExtension)"
        
        savePanel.begin { [weak self] response in
            if response == .OK, let url = savePanel.url {
                self?.performFullReportExport(reportName: reportName, reportType: reportType, format: format, filters: filters, selectedColumns: selectedColumns, saveUrl: url)
            }
        }
    }
    
    /// Performs the full report export using Microsoft Graph export jobs API
    /// - Parameters:
    ///   - reportName: The report name for display
    ///   - reportType: The report type for API calls
    ///   - format: Export format (csv or json)
    ///   - filters: Dictionary of filter values to apply
    ///   - selectedColumns: Array of selected column keys
    ///   - saveUrl: The file URL to save to
    private func performFullReportExport(reportName: String, reportType: String, format: String, filters: [String: String] = [:], selectedColumns: [String], saveUrl: URL) {
        // Reset cancellation state
        isExportCancelled = false
        exportStartTime = Date()
        
        // Show progress and disable controls
        setExportInProgress(true)
        updateStatusLabel("Creating export job...", color: .controlAccentColor)
        
        Logger.info("Starting full report export for \(reportType) in \(format) format", category: .core, toUserDirectory: true)
        
        // Build OData filter string from filter parameters using ReportRegistry
        let filterString = ReportRegistry.shared.buildODataFilter(from: filters, for: reportType)
        
        // Use selected columns instead of defaults
        let columnsToExport = selectedColumns
        
        // Create export job using generic XPC method
        XPCManager.shared.createExportJob(
            reportName: reportType,
            filter: filterString,
            select: columnsToExport,
            format: format
        ) { [weak self] jobId in
            DispatchQueue.main.async {
                guard let self = self, let jobId = jobId else {
                    self?.handleExportError("Failed to create export job")
                    return
                }
                
                self.pollAndHandleExportJob(jobId: jobId, saveUrl: saveUrl, format: format)
            }
        }
    }
    
    /// Saves export job data to the specified file
    /// - Parameters:
    ///   - data: The export job data (ZIP file from Microsoft Graph)
    ///   - saveUrl: The file URL to save to
    ///   - format: The export format for user feedback
    private func saveExportJobData(_ data: Data, to saveUrl: URL, format: String) {
        do {
            // Show completion
            updateProgress(100, message: "Extracting and saving file")
            
            // Microsoft Graph export jobs return ZIP files, so we need to extract the content
            let extractedData = try extractExportDataFromZip(data, expectedFormat: format)
            
            // Save the extracted CSV/JSON data
            try extractedData.write(to: saveUrl)
            
            // Reset UI state
            resetUIState()
            updateStatusLabel("Export completed successfully", color: .systemGreen)
            
            let dataSize = ByteCountFormatter.string(fromByteCount: Int64(extractedData.count), countStyle: .file)
            Logger.info("Full report export completed: \(dataSize) extracted and saved to \(saveUrl.lastPathComponent)", category: .core, toUserDirectory: true)
            
            // Show success and offer to open file
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Export Completed"
            alert.informativeText = "Full installation report (\(dataSize)) exported successfully to \(saveUrl.lastPathComponent)"
            alert.addButton(withTitle: "Open File")
            alert.addButton(withTitle: "Show in Finder")
            alert.addButton(withTitle: "OK")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(saveUrl)
            } else if response == .alertSecondButtonReturn {
                NSWorkspace.shared.selectFile(saveUrl.path, inFileViewerRootedAtPath: "")
            }
            
        } catch {
            handleExportError("Failed to save export file: \(error.localizedDescription)")
        }
    }
    
    /// Extracts the actual CSV/JSON data from the ZIP file returned by Microsoft Graph export jobs
    /// - Parameters:
    ///   - zipData: The ZIP file data from the export job
    ///   - expectedFormat: The expected format (csv or json)
    /// - Returns: The extracted CSV/JSON data
    /// - Throws: Extraction or file format errors
    private func extractExportDataFromZip(_ zipData: Data, expectedFormat: String) throws -> Data {
        // Create a temporary directory to extract the ZIP
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up temporary directory
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Write ZIP data to temporary file
        let tempZipFile = tempDir.appendingPathComponent("export.zip")
        try zipData.write(to: tempZipFile)
        
        // Extract ZIP file using NSTask (unzip command)
        let unzipProcess = Process()
        unzipProcess.launchPath = "/usr/bin/unzip"
        unzipProcess.arguments = ["-qq", tempZipFile.path, "-d", tempDir.path] // -j flattens directory structure
        unzipProcess.launch()
        unzipProcess.waitUntilExit()
        
        guard unzipProcess.terminationStatus == 0 else {
            throw NSError(domain: "ExportExtraction", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract ZIP file"])
        }
        
        // Find the extracted file with the expected format
        let extractedFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let targetExtension = expectedFormat.lowercased()
        
        // Look for a file with the expected extension
        guard let extractedFile = extractedFiles.first(where: { $0.pathExtension.lowercased() == targetExtension }) else {
            // If no file with expected extension, try to find any CSV or JSON file
            let fallbackFile = extractedFiles.first { url in
                let ext = url.pathExtension.lowercased()
                return ext == "csv" || ext == "json"
            }
            
            guard let fallbackFile = fallbackFile else {
                throw NSError(domain: "ExportExtraction", code: 2, userInfo: [NSLocalizedDescriptionKey: "No \(targetExtension.uppercased()) file found in export ZIP"])
            }
            
            Logger.warning("Expected \(targetExtension) file not found, using \(fallbackFile.lastPathComponent)", category: .core, toUserDirectory: true)
            return try Data(contentsOf: fallbackFile)
        }
        
        return try Data(contentsOf: extractedFile)
    }
    
    /// Handles export errors by showing appropriate UI feedback
    /// - Parameter message: The error message to display
    private func handleExportError(_ message: String) {
        resetUIState()
        updateStatusLabel("Export failed", color: .systemRed)
        
        Logger.error("Full report export error: \(message)", category: .core, toUserDirectory: true)
        showError(message)
    }
    
    // MARK: - UI State Management
    
    /// Sets the export in progress state
    /// - Parameter inProgress: Whether export is in progress
    private func setExportInProgress(_ inProgress: Bool) {
        runReportButton.isEnabled = !inProgress
        scheduleReportButton.isEnabled = !inProgress
        reportNamePopUp.isEnabled = !inProgress
        cancelButton.isHidden = !inProgress
        
        if inProgress {
            progressIndicator.isHidden = false
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.isHidden = true
            progressIndicator.stopAnimation(nil)
        }
    }
    
    /// Resets UI to default state
    private func resetUIState() {
        setExportInProgress(false)
        progressIndicator.doubleValue = 0
        progressTimer?.invalidate()
        progressTimer = nil
        currentJobId = nil
        isExportCancelled = false  // Reset cancellation flag
        updateStatusLabel("Ready to export reports", color: .secondaryLabelColor)
    }
    
    /// Updates the status label with color
    /// - Parameters:
    ///   - message: Status message to display
    ///   - color: Text color for the message
    private func updateStatusLabel(_ message: String, color: NSColor) {
        statusLabel.stringValue = message
        statusLabel.textColor = color
    }
    
    /// Updates progress with elapsed time and optional percentage
    /// - Parameters:
    ///   - progress: Progress percentage (0-100)
    ///   - message: Status message
    private func updateProgress(_ progress: Double, message: String) {
        progressIndicator.doubleValue = progress
        
        // Add elapsed time to status message
        if let startTime = exportStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            let elapsedString = String(format: "%.0fs", elapsed)
            updateStatusLabel("\(message) (\(elapsedString))", color: .controlAccentColor)
        } else {
            updateStatusLabel(message, color: .controlAccentColor)
        }
    }
    
    /// Starts simulated progress tracking since Microsoft Graph doesn't provide real-time progress
    private func startProgressTracking() {
        var currentProgress: Double = 5
        updateProgress(currentProgress, message: "Processing export job…")
        
        // Timer to simulate progress while waiting for Microsoft Graph
        progressTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self, !self.isExportCancelled else {
                timer.invalidate()
                return
            }
            
            // Gradually increase progress up to 90% (never 100% until actually complete)
            currentProgress += 3
            if currentProgress > 90 {
                currentProgress = 90
            }
            
            // Vary the message based on time elapsed
            let elapsed = Date().timeIntervalSince(self.exportStartTime ?? Date())
            let message: String
            if elapsed < 5 {
                message = "Processing export job…"
            } else if elapsed < 10 {
                message = "Creating export job…"
            } else if elapsed < 15 {
                message = "Intune exporting data…"
            } else if elapsed < 20 {
                message = "Creating export job…"
            } else if elapsed < 25 {
                message = "Intune exporting data…"
            } else if elapsed < 30 {
                message = "Creating export job…"
            } else if elapsed < 35 {
                message = "Intune exporting data…"
            } else if elapsed < 40 {
                message = "Creating export job…"
            } else if elapsed < 45 {
                message = "Intune exporting data…"
            } else if elapsed < 50 {
                message = "Creating export job…"
            } else if elapsed < 55 {
                message = "Intune exporting data…"
            } else {
                message = "Finalizing export report…"
            }
            
            self.updateProgress(currentProgress, message: message)
        }
    }
    
    /// Generic helper to handle export job polling with proper cancellation support
    /// - Parameters:
    ///   - jobId: The export job ID
    ///   - saveUrl: Where to save the completed export
    ///   - format: Export format for user feedback
    private func pollAndHandleExportJob(jobId: String, saveUrl: URL, format: String) {
        // Check if cancelled before proceeding
//        guard !isExportCancelled else { return }
        
        guard !self.cancelledJobIds.contains(jobId) else {
            Logger.info("Export job \(jobId) completed but was cancelled by user - ignoring result", category: .core, toUserDirectory: true)
            self.cancelledJobIds.remove(jobId)
            return
        }

        currentJobId = jobId
        Logger.info("Export job created with ID: \(jobId)", category: .core, toUserDirectory: true)
        
        // Start progress tracking with simulated progress
        startProgressTracking()
        
        // Poll and download the export job
        XPCManager.shared.pollAndDownloadExportJob(
            jobId: jobId,
            maxWaitTimeSeconds: 600, // 10 minutes
            pollIntervalSeconds: 5
        ) { [weak self] data in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Check if this specific job was cancelled
                guard !self.cancelledJobIds.contains(jobId) else { 
                    Logger.info("Export job \(jobId) completed but was cancelled by user - ignoring result", category: .core, toUserDirectory: true)
                    self.cancelledJobIds.remove(jobId) // Clean up
                    return 
                }
                
                if let data = data {
                    self.saveExportJobData(data, to: saveUrl, format: format)
                } else {
                    self.handleExportError("Export job failed or timed out")
                }
            }
        }
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
    
    // MARK: - Window Size Management Methods
    
    /// Saves the current window size to UserDefaults for persistence
    /// Preserves user's preferred window dimensions across application sessions
    /// - Parameter size: NSSize representing the current window dimensions
    func saveWindowFrame(_ window: NSWindow, forElement element: String) {
        let frame = window.frame
        let sizeDict: [String: Any] = [
            "width": frame.size.width,
            "height": frame.size.height,
            "x": frame.origin.x,
            "y": frame.origin.y
        ]
        UserDefaults.standard.set(sizeDict, forKey: element)
    }

    // MARK: - Scheduled Reports
    
    /// Shows the schedule report dialog for the currently selected report
    private func showScheduleReportDialog() {
        let reportNameAndType = getReportNameAndType()
        guard let reportType = reportNameAndType?.reportType,
              let reportName = reportNameAndType?.reportName else {
            showError("Please select a report type first")
            return
        }
        
        // Create a new scheduled report with the selected report type
        let storyboard = NSStoryboard(name: "IntuneReports", bundle: nil)
        guard let editorVC = storyboard.instantiateController(withIdentifier: "ReportScheduleEditorViewController") as? ReportScheduleEditorViewController else {
            showError("Failed to load schedule editor")
            return
        }
        
        // Configure the editor for a new report based on current selection
        var newReport = ScheduledReport(name: "\(reportName) Schedule", reportType: reportType, reportDisplayName: reportName)
        
        // Pre-populate with current filter selections if any
        let reportDefinition = ReportRegistry.shared.getReportDefinition(for: reportType)
        if reportDefinition?.supportedFilters.isEmpty == false {
            // In a full implementation, we could extract current filter state from the export dialog
            // For now, start with empty filters
        }
        
        editorVC.scheduledReport = nil // Ensure it's treated as new
        
        editorVC.onSaveComplete = { [weak self] savedReport in
            self?.showSuccess("Scheduled report '\(savedReport.name)' created successfully")
            Logger.info("Created scheduled report: \(savedReport.name)", category: .core, toUserDirectory: true)
        }
        
        editorVC.onCancel = {
            Logger.info("Scheduled report creation cancelled", category: .core, toUserDirectory: true)
        }
        
        presentAsSheet(editorVC)
    }
        
    /// Updates the UI state for schedule-related buttons
    private func updateScheduleButtonsState() {
        let hasReportSelected = selectedReportType != nil
        
        // Check Azure Storage configurations via XPC
        XPCManager.shared.getAzureStorageConfigurationNames { availableConfigs in
            DispatchQueue.main.async {
                let hasAzureStorage = !availableConfigs.isEmpty
                self.scheduleReportButton.isEnabled = hasReportSelected && hasAzureStorage

                if !hasAzureStorage {
                    self.scheduleReportButton.toolTip = "Configure Azure Storage in Settings to enable report scheduling"
                    self.manageSchedulesButton.toolTip = "Configure Azure Storage in Settings to enable report scheduling"
                } else {
                    self.scheduleReportButton.toolTip = nil
                    self.manageSchedulesButton.toolTip = nil
                }
            }
        }
    }
    
    /// Populates filter controls with preselected values
    /// - Parameters:
    ///   - filterControls: Dictionary of filter controls created by ReportRegistry
    ///   - preselectedValues: Dictionary of filter values to populate (key = filter field name, value = filter value)
    ///   - reportType: The report type for logging and validation
    private func populateFilterControls(_ filterControls: [String: NSControl], with preselectedValues: [String: String], for reportType: String) {
        Logger.info("Populating \(preselectedValues.count) preselected filter(s) for report type: \(reportType)", category: .core, toUserDirectory: true)
        
        for (filterKey, filterValue) in preselectedValues {
            guard let control = filterControls[filterKey] else {
                Logger.warning("No filter control found for key '\(filterKey)' in report type '\(reportType)'", category: .core, toUserDirectory: true)
                continue
            }
            
            // Handle different control types
            if let popupButton = control as? NSPopUpButton {
                // For popup buttons, try to find and select the matching item
                var foundMatch = false
                
                // First try exact title match
                for i in 0..<popupButton.numberOfItems {
                    if let item = popupButton.item(at: i), item.title == filterValue {
                        popupButton.selectItem(at: i)
                        Logger.info("Set popup filter '\(filterKey)' to '\(filterValue)'", category: .core, toUserDirectory: true)
                        foundMatch = true
                        break
                    }
                }
                
                // If no exact match, try by representedObject (for cases where display name != API value)
                if !foundMatch {
                    for i in 0..<popupButton.numberOfItems {
                        if let item = popupButton.item(at: i),
                           let representedValue = item.representedObject as? String,
                           representedValue == filterValue {
                            popupButton.selectItem(at: i)
                            Logger.info("Set popup filter '\(filterKey)' to '\(item.title)' (matched by value '\(filterValue)')", category: .core, toUserDirectory: true)
                            foundMatch = true
                            break
                        }
                    }
                }
                
                if !foundMatch {
                    Logger.warning("Could not find matching popup item for filter '\(filterKey)' with value '\(filterValue)'", category: .core, toUserDirectory: true)
                }
                
            } else if let textField = control as? NSTextField {
                // For text fields, directly set the string value
                textField.stringValue = filterValue
                Logger.info("Set text filter '\(filterKey)' to '\(filterValue)'", category: .core, toUserDirectory: true)
                
            } else {
                Logger.warning("Unknown control type for filter '\(filterKey)': \(type(of: control))", category: .core, toUserDirectory: true)
            }
        }
    }

}

// MARK: - ColumnSelectionDelegate

extension IntuneReportsViewController: ColumnSelectionDelegate {
    
    func columnSelectionDidComplete(_ selectedColumns: [String], displayNames: [String: String]) {
        guard let params = pendingExportParameters else {
            Logger.error("No pending export parameters found for column selection", category: .core, toUserDirectory: true)
            return
        }
        
        // Clear pending parameters
        pendingExportParameters = nil
        
        Logger.info("Column selection completed: \(selectedColumns.count) columns selected for \(params.reportName)", category: .core, toUserDirectory: true)
        
        // Proceed to save panel with selected columns
        showSavePanelForFullReport(
            reportName: params.reportName,
            reportType: params.reportType,
            format: params.format,
            filters: params.filters,
            selectedColumns: selectedColumns
        )
    }
    
    func columnSelectionDidCancel() {
        // Clear pending parameters
        pendingExportParameters = nil
        Logger.info("Column selection cancelled by user", category: .core, toUserDirectory: true)
    }
}
