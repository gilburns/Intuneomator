//
//  AppsReportingViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/11/25.
//

import Cocoa

/// View controller for displaying detailed device app installation status for Intune apps
/// Provides comprehensive reporting of app installation across assigned devices with sortable columns
/// and detailed installation information including status, versions, errors, and user data
class AppsReportingViewController: NSViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var appNameLabel: NSTextField!
    @IBOutlet weak var summaryLabel: NSTextField!
    @IBOutlet weak var dateCreatedLabel: NSTextField!
    @IBOutlet weak var dateModifiedLabel: NSTextField!
    @IBOutlet weak var pieChartView: NSView!
    @IBOutlet weak var cveScrollView: NSScrollView!
    @IBOutlet weak var cveTextView: NSTextView!
    @IBOutlet weak var cveHeaderLabel: NSTextField!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var exportButton: NSButton!
    @IBOutlet weak var exportFullReportButton: NSButton!
    @IBOutlet weak var openInIntuneButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    // MARK: - Properties
    
    /// The Intune app data for which to display device installation status
    var appData: [String: Any]?
    
    /// Array of device installation status dictionaries from Microsoft Graph reports API
    var deviceInstallationStatus: [[String: Any]] = []
    
    /// Filtered and sorted device installation status for table display
    var filteredDeviceInstallationStatus: [[String: Any]] = []
    
    /// Current sort descriptor for table columns
    var currentSortDescriptor: NSSortDescriptor?
    
    /// Custom pie chart view for displaying installation status
    private var installationStatusPieChart: InstallationStatusPieChartView?
    
    /// CVE fetcher for vulnerability information
    private let cveFetcher = CVEFetcher()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupUI()
        setupPieChart()
        setupCVEView()
        setupCVEHeaderLabel()
        loadDeviceInstallationStatus()
        loadCVEInformation()
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
            window.title = "Intune App Installation Report"
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
    
    /// Sets up the pie chart view for installation status visualization
    private func setupPieChart() {
        guard let pieChartView = pieChartView else { return }
        
        // Create custom pie chart view
        installationStatusPieChart = InstallationStatusPieChartView(frame: pieChartView.bounds)
        installationStatusPieChart?.autoresizingMask = [.width, .height]
        
        // Add to container view
        pieChartView.addSubview(installationStatusPieChart!)
    }
    
    /// Sets up the CVE text view for vulnerability information display
    private func setupCVEView() {
        guard let cveTextView = cveTextView else { return }
        
        // Configure text view
        cveTextView.isEditable = false
        cveTextView.isSelectable = true
        cveTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        cveTextView.textColor = NSColor.labelColor
        cveTextView.backgroundColor = NSColor.controlBackgroundColor
        
        // Enable automatic link detection
        cveTextView.isAutomaticLinkDetectionEnabled = true
        cveTextView.checkTextInDocument(nil)
        
        // Set initial placeholder text
        cveTextView.string = "Loading CVE information..."
    }
    
    /// Sets up the CVE header label
    private func setupCVEHeaderLabel() {
        guard let cveHeaderLabel = cveHeaderLabel else { return }
        
        // Configure header label
        cveHeaderLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        cveHeaderLabel.textColor = NSColor.labelColor
        cveHeaderLabel.stringValue = "CVE Information"
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
        // Set app name
        if let appData = appData,
           let displayName = appData["displayName"] as? String,
           let createDateString = appData["createdDateTime"] as? String,
           let lastModifiedDateString = appData["lastModifiedDateTime"] as? String {
            appNameLabel.stringValue = "Installation Report for: \(displayName)"
            dateCreatedLabel.stringValue = "\(createDateString.formatIntuneDate())"
            dateModifiedLabel.stringValue = "\(lastModifiedDateString.formatIntuneDate())"

        } else {
            appNameLabel.stringValue = "Installation Report for Intune App"
            dateCreatedLabel.stringValue = "Not Available"
            dateModifiedLabel.stringValue = "Not Available"
        }

        // Initial UI state
        summaryLabel.stringValue = "Loading device installation status..."
        refreshButton.isEnabled = false
        exportButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
    }
    
    // MARK: - Data Loading
    
    /// Loads device installation status from Microsoft Graph via XPC
    private func loadDeviceInstallationStatus() {
        guard let appData = appData,
              let appId = appData["id"] as? String else {
            showError("No app ID available for loading device installation status")
            return
        }
        
        XPCManager.shared.getDeviceAppInstallationStatusReport(appId: appId) { [weak self] installationStatus in
            
            DispatchQueue.main.async {
                self?.handleDeviceInstallationStatusResponse(installationStatus)
            }
        }
    }
    
    /// Handles the response from the device installation status API call
    /// - Parameter installationStatus: Array of device installation status dictionaries or nil on failure
    private func handleDeviceInstallationStatusResponse(_ installationStatus: [[String: Any]]?) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
        refreshButton.isEnabled = true
        
        if let installationStatus = installationStatus {
            self.deviceInstallationStatus = installationStatus
            self.filteredDeviceInstallationStatus = installationStatus
            updateSummaryLabel()
            updatePieChart()
            exportButton.isEnabled = !installationStatus.isEmpty
            tableView.reloadData()
        } else {
            showError("Failed to load device installation status. Please check your connection and permissions.")
            summaryLabel.stringValue = "Failed to load installation data"
        }
    }
    
    /// Updates the summary label with installation statistics
    private func updateSummaryLabel() {
        let totalDevices = deviceInstallationStatus.count
        let installedCount = deviceInstallationStatus.filter { ($0["InstallState"] as? Int) == 1 }.count
        let failedCount = deviceInstallationStatus.filter { 
            let state = $0["InstallState"] as? Int ?? -1
            return state == 2 || state == 4 // Failed or Uninstall Failed
        }.count
        let pendingCount = deviceInstallationStatus.filter { 
            let state = $0["InstallState"] as? Int ?? -1
            return state == 0 || state == 5 // Not Installed or Pending Restart
        }.count
        
        summaryLabel.stringValue = "Total: \(totalDevices) devices | Installed: \(installedCount) | Failed: \(failedCount) | Pending: \(pendingCount)"
    }
    
    /// Updates the pie chart with current installation status data
    private func updatePieChart() {
        guard let pieChart = installationStatusPieChart else { return }
        
        let totalDevices = deviceInstallationStatus.count
        let installedCount = deviceInstallationStatus.filter { ($0["InstallState"] as? Int) == 1 }.count
        let failedCount = deviceInstallationStatus.filter { 
            let state = $0["InstallState"] as? Int ?? -1
            return state == 2 || state == 4 // Failed or Uninstall Failed
        }.count
        let pendingCount = deviceInstallationStatus.filter { 
            let state = $0["InstallState"] as? Int ?? -1
            return state == 0 || state == 5 // Not Installed or Pending Restart
        }.count
        let notApplicableCount = deviceInstallationStatus.filter { 
            let state = $0["InstallState"] as? Int ?? -1
            return state == 3 // Not Applicable
        }.count
        
        // Update pie chart data
        pieChart.updateData(
            installed: installedCount,
            failed: failedCount,
            pending: pendingCount,
            notApplicable: notApplicableCount,
            total: totalDevices,
            labels: (installed: "Installed", failed: "Failed", pending: "Pending", notApplicable: "Not Applicable")
        )
    }
    
    // MARK: - CVE Information Loading
    
    /// Loads CVE (Common Vulnerabilities and Exposures) information for the current app
    private func loadCVEInformation() {
        guard let appData = appData,
              let displayName = appData["displayName"] as? String else {
            updateCVETextView("No app information available for CVE lookup")
            return
        }
        
        // Parse app name to extract just the application name without version
        let parsedAppName = parseApplicationName(from: displayName)
        
        // Update header with app name
        updateCVEHeader(appName: parsedAppName)
        
        // Show loading state
        updateCVETextView("Searching for CVE information...")
        
        // Fetch CVE information using the simple fetcher
        cveFetcher.fetchCVEsSimple(for: parsedAppName, daysBack: 90, maxResults: 10) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleCVEResponse(result, appName: parsedAppName)
            }
        }
    }
    
    /// Parses the application display name to extract just the app name without version numbers
    /// - Parameter displayName: The full display name from Intune (may include version)
    /// - Returns: Cleaned application name suitable for CVE lookup
    private func parseApplicationName(from displayName: String) -> String {
        var cleanName = displayName
        
        // Common patterns to remove version information
        let versionPatterns = [
            // Remove version patterns like "v1.2.3", "Version 1.2", "1.2.3"
            #"\s+v?\d+\.[\d\.]+.*$"#,
            #"\s+Version\s+\d+\.[\d\.]+.*$"#,
            #"\s+\d{4}\s*$"#,  // Year at end
            #"\s+\(\d+\.[\d\.]+.*\)$"#,  // Version in parentheses
            #"\s+\d+\.[\d\.]+.*$"#,  // Version numbers at end
            // Remove common installer/package suffixes
            #"\s+\(.*\)$"#,  // Anything in parentheses
            #"\s+-\s+.*$"#,  // Dash separator with additional info
            #"\s+for\s+.*$"#,  // "for Windows/macOS" etc.
            #"\s+\d{1,2}bit$"#,  // "32bit", "64bit"
            #"\s+(x86|x64|arm64|intel|apple\s+silicon).*$"#  // Architecture info
        ]
        
        for pattern in versionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: cleanName.utf16.count)
                cleanName = regex.stringByReplacingMatches(in: cleanName, options: [], range: range, withTemplate: "")
            }
        }
        
        // Additional cleanup for common app naming patterns
        cleanName = cleanName
            .replacingOccurrences(of: " Pro", with: "")
            .replacingOccurrences(of: " Professional", with: "")
            .replacingOccurrences(of: " Premium", with: "")
            .replacingOccurrences(of: " Enterprise", with: "")
            .replacingOccurrences(of: " Business", with: "")
            .replacingOccurrences(of: " Standard", with: "")
            .replacingOccurrences(of: " Personal", with: "")
            .replacingOccurrences(of: " Home", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanName.isEmpty ? displayName : cleanName
    }
    
    /// Handles the CVE fetcher response and updates the text view
    /// - Parameters:
    ///   - result: Result from CVE fetcher containing vulnerabilities or error
    ///   - appName: The parsed application name that was searched
    private func handleCVEResponse(_ result: Result<[VulnerabilityEntry], Error>, appName: String) {
        switch result {
        case .success(let vulnerabilities):
            // Update header with count
            updateCVEHeader(appName: appName, count: vulnerabilities.count)
            
            if vulnerabilities.isEmpty {
                updateCVETextView("✅ No recent vulnerabilities found in the last 90 days.")
            } else {
                let cveText = formatCVEInformation(vulnerabilities)
                updateCVETextView(cveText)
            }
        case .failure(let error):
            // Update header without count for errors
            updateCVEHeader(appName: appName)
            
            let errorMessage = "⚠️ Failed to fetch CVE information:\n\(error.localizedDescription)"
            updateCVETextView(errorMessage)
            Logger.error("CVE fetch failed for \(appName): \(error.localizedDescription)", category: .core, toUserDirectory: true)
        }
    }
    
    /// Formats CVE vulnerability information for display in the text view
    /// - Parameter vulnerabilities: Array of vulnerability entries from NIST
    /// - Returns: Formatted string with CVE information
    private func formatCVEInformation(_ vulnerabilities: [VulnerabilityEntry]) -> String {
        var output = ""
        
        for (index, vulnerability) in vulnerabilities.enumerated() {
            let cve = vulnerability.cve
            
            output += "[\(index + 1)] \(cve.id)\n"
            output += "Published: \(formatCVEDate(vulnerability.publishedDate, rawString: cve.published))\n"
            
            // Get CVSS score and severity
            if let metrics = cve.metrics,
               let cvssV3 = metrics.cvssMetricV31?.first ?? metrics.cvssMetricV30?.first {
                let score = cvssV3.cvssData.baseScore
                let severity = cvssV3.cvssData.baseSeverity ?? "UNKNOWN"
                output += "CVSS Score: \(score) (\(severity))\n"
            }
            
            // Description
            if let englishDesc = cve.descriptions.first(where: { $0.lang == "en" }) {
                let description = englishDesc.value
                let truncatedDesc = description.count > 500 ? String(description.prefix(500)) + "..." : description
                output += "Description: \(truncatedDesc)\n"
            }
            
            // CVE URL for more information
            output += "More info: https://nvd.nist.gov/vuln/detail/\(cve.id)\n"
            
            output += "\n" + String(repeating: "─", count: 50) + "\n\n"
        }
        
        output += "Data provided by NIST National Vulnerability Database\n"
        output += "Last updated: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
        
        return output
    }
    
    /// Formats a CVE date for display with fallback parsing
    /// - Parameters:
    ///   - date: Optional parsed date from CVE data
    ///   - rawString: Raw date string from CVE for debugging/fallback
    /// - Returns: Formatted date string or debug info
    private func formatCVEDate(_ date: Date?, rawString: String?) -> String {
        if let date = date {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        }
        
        // If parsing failed, try manual parsing with different formats
        if let rawString = rawString {
            // Try different date formats commonly used by NIST
            let formatters = [
                // Standard ISO8601 formats
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd'T'HH:mm:ssZ", 
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                // Alternative formats
                "yyyy-MM-dd",
                "MM/dd/yyyy"
            ]
            
            for format in formatters {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                
                if let parsedDate = formatter.date(from: rawString) {
                    return DateFormatter.localizedString(from: parsedDate, dateStyle: .medium, timeStyle: .none)
                }
            }
            
            // If all parsing failed, return the raw string for debugging
            return "Raw: \(rawString)"
        }
        
        return "Unknown"
    }
    
    /// Updates the CVE header label with app name and search period
    /// - Parameters:
    ///   - appName: The parsed application name being searched
    ///   - count: Optional count of vulnerabilities found
    private func updateCVEHeader(appName: String, count: Int? = nil) {
        if let count = count {
            cveHeaderLabel?.stringValue = "🔍 CVE Information for '\(appName)' (\(count) for the last 90 days)"
        } else {
            cveHeaderLabel?.stringValue = "🔍 CVE Information for '\(appName)' (Last 90 days)"
        }
    }
    
    /// Updates the CVE text view with new content and makes URLs clickable
    /// - Parameter text: The text to display in the CVE text view
    private func updateCVETextView(_ text: String) {
        guard let cveTextView = cveTextView else { return }
        
        // Create attributed string with the text
        let attributedString = NSMutableAttributedString(string: text)
        
        // Set default font and color
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
        attributedString.addAttributes(defaultAttributes, range: NSRange(location: 0, length: attributedString.length))
        
        // Find and format URLs
        let urlPattern = #"https?://[^\s]+"#
        if let regex = try? NSRegularExpression(pattern: urlPattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            
            for match in matches.reversed() { // Reverse to avoid index shifting
                if let range = Range(match.range, in: text) {
                    let urlString = String(text[range])
                    if let url = URL(string: urlString) {
                        // Apply link attributes
                        let linkAttributes: [NSAttributedString.Key: Any] = [
                            .link: url,
                            .foregroundColor: NSColor.systemBlue,
                            .underlineStyle: NSUnderlineStyle.single.rawValue
                        ]
                        attributedString.addAttributes(linkAttributes, range: match.range)
                    }
                }
            }
        }
        
        // Color-code CVSS severity levels
        applyCVSSSeverityColoring(to: attributedString, text: text)
        
        // Apply the attributed string to the text view
        cveTextView.textStorage?.setAttributedString(attributedString)
        
        // Enable automatic link detection for any URLs we might have missed
        cveTextView.checkTextInDocument(nil)
        
        // Scroll to top
        cveTextView.scrollToBeginningOfDocument(nil)
    }
    
    /// Applies color coding to CVSS severity levels in the attributed string
    /// - Parameters:
    ///   - attributedString: The mutable attributed string to modify
    ///   - text: The original text for pattern matching
    private func applyCVSSSeverityColoring(to attributedString: NSMutableAttributedString, text: String) {
        // Pattern to match CVSS Score lines: "CVSS Score: 7.5 (HIGH)"
        let cvssPattern = #"CVSS Score: [\d\.]+ \((CRITICAL|HIGH|MEDIUM|LOW|UNKNOWN)\)"#
        
        guard let regex = try? NSRegularExpression(pattern: cvssPattern, options: []) else { return }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        for match in matches {
            // Extract the severity level
            if let severityRange = Range(match.range, in: text) {
                let matchText = String(text[severityRange])
                
                // Determine color based on severity
                let severityColor: NSColor
                if matchText.contains("(CRITICAL)") {
                    severityColor = NSColor.systemRed
                } else if matchText.contains("(HIGH)") {
                    severityColor = NSColor.systemOrange
                } else if matchText.contains("(MEDIUM)") {
                    severityColor = NSColor.systemYellow
                } else if matchText.contains("(LOW)") {
                    severityColor = NSColor.systemGreen
                } else { // UNKNOWN
                    severityColor = NSColor.systemGray
                }
                
                // Apply color and bold weight to the entire CVSS line
                let severityAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: severityColor,
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
                ]
                attributedString.addAttributes(severityAttributes, range: match.range)
            }
        }
        
    }
    
    // MARK: - Actions
    
    /// Refreshes the device installation status data
    @IBAction func refreshData(_ sender: NSButton) {
        refreshButton.isEnabled = false
        exportButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        summaryLabel.stringValue = "Refreshing device installation status..."
        
        loadDeviceInstallationStatus()
    }
    
    /// Exports the device installation status data to CSV
    @IBAction func exportData(_ sender: NSButton) {
        exportToCSV()
    }
    
    /// Exports the full device installation status report using Microsoft Graph export jobs API
    @IBAction func exportFullReport(_ sender: NSButton) {
        showExportFullReportDialog()
    }
    
    /// Closes the reporting sheet
    @IBAction func closeSheet(_ sender: Any) {
        dismiss(self)
    }
    
    /// Opens the selected app in the Intune web console
    @IBAction func openInIntuneButtonClicked(_ sender: NSButton) {
        guard let appData = appData,
              let appId = appData["id"] as? String else {
            showError("No app ID available for Intune console link")
            return
        }
        
        openAppInIntuneConsole(appId: appId)
    }
    
    /// Opens the specified app in the Intune web console using the default browser
    /// - Parameter appId: The app GUID to open in the console
    private func openAppInIntuneConsole(appId: String) {
        let intuneURL = "https://intune.microsoft.com/#view/Microsoft_Intune_Apps/SettingsMenu/~/4/appId/\(appId)"
        
        guard let url = URL(string: intuneURL) else {
            showError("Failed to create valid Intune console URL")
            return
        }
        
        NSWorkspace.shared.open(url)
        Logger.info("Opened app \(appId) in Intune console: \(intuneURL)", category: .core, toUserDirectory: true)
    }

    // MARK: - Export Functionality
    
    /// Exports device installation status data to CSV format
    private func exportToCSV() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Device Installation Status"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        
        // Generate default filename
        let appName = (appData?["displayName"] as? String ?? "Application").replacingOccurrences(of: " ", with: "")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        savePanel.nameFieldStringValue = "\(appName)_InstallationReport_\(timestamp).csv"
        
        savePanel.begin { [weak self] response in
            if response == .OK, let url = savePanel.url {
                self?.writeCSVFile(to: url)
            }
        }
    }
    
    /// Writes device installation status data to CSV file
    /// - Parameter url: The file URL to write to
    private func writeCSVFile(to url: URL) {
        var csvContent = "Device Name,Device ID,User Principal Name,User ID,User Name,ApplicationId,Platform,Install State,Install State Detail,App Version,App Install State,App Install State loc,App State Details,App State Details loc,Error Code,Hex Error Code,Last Modified\n"
        
        for deviceStatus in deviceInstallationStatus {
            let deviceName = csvEscaped(deviceStatus["DeviceName"] as? String ?? "Unknown")
            let deviceID = csvEscaped(deviceStatus["DeviceId"] as? String ?? "Unknown")
            let userPrincipalName = csvEscaped(deviceStatus["UserPrincipalName"] as? String ?? "")
            let userID = csvEscaped(deviceStatus["UserId"] as? String ?? "")
            let userName = csvEscaped(deviceStatus["UserName"] as? String ?? "")
            let applicationId = csvEscaped(deviceStatus["ApplicationId"] as? String ?? "")
            let platform = csvEscaped(deviceStatus["Platform"] as? String ?? "")
            let installStateInt = deviceStatus["InstallState"] as? Int ?? 0
            let installState = csvEscaped(convertInstallStateToString(installStateInt))
            let installStateDetailInt = deviceStatus["InstallStateDetail"] as? Int ?? 0
            let installStateDetail = csvEscaped(convertInstallStateDetailToString(installStateDetailInt))
            let appVersion = csvEscaped(deviceStatus["AppVersion"] as? String ?? "")
            let appInstallState = csvEscaped(deviceStatus["AppInstallState"] as? String ?? "")
            let appInstallState_loc = csvEscaped(deviceStatus["AppInstallState_loc"] as? String ?? "")
            let appInstallStateDetails = csvEscaped(deviceStatus["AppInstallStateDetails"] as? String ?? "")
            let appInstallStateDetails_loc = csvEscaped(deviceStatus["AppInstallStateDetails_loc"] as? String ?? "")
            let errorCode = csvEscaped(String(deviceStatus["ErrorCode"] as? Int ?? 0))
            let hexErrorCode = csvEscaped(String(deviceStatus["HexErrorCode"] as? Int ?? 0))
            let lastModified = csvEscaped((deviceStatus["LastModifiedDateTime"] as? String ?? "").formatIntuneDate())
            
            csvContent += "\(deviceName),\(deviceID),\(userPrincipalName),\(userID),\(userName),\(applicationId),\(platform),\(installState),\(installStateDetail),\(appVersion),\(appInstallState),\(appInstallState_loc),\(appInstallStateDetails),\(appInstallStateDetails_loc),\(errorCode),\(hexErrorCode),\(lastModified)\n"
        }
        
        do {
            try csvContent.write(to: url, atomically: true, encoding: .utf8)
            showSuccess("Installation report exported successfully to \(url.lastPathComponent)")
        } catch {
            showError("Failed to export installation report: \(error.localizedDescription)")
        }
    }
    
    /// Escapes a string for CSV format
    /// - Parameter string: The string to escape
    /// - Returns: CSV-safe string with quotes and escaping
    private func csvEscaped(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    
    // MARK: - Export Full Report Functionality
    
    /// Shows the export full report dialog with format and save location options
    private func showExportFullReportDialog() {
        guard let appData = appData,
              let appId = appData["id"] as? String else {
            showError("No app ID available for export")
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Export Full Report"
        alert.informativeText = "Export the complete device installation status report for this app from Microsoft Graph. This may include more devices and data than currently displayed."
        
        // Create accessory view for format selection
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 50))
        
        // Format label
        let formatLabel = NSTextField(labelWithString: "Export Format:")
        formatLabel.frame = NSRect(x: 0, y: 20, width: 100, height: 20)
        accessoryView.addSubview(formatLabel)
        
        // Format popup button
        let formatPopup = NSPopUpButton(frame: NSRect(x: 110, y: 18, width: 80, height: 25))
        formatPopup.addItem(withTitle: "CSV")
        formatPopup.addItem(withTitle: "JSON")
        formatPopup.selectItem(at: 0) // Default to CSV
        accessoryView.addSubview(formatPopup)
        
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: "Export")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let format = formatPopup.titleOfSelectedItem?.lowercased() ?? "csv"
            
            // Show save panel
            showSavePanelForFullReport(appId: appId, format: format)
        }
    }
    
    /// Shows save panel for full report export
    /// - Parameters:
    ///   - appId: The app ID to export
    ///   - format: Export format (csv or json)
    private func showSavePanelForFullReport(appId: String, format: String) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Full Installation Report"
        
        // Set appropriate file type based on format
        if format == "csv" {
            savePanel.allowedContentTypes = [.commaSeparatedText]
        } else {
            savePanel.allowedContentTypes = [.json]
        }
        
        // Generate default filename
        let appName = (appData?["displayName"] as? String ?? "Application").replacingOccurrences(of: " ", with: "")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let fileExtension = format == "csv" ? "csv" : "json"
        savePanel.nameFieldStringValue = "\(appName)_FullReport_\(timestamp).\(fileExtension)"
        
        savePanel.begin { [weak self] response in
            if response == .OK, let url = savePanel.url {
                self?.performFullReportExport(appId: appId, format: format, saveUrl: url)
            }
        }
    }
    
    /// Performs the full report export using Microsoft Graph export jobs API
    /// - Parameters:
    ///   - appId: The app ID to export
    ///   - format: Export format (csv or json)
    ///   - saveUrl: The file URL to save to
    private func performFullReportExport(appId: String, format: String, saveUrl: URL) {
        // Show progress
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        exportFullReportButton?.isEnabled = false
        exportFullReportButton?.title = "Creating Export..."
        
        Logger.info("Starting full report export for app \(appId) in \(format) format", category: .core, toUserDirectory: true)
        
        // Create export job
        XPCManager.shared.createDeviceInstallStatusByAppExportJob(
            applicationId: appId,
            deviceName: nil,
            userName: nil,
            includeColumns: nil,
            format: format
        ) { [weak self] jobId in
            DispatchQueue.main.async {
                guard let self = self, let jobId = jobId else {
                    self?.handleExportError("Failed to create export job")
                    return
                }
                
                Logger.info("Export job created with ID: \(jobId)", category: .core, toUserDirectory: true)
                
                // Update UI to show polling status
                self.exportFullReportButton?.title = "Processing Export..."
                
                // Poll and download the export job
                XPCManager.shared.pollAndDownloadExportJob(
                    jobId: jobId,
                    maxWaitTimeSeconds: 600, // 10 minutes
                    pollIntervalSeconds: 5
                ) { [weak self] data in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        if let data = data {
                            self.saveExportJobData(data, to: saveUrl, format: format)
                        } else {
                            self.handleExportError("Export job failed or timed out")
                        }
                    }
                }
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
            // Microsoft Graph export jobs return ZIP files, so we need to extract the content
            let extractedData = try extractExportDataFromZip(data, expectedFormat: format)
            
            // Save the extracted CSV/JSON data
            try extractedData.write(to: saveUrl)
            
            // Hide progress and reset button
            progressIndicator.isHidden = true
            progressIndicator?.stopAnimation(nil)
            exportFullReportButton?.isEnabled = true
            exportFullReportButton?.title = "Export Full Report"
            
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
        unzipProcess.arguments = ["-j", tempZipFile.path, "-d", tempDir.path] // -j flattens directory structure
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
        
        Logger.info("Extracted \(extractedFile.lastPathComponent) from export ZIP", category: .core, toUserDirectory: true)
        return try Data(contentsOf: extractedFile)
    }
    
    /// Handles export errors by showing appropriate UI feedback
    /// - Parameter message: The error message to display
    private func handleExportError(_ message: String) {
        progressIndicator.isHidden = true
        progressIndicator.stopAnimation(nil)
        exportFullReportButton?.isEnabled = true
        exportFullReportButton?.title = "Export Full Report"
        
        Logger.error("Full report export error: \(message)", category: .core, toUserDirectory: true)
        showError(message)
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
    
    /// Configures the view controller with app data
    /// - Parameter appData: Dictionary containing app information
    func configure(with appData: [String: Any]) {
        self.appData = appData
    }
    
    /// Converts numeric install state to human-readable string
    /// - Parameter installState: Numeric install state from Microsoft Graph
    /// - Returns: Human-readable string representation
    private func convertInstallStateToString(_ installState: Int) -> String {
        switch installState {
        case 0:
            return "Not Installed"
        case 1:
            return "Installed"
        case 2:
            return "Failed"
        case 3:
            return "Not Applicable"
        case 4:
            return "Uninstall Failed"
        case 5:
            return "Pending Restart"
        default:
            return "Unknown (\(installState))"
        }
    }
    
    /// Converts numeric install state detail to human-readable string
    /// - Parameter installStateDetail: Numeric install state detail from Microsoft Graph
    /// - Returns: Human-readable string representation
    private func convertInstallStateDetailToString(_ installStateDetail: Int) -> String {
        switch installStateDetail {
        case 0:
            return "No Additional Info"
        case 1:
            return "Dependency Failed"
        case 2:
            return "Conflict with Other App"
        case 3:
            return "Pending Reboot"
        case 4:
            return "Installing Dependencies"
        case 5:
            return "Pending User Session"
        default:
            return "Detail (\(installStateDetail))"
        }
    }
}

// MARK: - NSTableViewDataSource

extension AppsReportingViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredDeviceInstallationStatus.count
    }
}

