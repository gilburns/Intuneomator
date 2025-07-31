//
//  DeviceDetailsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/20/25.
//

import Cocoa

class DeviceDetailsViewController: NSViewController, NSTabViewDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var tabView: NSTabView!
    @IBOutlet weak var deviceNameLabel: NSTextField!
    @IBOutlet weak var deviceIdLabel: NSTextField!
        
    // Device Overview Tab
    @IBOutlet weak var overviewScrollView: NSScrollView!
    @IBOutlet weak var overviewContentView: NSView!
    @IBOutlet weak var overviewLoadingIndicator: NSProgressIndicator!
    @IBOutlet weak var overviewStatusLabel: NSTextField!
    
    // Detected Apps Tab
    @IBOutlet weak var appsScrollView: NSScrollView!
    @IBOutlet weak var appsTableView: NSTableView!
    @IBOutlet weak var appsSearchField: NSSearchField!
    @IBOutlet weak var appsLoadingIndicator: NSProgressIndicator!
    @IBOutlet weak var appsStatusLabel: NSTextField!
    @IBOutlet weak var appsCountLabel: NSTextField!
    @IBOutlet weak var exportAppsButton: NSButton!
    @IBOutlet weak var exportAppsFullReportButton: NSButton!
    @IBOutlet weak var appsExportingIndicator: NSProgressIndicator!

    // Compliance Policy Tab
    @IBOutlet weak var complianceScrollView: NSScrollView!
    @IBOutlet weak var complianceContentView: NSView!
    @IBOutlet weak var complianceLoadingIndicator: NSProgressIndicator!
    @IBOutlet weak var complianceStatusLabel: NSTextField!
    
    // Configuration Policy Tab
    @IBOutlet weak var configScrollView: NSScrollView!
    @IBOutlet weak var configContentView: NSView!
    @IBOutlet weak var configLoadingIndicator: NSProgressIndicator!
    @IBOutlet weak var configStatusLabel: NSTextField!
    
    // Windows Protection Tab
    @IBOutlet weak var protectionScrollView: NSScrollView!
    @IBOutlet weak var protectionContentView: NSView!
    @IBOutlet weak var protectionLoadingIndicator: NSProgressIndicator!
    @IBOutlet weak var protectionStatusLabel: NSTextField!
    
    // MARK: - Properties
    var deviceId: String?
    var deviceName: String?
    var deviceDetails: [String: Any]?
    var detectedApps: [[String: Any]]?
    var compliancePolicyStates: [[String: Any]]?
    var configurationStates: [[String: Any]]?
    var windowsProtectionState: [String: Any]?
    
    // Track which tabs have been loaded
    private var loadedTabs: Set<Int> = []
    
    // Apps table view management
    private var filteredApps: [[String: Any]] = []
    private var searchText: String = ""
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadDeviceDetails()
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
            window.title = "Intune Devices"
            window.minSize = NSSize(width: 750, height: 600)
            window.maxSize = NSSize(width: 750, height: 600)
            window.setContentSize(NSSize(width: 750, height: 600))
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
            dismiss(self)
        } else {
            super.keyDown(with: event)
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Set up tab view and ensure all tabs have proper identifiers
        tabView.delegate = self
        
        // Set up tab identifiers (these need to match what's in Interface Builder)
        for (index, tabItem) in tabView.tabViewItems.enumerated() {
            switch index {
            case 0:
                tabItem.identifier = "overview"
            case 1:
                tabItem.identifier = "apps"
            case 2:
                tabItem.identifier = "compliance"
            case 3:
                tabItem.identifier = "configuration"
            case 4:
                tabItem.identifier = "protection"
            default:
                break
            }
        }
        
        // Set deviceNameLabel if deviceName is available
        if let deviceName = deviceName {
            deviceNameLabel.stringValue = "Device Details: \(deviceName)"
        } else {
            deviceNameLabel.stringValue = "Device Details"
        }
        
        // Set deviceIdLabel if deviceId is available
        if let deviceId = deviceId {
            deviceIdLabel.stringValue = "Device ID: \(deviceId)"
        } else {
            deviceIdLabel.stringValue = "Unknown ID"
        }

        // Configure all loading indicators
        overviewLoadingIndicator.style = .spinning
        overviewLoadingIndicator.isDisplayedWhenStopped = false
        appsLoadingIndicator.style = .spinning
        appsLoadingIndicator.isDisplayedWhenStopped = false
        complianceLoadingIndicator.style = .spinning
        complianceLoadingIndicator.isDisplayedWhenStopped = false
        configLoadingIndicator.style = .spinning
        configLoadingIndicator.isDisplayedWhenStopped = false
        protectionLoadingIndicator.style = .spinning
        protectionLoadingIndicator.isDisplayedWhenStopped = false
        
        // Configure all scroll views
        setupScrollView(overviewScrollView, contentView: overviewContentView)
        setupScrollView(complianceScrollView, contentView: complianceContentView)
        setupScrollView(configScrollView, contentView: configContentView)
        setupScrollView(protectionScrollView, contentView: protectionContentView)
        
        // Configure apps table view
        setupAppsTableView()
        
        // Configure export apps button
        exportAppsButton.title = "Export Apps to CSV…"
        exportAppsButton.isEnabled = false
        
        // Set initial status labels
        overviewStatusLabel.stringValue = "Loading device details..."
        overviewStatusLabel.textColor = .secondaryLabelColor
        appsStatusLabel.stringValue = "Click tab to load detected applications..."
        appsStatusLabel.textColor = .secondaryLabelColor
        appsCountLabel.stringValue = ""
        appsCountLabel.textColor = .secondaryLabelColor
        complianceStatusLabel.stringValue = "Click tab to load compliance policies..."
        complianceStatusLabel.textColor = .secondaryLabelColor
        configStatusLabel.stringValue = "Click tab to load configuration policies..."
        configStatusLabel.textColor = .secondaryLabelColor
        protectionStatusLabel.stringValue = "Click tab to load Windows protection state..."
        protectionStatusLabel.textColor = .secondaryLabelColor
        
        // Hide Windows Protection tab for non-Windows devices initially
        // Will be shown when device details load if it's a Windows device
        hideWindowsProtectionTab()
    }
    
    private func setupScrollView(_ scrollView: NSScrollView, contentView: NSView) {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView
    }
    
    private func setupAppsTableView() {
        // Configure table view
        appsTableView.dataSource = self
        appsTableView.delegate = self
        appsTableView.allowsMultipleSelection = false
        appsTableView.allowsColumnSelection = false
        appsTableView.allowsColumnReordering = true
        appsTableView.allowsColumnResizing = true
        appsTableView.usesAlternatingRowBackgroundColors = true
        appsTableView.rowSizeStyle = .default
        
        // Configure search field
        appsSearchField.delegate = self
        appsSearchField.placeholderString = "Search applications..."
        appsSearchField.sendsSearchStringImmediately = true
        
        // Set up table columns if not already configured in IB
        if appsTableView.tableColumns.isEmpty {
            setupTableColumns()
        }
    }
    
    private func setupTableColumns() {
        // Application Name Column
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Application Name"
        nameColumn.width = 200
        nameColumn.minWidth = 150
        nameColumn.maxWidth = 300
        appsTableView.addTableColumn(nameColumn)
        
        // Version Column
        let versionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("version"))
        versionColumn.title = "Version"
        versionColumn.width = 100
        versionColumn.minWidth = 80
        versionColumn.maxWidth = 150
        appsTableView.addTableColumn(versionColumn)
        
        // Publisher Column
        let publisherColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("publisher"))
        publisherColumn.title = "Publisher"
        publisherColumn.width = 150
        publisherColumn.minWidth = 100
        publisherColumn.maxWidth = 200
        appsTableView.addTableColumn(publisherColumn)
        
        // Size Column
        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeColumn.title = "Size"
        sizeColumn.width = 80
        sizeColumn.minWidth = 60
        sizeColumn.maxWidth = 120
        appsTableView.addTableColumn(sizeColumn)
        
        // Platform Column
        let platformColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("platform"))
        platformColumn.title = "Platform"
        platformColumn.width = 100
        platformColumn.minWidth = 80
        platformColumn.maxWidth = 120
        appsTableView.addTableColumn(platformColumn)
    }
    
    // MARK: - Data Loading
    private func loadDeviceDetails() {
        guard let deviceId = deviceId else {
            overviewStatusLabel.stringValue = "No device ID provided"
            overviewStatusLabel.textColor = .systemRed
            return
        }
        
        // Show loading state for overview tab
        overviewLoadingIndicator.startAnimation(nil)
        overviewStatusLabel.stringValue = "Loading device details..."
        overviewStatusLabel.textColor = .secondaryLabelColor
        
        // Fetch device details via XPC
        XPCManager.shared.getManagedDeviceDetails(deviceId: deviceId) { [weak self] details in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.overviewLoadingIndicator.stopAnimation(nil)
                
                if let details = details {
                    self.deviceDetails = details
                    
                    // Mark overview tab as loaded and display it
                    self.loadedTabs.insert(0)
                    self.displayOverviewTab(details)
                    
                    // Show Windows Protection tab if this is a Windows device
                    if let os = details["operatingSystem"] as? String, os.lowercased().contains("windows") {
                        self.showWindowsProtectionTab()
                    }
                    
                    // Extract detected apps for the apps tab
                    if let detectedApps = details["detectedApps"] as? [[String: Any]] {
                        self.detectedApps = detectedApps
                        self.exportAppsButton.isEnabled = !detectedApps.isEmpty
                    }
                    
                    self.overviewStatusLabel.isHidden = true
                } else {
                    self.overviewStatusLabel.stringValue = "Failed to load device details"
                    self.overviewStatusLabel.textColor = .systemRed
                }
            }
        }
    }
    
    // MARK: - Tab Management
    private var hiddenProtectionTab: NSTabViewItem?
    
    private func hideWindowsProtectionTab() {
        // Find and remove the Windows Protection tab
        for tabItem in tabView.tabViewItems {
            if let identifier = tabItem.identifier as? String, identifier == "protection" {
                hiddenProtectionTab = tabItem
                tabView.removeTabViewItem(tabItem)
                break
            }
        }
    }
    
    private func showWindowsProtectionTab() {
        // Restore the Windows Protection tab if it was hidden
        if let protectionTab = hiddenProtectionTab {
            tabView.addTabViewItem(protectionTab)
            hiddenProtectionTab = nil
        }
    }
    
    // MARK: - NSTabViewDelegate
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard let tabViewItem = tabViewItem,
              let identifier = tabViewItem.identifier as? String,
              let deviceId = deviceId else { return }
        
        let tabIndex = tabView.indexOfTabViewItem(tabViewItem)
        
        // Load data for the selected tab if not already loaded
        if !loadedTabs.contains(tabIndex) {
            loadedTabs.insert(tabIndex)
            
            switch identifier {
            case "overview":
                // Overview already loaded in loadDeviceDetails
                break
            case "apps":
                loadDetectedAppsTab()
            case "compliance":
                loadCompliancePolicyTab(deviceId: deviceId)
            case "configuration":
                loadConfigurationPolicyTab(deviceId: deviceId)
            case "protection":
                loadWindowsProtectionTab(deviceId: deviceId)
            default:
                break
            }
        }
    }
    
    // MARK: - Tab Data Loading
    private func loadDetectedAppsTab() {
        if let detectedApps = detectedApps, !detectedApps.isEmpty {
            displayAppsTab(detectedApps)
        } else {
            appsStatusLabel.stringValue = "No detected applications found"
            appsStatusLabel.textColor = .secondaryLabelColor
            appsTableView.isHidden = true
            appsSearchField.isHidden = true
            appsCountLabel.stringValue = "0 applications"
            exportAppsButton.isEnabled = false
        }
    }
    
    private func loadCompliancePolicyTab(deviceId: String) {
        complianceLoadingIndicator.startAnimation(nil)
        complianceStatusLabel.stringValue = "Loading compliance policies..."
        complianceStatusLabel.textColor = .secondaryLabelColor
        
        XPCManager.shared.getDeviceCompliancePolicyStates(deviceId: deviceId) { [weak self] states in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.complianceLoadingIndicator.stopAnimation(nil)
                
                if let states = states {
                    self.compliancePolicyStates = states
                    self.displayCompliancePolicyTab(states)
                    self.complianceStatusLabel.isHidden = true
                } else {
                    self.complianceStatusLabel.stringValue = "Failed to load compliance policies"
                    self.complianceStatusLabel.textColor = .systemRed
                }
            }
        }
    }
    
    private func loadConfigurationPolicyTab(deviceId: String) {
        configLoadingIndicator.startAnimation(nil)
        configStatusLabel.stringValue = "Loading configuration policies..."
        configStatusLabel.textColor = .secondaryLabelColor
        
        XPCManager.shared.getDeviceConfigurationStates(deviceId: deviceId) { [weak self] states in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.configLoadingIndicator.stopAnimation(nil)
                
                if let states = states {
                    self.configurationStates = states
                    self.displayConfigurationPolicyTab(states)
                    self.configStatusLabel.isHidden = true
                } else {
                    self.configStatusLabel.stringValue = "Failed to load configuration policies"
                    self.configStatusLabel.textColor = .systemRed
                }
            }
        }
    }
    
    private func loadWindowsProtectionTab(deviceId: String) {
        protectionLoadingIndicator.startAnimation(nil)
        protectionStatusLabel.stringValue = "Loading Windows protection state..."
        protectionStatusLabel.textColor = .secondaryLabelColor
        
        XPCManager.shared.getWindowsProtectionState(deviceId: deviceId) { [weak self] state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.protectionLoadingIndicator.stopAnimation(nil)
                
                if let state = state {
                    self.windowsProtectionState = state
                    self.displayWindowsProtectionTab(state)
                    self.protectionStatusLabel.isHidden = true
                } else {
                    self.protectionStatusLabel.stringValue = "Failed to load Windows protection state"
                    self.protectionStatusLabel.textColor = .systemRed
                }
            }
        }
    }
    
    // MARK: - Tab Display Methods
    private func displayOverviewTab(_ details: [String: Any]) {
        // Clear existing content
        overviewContentView.subviews.forEach { $0.removeFromSuperview() }
        
        // First, calculate total height needed by collecting all sections
        var sections: [(header: String, fields: [(label: String, value: String?)])] = []
        let margin: CGFloat = 20
        let sectionSpacing: CGFloat = 30
        
        // Device Overview Section
        sections.append((
            header: "Device Overview",
            fields: [
                ("Device Name", details["deviceName"] as? String),
                ("Serial Number", details["serialNumber"] as? String),
                ("Manufacturer", details["manufacturer"] as? String),
                ("Model", details["model"] as? String),
                ("Device Type", details["deviceType"] as? String)
            ]
        ))

        // Operating System Section
        sections.append((
            header: "Operating System",
            fields: [
                ("Operating System", details["operatingSystem"] as? String),
                ("OS Version", details["osVersion"] as? String)
            ]
        ))

        // Management Information Section
        sections.append((
            header: "Management Information",
            fields: [
                ("Managed Device Name", details["managedDeviceName"] as? String),
                ("Management State", details["managementState"] as? String),
                ("Compliance State", details["complianceState"] as? String),
                ("Owner Type", details["ownerType"] as? String),
                ("Management Agent", details["managementAgent"] as? String),
                ("Enrollment Type", details["deviceEnrollmentType"] as? String),
                ("Enrollment Profile", details["enrollmentProfileName"] as? String),
                ("Join Type", details["joinType"] as? String),
                ("Is Supervised", formatBooleanValue(details["isSupervised"])),
                ("Is Encrypted", formatBooleanValue(details["isEncrypted"])),
                ("EAS Activated", formatBooleanValue(details["easActivated"])),
                ("EAS Activation ID", details["easDeviceId"] as? String),
                ("EAS Activation Time", formatDateTime(details["easActivationDateTime"] as? String))
            ]
        ))
        
        // User Information Section
        sections.append((
            header: "User Information",
            fields: [
                ("User Display Name", details["userDisplayName"] as? String),
                ("User Principal Name", details["userPrincipalName"] as? String),
                ("User ID", details["userId"] as? String),
                ("Email Address", details["emailAddress"] as? String)
            ]
        ))
        
        // Device Status Section
        sections.append((
            header: "Device Status",
            fields: [
                ("Last Sync", formatDateTime(details["lastSyncDateTime"] as? String)),
                ("Enrolled Date", formatDateTime(details["enrolledDateTime"] as? String)),
                ("Enrolled By", details["enrolledByUserPrincipalName"] as? String),
                ("Autopilot Enrolled", details["autopilotEnrolled"] as? String),
                ("Device Registration State", details["deviceRegistrationState"] as? String),
                ("Entra ID Registered", formatBooleanValue(details["azureADRegistered"])),
                ("Intune Device ID", details["id"] as? String),
                ("Entra ID Device ID", details["azureADDeviceId"] as? String)
            ]
        ))
        
        // Hardware Information Section
        sections.append((
            header: "Hardware Information",
            fields: [
                ("Chassis Type", details["chassisType"] as? String),
                ("Total Storage", formatStorageSize(details["totalStorageSpaceInBytes"] as? Int64)),
                ("Free Storage", formatStorageSize(details["freeStorageSpaceInBytes"] as? Int64)),
                ("Physical Memory", formatStorageSize(details["physicalMemoryInBytes"] as? Int64)),
                ("Encrypted", formatBooleanValue(details["isEncrypted"])),
                ("Processor Architecture", details["processorArchitecture"] as? String),
                ("System Management BIOS Version", details["systemManagementBIOSVersion"] as? String)
            ]
        ))
        
        // Network Information Section
        sections.append((
            header: "Network Information",
            fields: [
                ("WiFi MAC Address", details["wiFiMacAddress"] as? String),
                ("Ethernet MAC Address", details["ethernetMacAddress"] as? String),
                ("Subscriber Carrier", details["subscriberCarrier"] as? String),
                ("ICCID", details["iccid"] as? String),
                ("Phone Number", details["phoneNumber"] as? String),
                ("IMEI", details["imei"] as? String),
                ("MEID", details["meid"] as? String)
            ]
        ))
        
        // Security Information Section
        sections.append((
            header: "Security Information",
            fields: [
                ("Security Patch Level", details["securityPatchLevel"] as? String),
                ("Android Security Patch", details["androidSecurityPatchLevel"] as? String),
                ("Lost Mode State", details["lostModeState"] as? String),
                ("Jailbroken Status", details["jailBroken"] as? String),
                ("Management Cert Expiration", formatDateTime(details["managementCertificateExpirationDate"] as? String)),
                ("TPM Version", details["tpmVersion"] as? String),
                ("TPM Manufacturer", details["tpmManufacturer"] as? String),
                ("TPM Manufacturer Version", details["tpmSpecificationVersion"] as? String)
            ]
        ))
        
        // Detected Apps Section
        if let detectedApps = details["detectedApps"] as? [[String: Any]] {
            var appFields: [(label: String, value: String?)] = []
            let appsToShow = Array(detectedApps.prefix(5))
            for app in appsToShow {
                let appName = app["displayName"] as? String ?? "Unknown App"
                let appVersion = app["version"] as? String ?? ""
                let displayText = appVersion.isEmpty ? appName : "\(appName) (v\(appVersion))"
                appFields.append(("", displayText))
            }
            if detectedApps.count > 5 {
                appFields.append(("", "... and \(detectedApps.count - 5) more apps"))
            }
            
            sections.append((
                header: "Detected Applications (\(detectedApps.count) apps)",
                fields: appFields
            ))
        }
        
        // Additional Information Section
        sections.append((
            header: "Additional Information",
            fields: [
                ("Device Category", extractDeviceCategoryName(details["deviceCategory"])),
                ("SKU Family", details["skuFamily"] as? String),
                ("Notes", details["notes"] as? String)
            ]
        ))
        
        // Calculate total height needed
        var totalHeight: CGFloat = 40 // Top margin
        for section in sections {
            totalHeight += 25 // Section header height
            let validFields = section.fields.filter { $0.value != nil && !$0.value!.isEmpty }
            totalHeight += CGFloat(validFields.count) * 22 // Field height
            totalHeight += sectionSpacing // Section spacing
        }
        
        // Set content view height
        overviewContentView.frame = NSRect(x: 0, y: 0, width: overviewContentView.frame.width, height: totalHeight)
        
        // Now render sections from top to bottom
        var currentY = totalHeight - 20 // Start from top
        
        for section in sections {
            // Add section header
            currentY -= 25
            let headerLabel = NSTextField(labelWithString: section.header)
            headerLabel.font = NSFont.boldSystemFont(ofSize: 16)
            headerLabel.textColor = .controlAccentColor
            headerLabel.frame = NSRect(x: margin, y: currentY, width: overviewContentView.frame.width - (margin * 2), height: 20)
            overviewContentView.addSubview(headerLabel)
            
            // Add fields in this section
            for (label, value) in section.fields {
                guard let value = value, !value.isEmpty else { continue }
                
                currentY -= 22
                let labelWidth: CGFloat = 200
                let valueWidth = overviewContentView.frame.width - margin - labelWidth - margin - 10
                
                if !label.isEmpty {
                    let labelField = NSTextField(labelWithString: "\(label):")
                    labelField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
                    labelField.textColor = .labelColor
                    labelField.frame = NSRect(x: margin, y: currentY, width: labelWidth, height: 17)
                    labelField.alignment = .right
                    overviewContentView.addSubview(labelField)
                }
                
                let valueField = NSTextField(labelWithString: value)
                valueField.font = NSFont.systemFont(ofSize: 13)
                valueField.textColor = .secondaryLabelColor
                let xPos = label.isEmpty ? margin + 20 : margin + labelWidth + 10
                let adjustedWidth = label.isEmpty ? valueWidth + labelWidth - 20 : valueWidth
                valueField.frame = NSRect(x: xPos, y: currentY, width: adjustedWidth, height: 17)
                valueField.lineBreakMode = .byTruncatingTail
                valueField.toolTip = value
                valueField.isSelectable = true
                overviewContentView.addSubview(valueField)
            }
            
            currentY -= sectionSpacing
        }
        
        // Scroll to top of content
        overviewScrollView.documentView?.scroll(NSPoint(x: 0, y: overviewContentView.bounds.height))
    }
    
    private func displayAppsTab(_ apps: [[String: Any]]) {
        // Sort apps by displayName (case-insensitive)
        let sortedApps = apps.sorted { app1, app2 in
            let name1 = app1["displayName"] as? String ?? ""
            let name2 = app2["displayName"] as? String ?? ""
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
        
        // Update the data sources
        detectedApps = sortedApps  // Update the base data for filtering
        filteredApps = sortedApps
        updateAppsDisplay()
        
        // Hide status label and show table
        appsStatusLabel.isHidden = true
        appsTableView.isHidden = false
        appsSearchField.isHidden = false
        
        // Update count label
        updateAppsCountLabel()
        
        // Enable export button
        exportAppsButton.isEnabled = !apps.isEmpty
        
        // Reload table view
        appsTableView.reloadData()
    }
    
    private func displayCompliancePolicyTab(_ policies: [[String: Any]]) {
        // Clear existing content
        complianceContentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Filter out notApplicable and unknown policies
        let filteredPolicies = policies.filter { policy in
            let state = policy["state"] as? String ?? ""
            let lowerState = state.lowercased()
            return lowerState != "notapplicable" && lowerState != "unknown"
        }
        
        // Sort policies by displayName
        let applicablePolicies = filteredPolicies.sorted { policy1, policy2 in
            let name1 = policy1["displayName"] as? String ?? ""
            let name2 = policy2["displayName"] as? String ?? ""
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
        
        let margin: CGFloat = 20
        let rowHeight: CGFloat = 44 // Increased for multi-line display
        let headerHeight: CGFloat = 30
        
        // Calculate minimum height to fill the scroll view
        let scrollViewHeight = complianceScrollView.frame.height
        let totalContentHeight = headerHeight + CGFloat(applicablePolicies.count) * rowHeight + 40
        let contentHeight = max(totalContentHeight, scrollViewHeight)
        
        // Set content view frame
        complianceContentView.frame = NSRect(x: 0, y: 0, width: complianceContentView.frame.width, height: contentHeight)
        
        // Position content from the top
        var currentY = contentHeight - 20
        
        // Add section header
        currentY -= headerHeight
        let headerLabel = NSTextField(labelWithString: "Compliance Policies (\(applicablePolicies.count) applicable)")
        headerLabel.font = NSFont.boldSystemFont(ofSize: 16)
        headerLabel.textColor = .controlAccentColor
        headerLabel.frame = NSRect(x: margin, y: currentY, width: complianceContentView.frame.width - (margin * 2), height: 25)
        complianceContentView.addSubview(headerLabel)
        
        // Add policies
        for policy in applicablePolicies {
            currentY -= rowHeight
            
            let policyName = policy["displayName"] as? String ?? "Unknown Policy"
            let state = policy["state"] as? String ?? "Unknown"
            let lastReportedDateTime = policy["lastReportedDateTime"] as? String
            
            // Policy name and state
            let nameStateText = "\(policyName) = \(state.capitalized)"
            let nameField = NSTextField(labelWithString: nameStateText)
            nameField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            nameField.textColor = state.lowercased() == "compliant" ? .systemGreen : .systemOrange
            nameField.frame = NSRect(x: margin + 20, y: currentY + 20, width: complianceContentView.frame.width - margin - 40, height: 17)
            nameField.lineBreakMode = .byTruncatingTail
            nameField.isSelectable = true
            complianceContentView.addSubview(nameField)
            
            // Last reported date
            if let lastReported = lastReportedDateTime, let formattedDate = formatDateTime(lastReported) {
                let dateField = NSTextField(labelWithString: "Last Reported: \(formattedDate)")
                dateField.font = NSFont.systemFont(ofSize: 11)
                dateField.textColor = .tertiaryLabelColor
                dateField.frame = NSRect(x: margin + 20, y: currentY + 2, width: complianceContentView.frame.width - margin - 40, height: 15)
                dateField.lineBreakMode = .byTruncatingTail
                dateField.isSelectable = true
                complianceContentView.addSubview(dateField)
            }
        }
        
        complianceStatusLabel.isHidden = true
        
        // Scroll to top of content
        complianceScrollView.documentView?.scroll(NSPoint(x: 0, y: complianceContentView.bounds.height))

    }
    
    private func displayConfigurationPolicyTab(_ policies: [[String: Any]]) {
        // Clear existing content
        configContentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Filter out notApplicable and unknown policies
        let filteredPolicies = policies.filter { policy in
            let state = policy["state"] as? String ?? ""
            let lowerState = state.lowercased()
            return lowerState != "notapplicable" && lowerState != "unknown"
        }
        
        // Sort policies by displayName
        let applicablePolicies = filteredPolicies.sorted { policy1, policy2 in
            let name1 = policy1["displayName"] as? String ?? ""
            let name2 = policy2["displayName"] as? String ?? ""
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
        
        let margin: CGFloat = 20
        let rowHeight: CGFloat = 44 // Increased for multi-line display
        let headerHeight: CGFloat = 30
        
        // Calculate minimum height to fill the scroll view
        let scrollViewHeight = configScrollView.frame.height
        let totalContentHeight = headerHeight + CGFloat(applicablePolicies.count) * rowHeight + 40
        let contentHeight = max(totalContentHeight, scrollViewHeight)
        
        // Set content view frame
        configContentView.frame = NSRect(x: 0, y: 0, width: configContentView.frame.width, height: contentHeight)
        
        // Position content from the top
        var currentY = contentHeight - 20
        
        // Add section header
        currentY -= headerHeight
        let headerLabel = NSTextField(labelWithString: "Configuration Policies (\(applicablePolicies.count) applicable)")
        headerLabel.font = NSFont.boldSystemFont(ofSize: 16)
        headerLabel.textColor = .controlAccentColor
        headerLabel.frame = NSRect(x: margin, y: currentY, width: configContentView.frame.width - (margin * 2), height: 25)
        configContentView.addSubview(headerLabel)
        
        // Add policies
        for policy in applicablePolicies {
            currentY -= rowHeight
            
            let policyName = policy["displayName"] as? String ?? "Unknown Policy"
            let state = policy["state"] as? String ?? "Unknown"
            let lastReportedDateTime = policy["lastReportedDateTime"] as? String
            
            // Policy name and state (show "Succeeded" for compliant configuration policies)
            let displayState = state.lowercased() == "compliant" ? "Succeeded" : state.capitalized
            let nameStateText = "\(policyName) = \(displayState)"
            let nameField = NSTextField(labelWithString: nameStateText)
            nameField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            nameField.textColor = state.lowercased() == "compliant" ? .systemGreen : .systemOrange
            nameField.frame = NSRect(x: margin + 20, y: currentY + 20, width: configContentView.frame.width - margin - 40, height: 17)
            nameField.lineBreakMode = .byTruncatingTail
            nameField.isSelectable = true
            configContentView.addSubview(nameField)
            
            // Last reported date
            if let lastReported = lastReportedDateTime, let formattedDate = formatDateTime(lastReported) {
                let dateField = NSTextField(labelWithString: "Last Reported: \(formattedDate)")
                dateField.font = NSFont.systemFont(ofSize: 11)
                dateField.textColor = .tertiaryLabelColor
                dateField.frame = NSRect(x: margin + 20, y: currentY + 2, width: configContentView.frame.width - margin - 40, height: 15)
                dateField.lineBreakMode = .byTruncatingTail
                dateField.isSelectable = true
                configContentView.addSubview(dateField)
            }
        }
        
        configStatusLabel.isHidden = true
        
        // Scroll to top of content
        configScrollView.documentView?.scroll(NSPoint(x: 0, y: configContentView.bounds.height))

    }
    
    private func displayWindowsProtectionTab(_ state: [String: Any]) {
        // Clear existing content
        protectionContentView.subviews.forEach { $0.removeFromSuperview() }
        
        let margin: CGFloat = 20
        let sectionSpacing: CGFloat = 30
        
        // Define protection sections
        var sections: [(header: String, fields: [(label: String, value: String?)])] = []
        
        // Windows Defender Section
        sections.append((
            header: "Windows Defender Antivirus",
            fields: [
                ("Real-time Protection", formatBooleanValue(state["realTimeProtectionEnabled"])),
                ("Device State", state["deviceState"] as? String ),
                ("Antivirus Enabled", formatBooleanValue(state["antivirusRequired"])),
                ("Antimalware Version", state["antiMalwareVersion"] as? String),
                ("Signature Version", state["signatureVersion"] as? String),
                ("Engine Version", state["engineVersion"] as? String),
                ("Signature Version", state["antimalwareVersion"] as? String),
                ("Quick Scan Last Run", formatDateTime(state["lastQuickScanDateTime"] as? String)),
                ("Quick Scan Overdue", formatBooleanValue(state["quickScanOverdue"])),
                ("Quick Scan Signature Version", formatBooleanValue(state["lastQuickScanSignatureVersion"])),
                ("Full Scan Last Run", formatDateTime(state["lastFullScanDateTime"] as? String)),
                ("Full Scan Overdue", formatBooleanValue(state["fullScanOverdue"])),
                ("Full Scan Required", formatBooleanValue(state["fullScanRequired"])),
                ("Last Reported Date Time", formatDateTime(state["lastReportedDateTime"] as? String))
            ]
        ))
        
        // Firewall Section
        sections.append((
            header: "Windows Firewall",
            fields: [
                ("Firewall Enabled", formatBooleanValue(state["firewallEnabled"])),
                ("Network Firewall Enabled", formatBooleanValue(state["networkInspectionSystemEnabled"]))
            ]
        ))
        
        // Device Security Section
        sections.append((
            header: "Device Security",
            fields: [
                ("Tamper Protection Enabled", formatBooleanValue(state["tamperProtectionEnabled"])),
                ("Malware Protection Enabled", formatBooleanValue(state["malwareProtectionEnabled"])),
                ("Device Threat Protection Required", formatBooleanValue(state["deviceThreatProtectionRequiredSecurityLevel"])),
                ("Attack Surface Reduction Required", formatBooleanValue(state["attackSurfaceReductionRulesRequired"]))
            ]
        ))
        
        // Calculate total height needed
        var totalHeight: CGFloat = 40 // Top margin
        for section in sections {
            totalHeight += 25 // Section header height
            let validFields = section.fields.filter { $0.value != nil && !$0.value!.isEmpty }
            totalHeight += CGFloat(validFields.count) * 22 // Field height
            totalHeight += sectionSpacing // Section spacing
        }
        
        // Set content view height
        protectionContentView.frame = NSRect(x: 0, y: 0, width: protectionContentView.frame.width, height: totalHeight)
        
        // Now render sections from top to bottom
        var currentY = totalHeight - 20 // Start from top
        
        for section in sections {
            // Add section header
            currentY -= 25
            let headerLabel = NSTextField(labelWithString: section.header)
            headerLabel.font = NSFont.boldSystemFont(ofSize: 16)
            headerLabel.textColor = .controlAccentColor
            headerLabel.frame = NSRect(x: margin, y: currentY, width: protectionContentView.frame.width - (margin * 2), height: 20)
            protectionContentView.addSubview(headerLabel)
            
            // Add fields in this section
            for (label, value) in section.fields {
                guard let value = value, !value.isEmpty else { continue }
                
                currentY -= 22
                let labelWidth: CGFloat = 200
                let valueWidth = protectionContentView.frame.width - margin - labelWidth - margin - 10
                
                let labelField = NSTextField(labelWithString: "\(label):")
                labelField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
                labelField.textColor = .labelColor
                labelField.frame = NSRect(x: margin, y: currentY, width: labelWidth, height: 17)
                labelField.alignment = .right
                protectionContentView.addSubview(labelField)
                
                let valueField = NSTextField(labelWithString: value)
                valueField.font = NSFont.systemFont(ofSize: 13)
                valueField.textColor = .secondaryLabelColor
                valueField.frame = NSRect(x: margin + labelWidth + 10, y: currentY, width: valueWidth, height: 17)
                valueField.lineBreakMode = .byTruncatingTail
                valueField.toolTip = value
                valueField.isSelectable = true
                protectionContentView.addSubview(valueField)
            }
            
            currentY -= sectionSpacing
        }
        
        protectionStatusLabel.isHidden = true
        
        // Scroll to top of content
        protectionScrollView.documentView?.scroll(NSPoint(x: 0, y: protectionContentView.bounds.height))

    }
    
    
    // MARK: - Helper Methods for Data Formatting
    private func formatDateTime(_ dateString: String?) -> String? {
        guard let dateString = dateString, 
              dateString != "0001-01-01T00:00:00Z",
              dateString != "9999-12-31T23:59:59.9999999Z" else {
            return nil
        }
        
        // Try multiple formatters to handle different microsecond precision
        let formatters: [DateFormatter] = {
            let baseFormatter = DateFormatter()
            baseFormatter.locale = Locale(identifier: "en_US_POSIX")
            baseFormatter.timeZone = TimeZone(abbreviation: "UTC")
            
            // Create formatters for different microsecond precisions
            var formatters: [DateFormatter] = []
            
            // Format with 7 microseconds (like 2025-02-14T00:54:54.9518107Z)
            let formatter7 = baseFormatter.copy() as! DateFormatter
            formatter7.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS'Z'"
            formatters.append(formatter7)
            
            // Format with 6 microseconds (like 2025-02-09T16:22:39.254117Z)
            let formatter6 = baseFormatter.copy() as! DateFormatter
            formatter6.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            formatters.append(formatter6)
            
            // Format with 3 microseconds (standard milliseconds)
            let formatter3 = baseFormatter.copy() as! DateFormatter
            formatter3.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            formatters.append(formatter3)
            
            // Format without microseconds
            let formatter0 = baseFormatter.copy() as! DateFormatter
            formatter0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            formatters.append(formatter0)
            
            return formatters
        }()
        
        // Try each formatter until one works
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                displayFormatter.timeStyle = .short
                displayFormatter.locale = Locale.current
                return displayFormatter.string(from: date)
            }
        }
        
        // If all formatters fail, try ISO8601DateFormatter as fallback
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale.current
            return displayFormatter.string(from: date)
        }
        
        // If everything fails, return the original string
        return dateString
    }
    
    private func formatBooleanValue(_ value: Any?) -> String? {
        if let boolValue = value as? Bool {
            return boolValue ? "Yes" : "No"
        }
        return nil
    }
    
    private func formatStorageSize(_ bytes: Int64?) -> String? {
        guard let bytes = bytes, bytes > 0 else { return nil }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func extractDeviceCategoryName(_ category: Any?) -> String? {
        guard let categoryDict = category as? [String: Any],
              let displayName = categoryDict["displayName"] as? String,
              !displayName.isEmpty else {
            return nil
        }
        return displayName
    }
    
    // MARK: - Error Handling
    private func showError(_ message: String) {
        overviewStatusLabel.stringValue = message
        overviewStatusLabel.textColor = .systemRed
        overviewLoadingIndicator.stopAnimation(nil)
    }
    
    // MARK: - CSV Export
    private func exportDetectedAppsToCSV() {
        guard !filteredApps.isEmpty else {
            showExportError("No applications to export")
            return
        }
        
        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Export Detected Applications"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        
        // Generate default filename
        let deviceNameSafe = deviceName?.replacingOccurrences(of: " ", with: "_") ?? "Device"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        savePanel.nameFieldStringValue = "\(deviceNameSafe)_DetectedApps_\(timestamp).csv"
        
        savePanel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = savePanel.url else { return }
            
            do {
                let csvContent = self.generateCSVContent(from: self.filteredApps)
                try csvContent.write(to: url, atomically: true, encoding: .utf8)
                
                DispatchQueue.main.async {
                    self.showExportSuccess(url: url, count: self.filteredApps.count)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showExportError("Failed to write CSV file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func generateCSVContent(from apps: [[String: Any]]) -> String {
        var csvLines: [String] = []
        
        // CSV Header
        let headers = [
            "Application Name",
            "Version", 
            "Publisher",
            "Size (Bytes)",
            "Size (Formatted)",
            "Platform",
            "Application ID"
        ]
        csvLines.append(headers.joined(separator: ","))
        
        // CSV Data rows
        for app in apps {
            let displayName = escapeCSVField(app["displayName"] as? String ?? "")
            let version = escapeCSVField(app["version"] as? String ?? "")
            let publisher = escapeCSVField(app["publisher"] as? String ?? "")
            let sizeInBytes = app["sizeInByte"] as? Int64 ?? 0
            let sizeFormatted = formatAppSize(sizeInBytes)
            let platform = escapeCSVField(app["platform"] as? String ?? "")
            let appId = escapeCSVField(app["id"] as? String ?? "")
            
            let row = [
                displayName,
                version,
                publisher,
                "\(sizeInBytes)",
                escapeCSVField(sizeFormatted),
                platform,
                appId
            ]
            csvLines.append(row.joined(separator: ","))
        }
        
        return csvLines.joined(separator: "\n")
    }
    
    private func escapeCSVField(_ field: String) -> String {
        // Escape CSV fields that contain commas, quotes, or newlines
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
    
    private func formatAppSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 bytes" }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func showExportSuccess(url: URL, count: Int) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Export Successful"
        alert.informativeText = "Successfully exported \(count) detected applications to CSV file."
        alert.addButton(withTitle: "Open File")
        alert.addButton(withTitle: "Show in Finder") 
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(url)
        } else if response == .alertSecondButtonReturn {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }
    
    private func showExportError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Export Failed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Actions
    @IBAction func refreshButtonClicked(_ sender: Any) {
        loadDeviceDetails()
    }
    
    @IBAction func exportAppsButtonClicked(_ sender: Any) {
        exportDetectedAppsToCSV()
    }
    
    @IBAction func exportFullReport(_ sender: NSButton) {

        guard let deviceIdLabel = deviceIdLabel?.stringValue else {
            showError("No device ID available for export")
            return
        }
        
        let uuidString: String?
        if let range = deviceIdLabel.range(of: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#, options: .regularExpression) {
            uuidString = String(deviceIdLabel[range])
            print("Found UUID: \(uuidString ?? "Unknown")")
        } else {
            print("No UUID found")
            return
        }
        
        guard let deviceId = uuidString else {
            return
        }

        let reportType = "AppInvByDevice"
        
        
        WindowManager.shared.openWindow(
            identifier: "IntuneReportsViewController",
            storyboardName: "IntuneReports",
            controllerType: IntuneReportsViewController.self,
            windowTitle: "Intune Reports Export",
            defaultSize: NSSize(width: 400, height: 250),
            restoreKey: "IntuneReportsViewController",
            customization: { viewController in
                if let vc = viewController as? IntuneReportsViewController {
                    vc.preselectedReport = reportType
                    vc.preselectedFilters = ["DeviceId": deviceId]
                }
            }
        )

    }

    // MARK: - Apps Table Management
    private func updateAppsDisplay() {
        if searchText.isEmpty {
            filteredApps = detectedApps ?? []
        } else {
            filteredApps = (detectedApps ?? []).filter { app in
                let appName = app["displayName"] as? String ?? ""
                let publisher = app["publisher"] as? String ?? ""
                let version = app["version"] as? String ?? ""
                
                return appName.localizedCaseInsensitiveContains(searchText) ||
                       publisher.localizedCaseInsensitiveContains(searchText) ||
                       version.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        updateAppsCountLabel()
        appsTableView.reloadData()
    }
    
    private func updateAppsCountLabel() {
        let totalCount = detectedApps?.count ?? 0
        let filteredCount = filteredApps.count
        
        if searchText.isEmpty {
            appsCountLabel.stringValue = "\(totalCount) applications"
        } else {
            appsCountLabel.stringValue = "\(filteredCount) of \(totalCount) applications"
        }
    }
}

// MARK: - NSTableViewDataSource
extension DeviceDetailsViewController {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredApps.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredApps.count,
              let columnIdentifier = tableColumn?.identifier else { return nil }
        
        let app = filteredApps[row]
        
        // Create or reuse a cell view
        let cellView: NSTableCellView
        if let reusedView = tableView.makeView(withIdentifier: columnIdentifier, owner: self) as? NSTableCellView {
            cellView = reusedView
        } else {
            cellView = NSTableCellView()
            cellView.identifier = columnIdentifier
            
            // Create text field for the cell
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = NSColor.clear
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            cellView.textField = textField
            
            // Add constraints
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
        }
        
        // Set the cell value based on column
        let columnId = columnIdentifier.rawValue
        switch columnId {
        case "name":
            cellView.textField?.stringValue = app["displayName"] as? String ?? "Unknown App"
        case "version":
            cellView.textField?.stringValue = app["version"] as? String ?? ""
        case "publisher":
            cellView.textField?.stringValue = app["publisher"] as? String ?? ""
        case "size":
            if let sizeInBytes = app["sizeInByte"] as? Int64, sizeInBytes > 0 {
                cellView.textField?.stringValue = formatAppSize(sizeInBytes)
            } else {
                cellView.textField?.stringValue = ""
            }
        case "platform":
            cellView.textField?.stringValue = app["platform"] as? String ?? ""
        default:
            cellView.textField?.stringValue = ""
        }
        
        return cellView
    }
}

// MARK: - NSTableViewDelegate
extension DeviceDetailsViewController {
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 17
    }
}

// MARK: - NSSearchFieldDelegate
extension DeviceDetailsViewController {
    func searchFieldDidEndSearching(_ sender: NSSearchField) {
        searchText = sender.stringValue
        updateAppsDisplay()
    }
    
    func searchFieldDidStartSearching(_ sender: NSSearchField) {
        // Optional: Handle search start if needed
    }
    
    func controlTextDidChange(_ obj: Notification) {
        if let searchField = obj.object as? NSSearchField, searchField == appsSearchField {
            searchText = searchField.stringValue
            updateAppsDisplay()
        }
    }
}