// MARK: - NSTableViewDelegate

extension AppsReportingViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn,
              let cell = tableView.makeView(withIdentifier: column.identifier, owner: self) as? NSTableCellView,
              row < filteredDeviceInstallationStatus.count else {
            return nil
        }
        
        let deviceStatus = filteredDeviceInstallationStatus[row]
        
        switch column.identifier.rawValue {
        case "deviceName":
            cell.textField?.stringValue = deviceStatus["DeviceName"] as? String ?? "Unknown Device"
            cell.textField?.toolTip = deviceStatus["DeviceId"] as? String ?? "Unknown Device"

        case "userPrincipalName":
            cell.textField?.stringValue = deviceStatus["UserPrincipalName"] as? String ?? ""
            cell.textField?.toolTip = deviceStatus["UserId"] as? String ?? ""

        case "userName":
            cell.textField?.stringValue = deviceStatus["UserName"] as? String ?? ""
            
        case "installState":
            let installStateInt = deviceStatus["InstallState"] as? Int ?? 0
            let installStateString = convertInstallStateToString(installStateInt)
            cell.textField?.stringValue = installStateString
            
            // Color code the installation state
            switch installStateInt {
            case 1: // Installed
                cell.textField?.textColor = NSColor.systemGreen
            case 2, 3, 4, 5: // Failed states
                cell.textField?.textColor = NSColor.systemRed
            case 0: // Not installed/Pending
                cell.textField?.textColor = NSColor.systemOrange
            default:
                cell.textField?.textColor = NSColor.labelColor
            }
            
        case "installStateDetail":
            let installStateDetailInt = deviceStatus["InstallStateDetail"] as? Int ?? 0
            let installStateDetailString = convertInstallStateDetailToString(installStateDetailInt)
            let installState = deviceStatus["InstallState"] as? Int ?? 0

            cell.textField?.stringValue = installStateDetailString
            cell.textField?.toolTip = String(installState)

        case "appVersion":
            cell.textField?.stringValue = deviceStatus["AppVersion"] as? String ?? "Unknown"
            cell.textField?.toolTip = deviceStatus["Platform"] as? String ?? "Unknown"

        case "errorCode":
            let errorCode = deviceStatus["ErrorCode"] as? Int ?? 0
            let hexErrorCode = deviceStatus["HexErrorCode"] as? String ?? ""
            cell.textField?.stringValue = String(hexErrorCode)
            cell.textField?.toolTip = String(errorCode)
            if errorCode != 0 {
                cell.textField?.textColor = NSColor.systemRed
            } else {
                cell.textField?.textColor = NSColor.labelColor
            }
            
        case "lastModifiedDateTime":
            let dateString = deviceStatus["LastModifiedDateTime"] as? String ?? ""
            cell.textField?.stringValue = dateString.formatIntuneDate()
            
        default:
            cell.textField?.stringValue = ""
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }
        
        currentSortDescriptor = sortDescriptor
        sortDeviceInstallationStatus(by: sortDescriptor)
        tableView.reloadData()
    }
    
    /// Sorts the device installation status array by the given sort descriptor
    /// - Parameter sortDescriptor: The sort descriptor to apply
    private func sortDeviceInstallationStatus(by sortDescriptor: NSSortDescriptor) {
        filteredDeviceInstallationStatus.sort { deviceStatus1, deviceStatus2 in
            var value1: Any?
            var value2: Any?
            
            switch sortDescriptor.key {
            case "deviceName":
                value1 = deviceStatus1["DeviceName"] as? String ?? ""
                value2 = deviceStatus2["DeviceName"] as? String ?? ""
            case "userPrincipalName":
                value1 = deviceStatus1["UserPrincipalName"] as? String ?? ""
                value2 = deviceStatus2["UserPrincipalName"] as? String ?? ""
            case "userName":
                value1 = deviceStatus1["UserName"] as? String ?? ""
                value2 = deviceStatus2["UserName"] as? String ?? ""
            case "installState":
                value1 = deviceStatus1["InstallState"] as? Int ?? 0
                value2 = deviceStatus2["InstallState"] as? Int ?? 0
            case "installStateDetail":
                value1 = deviceStatus1["InstallStateDetail"] as? Int ?? 0
                value2 = deviceStatus2["InstallStateDetail"] as? Int ?? 0
            case "appVersion":
                value1 = deviceStatus1["AppVersion"] as? String ?? ""
                value2 = deviceStatus2["AppVersion"] as? String ?? ""
            case "errorCode":
                value1 = deviceStatus1["ErrorCode"] as? Int ?? 0
                value2 = deviceStatus2["ErrorCode"] as? Int ?? 0
            case "lastModifiedDateTime":
                value1 = deviceStatus1["LastModifiedDateTime"] as? String ?? ""
                value2 = deviceStatus2["LastModifiedDateTime"] as? String ?? ""
            default:
                return false
            }
            
            if let int1 = value1 as? Int, let int2 = value2 as? Int {
                return sortDescriptor.ascending ? (int1 < int2) : (int1 > int2)
            } else if let string1 = value1 as? String, let string2 = value2 as? String {
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

