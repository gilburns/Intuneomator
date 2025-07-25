//
//  IntuneReportsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/17/25.
//

import Cocoa


class IntuneReportsViewController: NSViewController {
    
    @IBOutlet weak var reportNamePopUp: NSPopUpButton!
    @IBOutlet weak var runReportButton: NSButton!
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
    
    
    // MARK: - View Lifecycle
    /// Lifecycle callback invoked when the view loads.
    /// Sets up the assignments file path, table view delegate/data source, and loads existing assignments.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    // MARK: - Public Methods
    
    /// Preselects a specific report type in the popup menu
    /// - Parameter reportType: The report type to preselect (e.g., "Devices with Inventory")
    func preselectReportType(_ reportType: String) {
        // Ensure the popup is set up first
        if reportNamePopUp.numberOfItems == 0 {
            setupPopups()
        }
        
        // Find and select the matching item
        for i in 0..<reportNamePopUp.numberOfItems {
            if let title = reportNamePopUp.item(at: i)?.title, title == reportType {
                reportNamePopUp.selectItem(at: i)
                Logger.info("Preselected report type: \(reportType)", category: .core, toUserDirectory: true)
                return
            }
        }
        
        Logger.warning("Could not find report type '\(reportType)' in popup menu", category: .core, toUserDirectory: true)
    }
    
    
    
    // MARK: - UI Setup
    private func setupUI() {
        setupPopups()
        setupStatusControls()
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
        
        let menuItems: [MenuItemData] = [
            MenuItemData(title: "Active Malware", tooltip: "Intune Location: Under Endpoint Security > Antivirus > Win10 detected malware"),
            MenuItemData(title: "ADMXSettings By Device By Policy", tooltip: "Intune Location: Under Reports > Device management > Device Configuration"),
            MenuItemData(title: "All Apps List", tooltip: "Intune Location: Under Apps > All Apps"),
            MenuItemData(title: "All Device Certificates", tooltip: "Intune Location: Under Devices > Monitor > Certificates"),
            MenuItemData(title: "App Install Status Aggregate", tooltip: "Intune Location: Under Apps > Monitor > App install status"),
            MenuItemData(title: "App Inv Aggregate", tooltip: "Intune Location: Under Apps > Monitor > Discovered apps > Export "),
            MenuItemData(title: "App Inv By Device", tooltip: "Intune Location: Under Devices > All Devices > Device > Discovered Apps "),
            MenuItemData(title: "App Inv Raw Data", tooltip: "Intune Location: Under Apps > Monitor > Discovered apps > Export "),
            MenuItemData(title: "Autopilot V1Deployment Status", tooltip: "Intune Location: Under Devices > Windows > Enrollment > Windows Autopilot"),
            MenuItemData(title: "Autopilot V2Deployment Status", tooltip: "Intune Location: Under Devices > Windows > Enrollment > Windows Autopilot"),
            MenuItemData(title: "Autopilot V2Deployment Status Detailed App Info", tooltip: "Intune Location: Under Devices > Windows > Enrollment > Windows Autopilot"),
            MenuItemData(title: "Autopilot V2Deployment Status Detailed Script Info", tooltip: "Intune Location: Under Devices > Windows > Enrollment > Windows Autopilot"),
            MenuItemData(title: "BRBattery By Model", tooltip: "Intune Location: Under Reports > Endpoint analytics > Battery health > select model performance"),
            MenuItemData(title: "BRBattery By Os", tooltip: "Intune Location: Under Reports > Endpoint analytics > Battery health > select OS performance"),
            MenuItemData(title: "BRDevice Battery Agg", tooltip: "Intune Location: Under Reports > Endpoint analytics > Battery health > select device performance"),
            MenuItemData(title: "BREnergy Usage", tooltip: "Intune Location: Under Reports > Endpoint analytics > Battery health"),
            MenuItemData(title: "Catalog Apps Update List", tooltip: "Intune Location: Under Apps > Monitor > Enterprise App Catalog apps with updates"),
            MenuItemData(title: "Certificates By RAPolicy", tooltip: "Intune Location: Under Devices > Monitor > Certificates"),
            MenuItemData(title: "Comanaged Device Workloads", tooltip: "Intune Location: Under Reports > Cloud attached devices > Reports > Co-Managed Workloads"),
            MenuItemData(title: "Comanagement Eligibility Tenant Attached Devices", tooltip: "Intune Location: Under Reports > Cloud attached devices > Reports > Co-Management Eligibility"),
            MenuItemData(title: "Configuration Policy Aggregate", tooltip: "Intune Location: Under Devices > Manage devices > Configuration"),
            MenuItemData(title: "Configuration Policy Aggregate V3", tooltip: "Intune Location: Under Devices > Manage devices > Configuration"),
            MenuItemData(title: "Configuration Policy Device Aggregates", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > select specific policy"),
            MenuItemData(title: "Configuration Policy Device Aggregates V3", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > select specific policy"),
            MenuItemData(title: "Configuration Policy Device Aggregates With PF", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > select specific policy"),
            MenuItemData(title: "Configuration Policy Device Aggregates With PFV3", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > select specific policy"),
            MenuItemData(title: "Defender Agents", tooltip: "Intune Location: Under Reports > MicrosoftDefender > Reports > Agent Status"),
            MenuItemData(title: "Dependent Apps Install Status", tooltip: "Intune Location: Under Apps > All Apps > select the dependent app > Device install status"),
            MenuItemData(title: "Device Assignment Status By Configuration Policy", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > select specific policy > Device assignment status"),
            MenuItemData(title: "Device Assignment Status By Configuration Policy For AC", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > select specific policy > Device assignment status"),
            MenuItemData(title: "Device Assignment Status By Configuration Policy For ASR", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > select specific policy > Device assignment status"),
            MenuItemData(title: "Device Assignment Status By Configuration Policy For EDR", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > select specific policy > Device assignment status"),
            MenuItemData(title: "Device Assignment Status By Configuration Policy V3", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > select specific policy > Device assignment status"),
            MenuItemData(title: "Device Compliance", tooltip: "Intune Location: Device Compliance Org"),
            MenuItemData(title: "Device Compliance Trend", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Configuration Policy Statuses", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Configuration Policy Statuses V3", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Configuration Policy Statuses With PF", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Configuration Policy Statuses With PFV3", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Enrollment Failures", tooltip: "Intune Location: Under Devices > Device onboarding > Enrollment > Monitor"),
            MenuItemData(title: "Device Failures By Feature Update Policy", tooltip: "Intune Location: Under Devices > Monitor > Failure for feature updates > click on error"),
            MenuItemData(title: "Device Install Status By App", tooltip: "Intune Location: Under Apps > All Apps > Select an individual app"),
            MenuItemData(title: "Device Intent Per Setting Status", tooltip: "Intune Location: Under Devices > All Devices > select specific device"),
            MenuItemData(title: "Device Inventory Policy Statuses V3", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > select specific policy > Device assignment status"),
            MenuItemData(title: "Device Inventory Policy Statuses With PF", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > select specific policy > Device assignment status"),
            MenuItemData(title: "Device Non Compliance", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Policies Compliance Report", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Policies Compliance Report V3", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Policy Settings Compliance Report", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Policy Settings Compliance Report V3", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Run States By Proactive Remediation", tooltip: "Intune Location: Under Reports > Endpoint Analytics > Proactive remediations > Select a remediation > Device status"),
            MenuItemData(title: "Device Run States By Script", tooltip: "Intune Location: Under Devices > Manage devices > Scripts and remediations > select specific script > Device status"),
            MenuItemData(title: "Devices", tooltip: "Intune Location: All devices list"),
            MenuItemData(title: "Devices By App Inv", tooltip: "Intune Location: Under Apps > Monitor > Discovered apps > Discovered app> Export "),
            MenuItemData(title: "Devices Status By Policy Platform Compliance Report", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Devices Status By Policy Platform Compliance Report V3", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Devices Status By Setting Report", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Devices Status By Setting Report V3", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Status By Compliace Policy Report", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Status By Compliace Policy Report V3", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Status By Compliance Policy Setting Report", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Status By Compliance Policy Setting Report V3", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Statuses By Configuration Profile", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > Policies > select specific policy > Device and user check-in status"),
            MenuItemData(title: "Device Statuses By Configuration Profile For App Control", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > Policies > select specific policy > Device and user check-in status"),
            MenuItemData(title: "Device Statuses By Configuration Profile For ASR", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > Policies > select specific policy > Device and user check-in status"),
            MenuItemData(title: "Device Statuses By Configuration Profile For EDR", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > Policies > select specific policy > Device and user check-in status"),
            MenuItemData(title: "Device Statuses By Configuration Profile V3", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > Policies > select specific policy > Device and user check-in status"),
            MenuItemData(title: "Device Statuses By Configuration Profile With PF", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > Policies > select specific policy > Device and user check-in status"),
            MenuItemData(title: "Device Statuses By Configuration Profile With PFV3", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > Policies > select specific policy > Device and user check-in status"),
            MenuItemData(title: "Device Statuses By Inventory Policy With PF", tooltip: "Intune Location: Under Devices > Manage devices > Compliance"),
            MenuItemData(title: "Device Statuses By Inventory Policy With PFV3", tooltip: "Intune Location: Under Devices > Manage devices > Compliance"),
            MenuItemData(title: "Device Status Summary By Compliace Policy Report", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Status Summary By Compliace Policy Report V3", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Status Summary By Compliance Policy Settings Report", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Device Status Summary By Compliance Policy Settings Report V3", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Devices With Inventory", tooltip: "Intune Location: Under Devices > All Devices > Export"),
            MenuItemData(title: "Devices Without Compliance Policy", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Devices Without Compliance Policy V3", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Driver Update Policy Status Summary", tooltip: "Intune Location: Under Devices > Manage updates > Windows updates > Driver updates"),
            MenuItemData(title: "EAAnomaly Asset", tooltip: "Intune Location: Under Reports > Endpoint analytics > Anomalies"),
            MenuItemData(title: "EAAnomaly Asset V2", tooltip: "Intune Location: Under Reports > Endpoint analytics > Anomalies"),
            MenuItemData(title: "EAAnomaly Device Asset", tooltip: "Intune Location: Under Reports > Endpoint analytics > Anomalies"),
            MenuItemData(title: "EAAnomaly Device Asset V2", tooltip: "Intune Location: Under Reports > Endpoint analytics > Anomalies"),
            MenuItemData(title: "EAApp Performance", tooltip: "Intune Location: Under Reports > Endpoint analytics > Application reliability > App performance"),
            MenuItemData(title: "EADevice Model Performance", tooltip: "Intune Location: Under Reports > Endpoint analytics"),
            MenuItemData(title: "EADevice Model Performance V2", tooltip: "Intune Location: Under Reports > Endpoint analytics"),
            MenuItemData(title: "EADevice Performance", tooltip: "Intune Location: Under Reports > Endpoint analytics"),
            MenuItemData(title: "EADevice Performance V2", tooltip: "Intune Location: Under Reports > Endpoint analytics"),
            MenuItemData(title: "EADevice Scores V2", tooltip: "Intune Location: Under Reports > Endpoint analytics > Device scores"),
            MenuItemData(title: "EAModel Scores V2", tooltip: "Intune Location: Under Reports > Endpoint analytics > Model scores"),
            MenuItemData(title: "EAOSVersions Performance", tooltip: "Intune Location: Under Reports > Endpoint analytics > Application reliability > OS versions performance"),
            MenuItemData(title: "EAResource Perf Agg By Device", tooltip: "Intune Location: Under Reports > Endpoint analytics > Resource performance > Device performance"),
            MenuItemData(title: "EAResource Perf Agg By Model", tooltip: "Intune Location: Under Reports > Endpoint analytics > Resource performance > Model performance"),
            MenuItemData(title: "EAResource Perf Cpu Spike Process", tooltip: "Intune Location: Under Reports > Endpoint analytics > Resource performance > Resource performance score"),
            MenuItemData(title: "EAResource Perf Ram Spike Process", tooltip: "Intune Location: Under Reports > Endpoint analytics > Resource performance > Resource performance score"),
            MenuItemData(title: "EAStartup Perf Device Performance", tooltip: "Intune Location: Under Reports > Endpoint analytics > Startup performance > Device performance"),
            MenuItemData(title: "EAStartup Perf Device Performance V2", tooltip: "Intune Location: Under Reports > Endpoint analytics > Startup performance > Device performance"),
            MenuItemData(title: "EAStartup Perf Device Processes", tooltip: "Intune Location: Under Reports > Endpoint analytics > Startup performance > Startup processes"),
            MenuItemData(title: "EAStartup Perf Model Performance", tooltip: "Intune Location: Under Reports > Endpoint analytics > Startup performance > Model performance"),
            MenuItemData(title: "EAStartup Perf Model Performance V2", tooltip: "Intune Location: Under Reports > Endpoint analytics > Startup performance > Model performance"),
            MenuItemData(title: "EAWFADevice List", tooltip: "Intune Location: Under Reports > Endpoint analytics > Work from anywhere > Device performance"),
            MenuItemData(title: "EAWFAModel Performance", tooltip: "Intune Location: Under Reports > Endpoint analytics > Work from anywhere > Model performance"),
            MenuItemData(title: "EAWFAPer Device Performance", tooltip: "Intune Location: Under Reports > Endpoint analytics > Work from anywhere > Device performance"),
            MenuItemData(title: "Enrollment Activity", tooltip: "Intune Location: Under Dashboard > Device enrollmentand/or Intune enrolled devices"),
            MenuItemData(title: "Enrollment Configuration Policies By Device", tooltip: "Intune Location: Under Devices > Device onboarding > Enrollment"),
            MenuItemData(title: "Epm Aggregation Report By Application", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by applications"),
            MenuItemData(title: "Epm Aggregation Report By Application V2", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by applications"),
            MenuItemData(title: "Epm Aggregation Report By Publisher", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by publisher"),
            MenuItemData(title: "Epm Aggregation Report By Publisher V2", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by publisher"),
            MenuItemData(title: "Epm Aggregation Report By User", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by user"),
            MenuItemData(title: "Epm Aggregation Report By User App By Month", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by user"),
            MenuItemData(title: "Epm Aggregation Report By User V2", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by user"),
            MenuItemData(title: "Epm Denied Report", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report"),
            MenuItemData(title: "Epm Elevation Report By User App By Day To Reporting", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report"),
            MenuItemData(title: "Epm Elevation Report Elevation Event", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report"),
            MenuItemData(title: "Epm Insights Elevation Trend", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report"),
            MenuItemData(title: "Epm Insights Most Frequent Elevations", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report"),
            MenuItemData(title: "Epm Insights Report", tooltip: "Intune Location: Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report"),
            MenuItemData(title: "Feature Update Device State", tooltip: "Intune Location: Under Reports > Window Updates > Reports> Windows Feature Update Report "),
            MenuItemData(title: "Feature Update Policy Failures Aggregate", tooltip: "Intune Location: Under Devices > Monitor > Failure for feature updates"),
            MenuItemData(title: "Feature Update Policy Status Summary", tooltip: "Intune Location: Under Devices > Manage updates > Windows updates > Feature updates"),
            MenuItemData(title: "Filtered Apps List", tooltip: "Intune Location: Under Apps > All Apps"),
            MenuItemData(title: "Firewall Status", tooltip: "Intune Location: Under Reports > Firewall > MDM Firewall status for Windows 10 and later"),
            MenuItemData(title: "Firewall Unhealthy Status", tooltip: "Intune Location: Under Reports > Endpoint security > Firewall"),
            MenuItemData(title: "GPAnalytics Setting Migration Readiness", tooltip: "Intune Location: Under Reports > Group policy analytics > Reports > Group policy migration readiness"),
            MenuItemData(title: "Inventory Policy Device Aggregates V3", tooltip: "Intune Location: Under Devices > Monitor"),
            MenuItemData(title: "Inventory Policy Device Aggregates With PF", tooltip: "Intune Location: Under Devices > Monitor"),
            MenuItemData(title: "MAMApp Configuration Status", tooltip: "Intune Location: Under Apps > Monitor > App protection status > App configuration report"),
            MenuItemData(title: "MAMApp Configuration Status Scoped V2", tooltip: "Intune Location: Under Apps > Monitor"),
            MenuItemData(title: "MAMApp Configuration Status V2", tooltip: "Intune Location: Under Apps > Monitor"),
            MenuItemData(title: "MAMApp Protection Status", tooltip: "Intune Location: Under Apps > Monitor > App protection status > App protection report: iOS, Android"),
            MenuItemData(title: "MAMApp Protection Status Scoped V2", tooltip: "Intune Location: Under Apps > Monitor"),
            MenuItemData(title: "MAMApp Protection Status V2", tooltip: "Intune Location: Under Apps > Monitor"),
            MenuItemData(title: "Malware", tooltip: "Intune Location: Under Reports > MicrosoftDefender > Reports > Detected malware"),
            MenuItemData(title: "MEMUpgrade Readiness Org Asset", tooltip: "Intune Location: Under Devices"),
            MenuItemData(title: "Non Compliant Compliance Policies Aggregate", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Non Compliant Compliance Policies Aggregate V3", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Non Compliant Configuration Policies Aggregate With PF", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Non Compliant Configuration Policies Aggregate With PFV3", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Noncompliant Devices And Settings", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Noncompliant Devices And Settings V3", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Non Compliant Devices By Compliance Policy", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Non Compliant Devices By Compliance Policy V3", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Noncompliant Devices To Be Retired", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Org Apps Install Status", tooltip: "Intune Location: Under Apps > Monitor > App install status"),
            MenuItemData(title: "Org Device Install Status", tooltip: "Intune Location: Under Devices > Monitor"),
            MenuItemData(title: "Per Setting Device Summary By Configuration Policy", tooltip: "Intune Location: Under Devices > Monitor > Configuration profiles"),
            MenuItemData(title: "Per Setting Device Summary By Configuration Policy For App Control", tooltip: "Intune Location: Under Devices > Monitor > Configuration profiles"),
            MenuItemData(title: "Per Setting Device Summary By Configuration Policy For EDR", tooltip: "Intune Location: Under Devices > Monitor > Configuration profiles"),
            MenuItemData(title: "Per Setting Device Summary By Inventory Policy", tooltip: "Intune Location: Under Devices > Monitor > Configuration profiles"),
            MenuItemData(title: "Per Setting Device Summary By Inventory Policy V3", tooltip: "Intune Location: Under Devices > Monitor > Configuration profiles"),
            MenuItemData(title: "Per Setting Summary By Device Configuration Policy", tooltip: "Intune Location: Under Devices > Monitor > Configuration profiles"),
            MenuItemData(title: "Policies", tooltip: "Intune Location: Under Devices > Manage Device > select specific policy type"),
            MenuItemData(title: "Policy Compliance Agg Report", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Policy Compliance Agg Report V3", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Policy Non Compliance Agg", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Policy Non Compliance Agg Ver3", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Policy Non Compliance New", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Policy Non Compliance New V3", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Policy Run States By Proactive Remediation", tooltip: "Intune Location: Under Reports > Endpoint analytics"),
            MenuItemData(title: "Quality Update Device Errors By Policy", tooltip: "Intune Location: Under Devices > Monitor > Windows Expedited update failures > Select a profile"),
            MenuItemData(title: "Quality Update Device Status By Policy", tooltip: "Intune Location: Under Reports > Windows updates > Reports > Windows Expedited Update Report"),
            MenuItemData(title: "Quality Update Policy Status Summary", tooltip: "Intune Location: Under Reports > Device management > Windows updates"),
            MenuItemData(title: "Remote Assistance Sessions", tooltip: "Intune Location: Under Reports > Endpoint analytics"),
            MenuItemData(title: "Resource Performance Aggregate By Device", tooltip: "Intune Location: Under Reports > Endpoint analytics"),
            MenuItemData(title: "Resource Performance Aggregate By Model", tooltip: "Intune Location: Under Reports > Endpoint analytics"),
            MenuItemData(title: "Setting Compliance Agg Report", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Setting Compliance Agg Report V3", tooltip: "Intune Location: Under Reports > Device management > Device compliance"),
            MenuItemData(title: "Ticketing Security Task Apps List", tooltip: "Intune Location: Under Endpoint security > Security tasks"),
            MenuItemData(title: "Tpm Attestation Status", tooltip: "Intune Location: Under Devices > Manage devices > Configuration > Monitor > Device encryption status"),
            MenuItemData(title: "Unhealthy Defender Agents", tooltip: "Intune Location: Under Endpoint Security > Antivirus > Win10 Unhealthy Endpoints"),
            MenuItemData(title: "User Install Status Aggregate By App", tooltip: "Intune Location: Under Apps > All Apps > Select an individual app"),
            MenuItemData(title: "Users", tooltip: "Intune Location: Under Users"),
            MenuItemData(title: "User Scale Test", tooltip: "Intune Location: Under Reports > Endpoint analytics"),
            MenuItemData(title: "Windows Device Health Attestation Report", tooltip: "Intune Location: Under Reports > Device management > Device Compliance > Reports"),
            MenuItemData(title: "Windows Update Per Policy Per Device Status", tooltip: "Intune Location: Under Devices > Manage updates > Windows updates"),
            MenuItemData(title: "Work From Anywhere Device List", tooltip: "Intune Location: Under Reports > Endpoint analytics > Work from anywhere"),
        ]

        let menu = NSMenu()
        menuItems.forEach { itemData in
            let menuItem = NSMenuItem(title: itemData.title, action: nil, keyEquivalent: "")
            menuItem.toolTip = itemData.tooltip
            menu.addItem(menuItem)
        }
        reportNamePopUp.menu = menu
        
        // Default selection (can be overridden by preselectReportType)
        reportNamePopUp.selectItem(at: 0)
    }

    
    // MARK: - Actions
    @IBAction func runReportButtonClicked(_ sender: Any) {
        showExportFullReportDialog()
    }
    
    @IBAction func cancelButtonClicked(_ sender: Any) {
        cancelCurrentExport()
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
        var reportType: String?
        var intuneLocation: String?

        guard let selectedTitle = reportNamePopUp.titleOfSelectedItem, !selectedTitle.isEmpty else {
            return nil
        }
        let reportName = selectedTitle
        
        switch reportName {
        case "Active Malware":
            reportType = "ActiveMalware"
        case "ADMX Settings By Device By Policy":
            reportType = "ADMXSettingsByDeviceByPolicy"
        case "All Apps List":
            reportType = "AllAppsList"
        case "All Device Certificates":
            reportType = "AllDeviceCertificates"
        case "App Install Status Aggregate":
            reportType = "AppInstallStatusAggregate"
        case "App Inv Aggregate":
            reportType = "AppInvAggregate"
        case "App Inv By Device":
            reportType = "AppInvByDevice"
        case "App Inv Raw Data":
            reportType = "AppInvRawData"
        case "Autopilot V1 Deployment Status":
            reportType = "AutopilotV1DeploymentStatus"
        case "Autopilot V2 Deployment Status":
            reportType = "AutopilotV2DeploymentStatus"
        case "Autopilot V2 Deployment Status Detailed App Info":
            reportType = "AutopilotV2DeploymentStatusDetailedAppInfo"
        case "Autopilot V2 Deployment Status Detailed Script Info":
            reportType = "AutopilotV2DeploymentStatusDetailedScriptInfo"
        case "BRBattery By Model":
            reportType = "BRBatteryByModel"
        case "BRBattery By Os":
            reportType = "BRBatteryByOs"
        case "BRDevice Battery Agg":
            reportType = "BRDeviceBatteryAgg"
        case "BREnergy Usage":
            reportType = "BREnergyUsage"
        case "Catalog Apps Update List":
            reportType = "CatalogAppsUpdateList"
        case "Certificates By RAPolicy":
            reportType = "CertificatesByRAPolicy"
        case "Comanaged Device Workloads":
            reportType = "ComanagedDeviceWorkloads"
        case "Comanagement Eligibility Tenant Attached Devices":
            reportType = "ComanagementEligibilityTenantAttachedDevices"
        case "Configuration Policy Aggregate":
            reportType = "ConfigurationPolicyAggregate"
        case "Configuration Policy Aggregate V3":
            reportType = "ConfigurationPolicyAggregateV3"
        case "Configuration Policy Device Aggregates":
            reportType = "ConfigurationPolicyDeviceAggregates"
        case "Configuration Policy Device Aggregates V3":
            reportType = "ConfigurationPolicyDeviceAggregatesV3"
        case "Configuration Policy Device Aggregates With PF":
            reportType = "ConfigurationPolicyDeviceAggregatesWithPF"
        case "Configuration Policy Device Aggregates With PFV3":
            reportType = "ConfigurationPolicyDeviceAggregatesWithPFV3"
        case "Defender Agents":
            reportType = "DefenderAgents"
        case "Dependent Apps Install Status":
            reportType = "DependentAppsInstallStatus"
        case "Device Assignment Status By Configuration Policy":
            reportType = "DeviceAssignmentStatusByConfigurationPolicy"
        case "Device Assignment Status By Configuration Policy For AC":
            reportType = "DeviceAssignmentStatusByConfigurationPolicyForAC"
        case "Device Assignment Status By Configuration Policy For ASR":
            reportType = "DeviceAssignmentStatusByConfigurationPolicyForASR"
        case "Device Assignment Status By Configuration Policy For EDR":
            reportType = "DeviceAssignmentStatusByConfigurationPolicyForEDR"
        case "Device Assignment Status By Configuration Policy V3":
            reportType = "DeviceAssignmentStatusByConfigurationPolicyV3"
        case "Device Compliance":
            reportType = "DeviceCompliance"
        case "Device Compliance Trend":
            reportType = "DeviceComplianceTrend"
        case "Device Configuration Policy Statuses":
            reportType = "DeviceConfigurationPolicyStatuses"
        case "Device Configuration Policy Statuses V3":
            reportType = "DeviceConfigurationPolicyStatusesV3"
        case "Device Configuration Policy Statuses With PF":
            reportType = "DeviceConfigurationPolicyStatusesWithPF"
        case "Device Configuration Policy Statuses With PFV3":
            reportType = "DeviceConfigurationPolicyStatusesWithPFV3"
        case "Device Enrollment Failures":
            reportType = "DeviceEnrollmentFailures"
        case "Device Failures By Feature Update Policy":
            reportType = "DeviceFailuresByFeatureUpdatePolicy"
        case "Device Install Status By App":
            reportType = "DeviceInstallStatusByApp"
        case "Device Intent Per Setting Status":
            reportType = "DeviceIntentPerSettingStatus"
        case "Device Inventory Policy Statuses V3":
            reportType = "DeviceInventoryPolicyStatusesV3"
        case "Device Inventory Policy Statuses With PF":
            reportType = "DeviceInventoryPolicyStatusesWithPF"
        case "Device Non Compliance":
            reportType = "DeviceNonCompliance"
        case "Device Policies Compliance Report":
            reportType = "DevicePoliciesComplianceReport"
        case "Device Policies Compliance Report V3":
            reportType = "DevicePoliciesComplianceReportV3"
        case "Device Policy Settings Compliance Report":
            reportType = "DevicePolicySettingsComplianceReport"
        case "Device Policy Settings Compliance Report V3":
            reportType = "DevicePolicySettingsComplianceReportV3"
        case "Device Run States By Proactive Remediation":
            reportType = "DeviceRunStatesByProactiveRemediation"
        case "Device Run States By Script":
            reportType = "DeviceRunStatesByScript"
        case "Devices":
            reportType = "Devices"
        case "Devices By App Inv":
            reportType = "DevicesByAppInv"
        case "Devices Status By Policy Platform Compliance Report":
            reportType = "DevicesStatusByPolicyPlatformComplianceReport"
        case "Devices Status By Policy Platform Compliance Report V3":
            reportType = "DevicesStatusByPolicyPlatformComplianceReportV3"
        case "Devices Status By Setting Report":
            reportType = "DevicesStatusBySettingReport"
        case "Devices Status By Setting Report V3":
            reportType = "DevicesStatusBySettingReportV3"
        case "Device Status By Compliace Policy Report":
            reportType = "DeviceStatusByCompliacePolicyReport"
        case "Device Status By Compliace Policy Report V3":
            reportType = "DeviceStatusByCompliacePolicyReportV3"
        case "Device Status By Compliance Policy Setting Report":
            reportType = "DeviceStatusByCompliancePolicySettingReport"
        case "Device Status By Compliance Policy Setting Report V3":
            reportType = "DeviceStatusByCompliancePolicySettingReportV3"
        case "Device Statuses By Configuration Profile":
            reportType = "DeviceStatusesByConfigurationProfile"
        case "Device Statuses By Configuration Profile For App Control":
            reportType = "DeviceStatusesByConfigurationProfileForAppControl"
        case "Device Statuses By Configuration Profile For ASR":
            reportType = "DeviceStatusesByConfigurationProfileForASR"
        case "Device Statuses By Configuration Profile For EDR":
            reportType = "DeviceStatusesByConfigurationProfileForEDR"
        case "Device Statuses By Configuration Profile V3":
            reportType = "DeviceStatusesByConfigurationProfileV3"
        case "Device Statuses By Configuration Profile With PF":
            reportType = "DeviceStatusesByConfigurationProfileWithPF"
        case "Device Statuses By Configuration Profile With PFV3":
            reportType = "DeviceStatusesByConfigurationProfileWithPFV3"
        case "Device Statuses By Inventory Policy With PF":
            reportType = "DeviceStatusesByInventoryPolicyWithPF"
        case "Device Statuses By Inventory Policy With PFV3":
            reportType = "DeviceStatusesByInventoryPolicyWithPFV3"
        case "Device Status Summary By Compliace Policy Report":
            reportType = "DeviceStatusSummaryByCompliacePolicyReport"
        case "Device Status Summary By Compliace Policy Report V3":
            reportType = "DeviceStatusSummaryByCompliacePolicyReportV3"
        case "Device Status Summary By Compliance Policy Settings Report":
            reportType = "DeviceStatusSummaryByCompliancePolicySettingsReport"
        case "Device Status Summary By Compliance Policy Settings Report V3":
            reportType = "DeviceStatusSummaryByCompliancePolicySettingsReportV3"
        case "Devices With Inventory":
            reportType = "DevicesWithInventory"
        case "Devices Without Compliance Policy":
            reportType = "DevicesWithoutCompliancePolicy"
        case "Devices Without Compliance Policy V3":
            reportType = "DevicesWithoutCompliancePolicyV3"
        case "Driver Update Policy Status Summary":
            reportType = "DriverUpdatePolicyStatusSummary"
        case "EAAnomaly Asset":
            reportType = "EAAnomalyAsset"
        case "EAAnomaly Asset V2":
            reportType = "EAAnomalyAssetV2"
        case "EAAnomaly Device Asset":
            reportType = "EAAnomalyDeviceAsset"
        case "EAAnomaly Device Asset V2":
            reportType = "EAAnomalyDeviceAssetV2"
        case "EAApp Performance":
            reportType = "EAAppPerformance"
        case "EADevice Model Performance":
            reportType = "EADeviceModelPerformance"
        case "EADevice Model Performance V2":
            reportType = "EADeviceModelPerformanceV2"
        case "EADevice Performance":
            reportType = "EADevicePerformance"
        case "EADevice Performance V2":
            reportType = "EADevicePerformanceV2"
        case "EADevice Scores V2":
            reportType = "EADeviceScoresV2"
        case "EAModel Scores V2":
            reportType = "EAModelScoresV2"
        case "EAOSVersions Performance":
            reportType = "EAOSVersionsPerformance"
        case "EAResource Perf Agg By Device":
            reportType = "EAResourcePerfAggByDevice"
        case "EAResource Perf Agg By Model":
            reportType = "EAResourcePerfAggByModel"
        case "EAResource Perf Cpu Spike Process":
            reportType = "EAResourcePerfCpuSpikeProcess"
        case "EAResource Perf Ram Spike Process":
            reportType = "EAResourcePerfRamSpikeProcess"
        case "EAStartup Perf Device Performance":
            reportType = "EAStartupPerfDevicePerformance"
        case "EAStartup Perf Device Performance V2":
            reportType = "EAStartupPerfDevicePerformanceV2"
        case "EAStartup Perf Device Processes":
            reportType = "EAStartupPerfDeviceProcesses"
        case "EAStartup Perf Model Performance":
            reportType = "EAStartupPerfModelPerformance"
        case "EAStartup Perf Model Performance V2":
            reportType = "EAStartupPerfModelPerformanceV2"
        case "EAWFADevice List":
            reportType = "EAWFADeviceList"
        case "EAWFAModel Performance":
            reportType = "EAWFAModelPerformance"
        case "EAWFAPer Device Performance":
            reportType = "EAWFAPerDevicePerformance"
        case "Enrollment Activity":
            reportType = "EnrollmentActivity"
        case "Enrollment Configuration Policies By Device":
            reportType = "EnrollmentConfigurationPoliciesByDevice"
        case "Epm Aggregation Report By Application":
            reportType = "EpmAggregationReportByApplication"
        case "Epm Aggregation Report By Application V2":
            reportType = "EpmAggregationReportByApplicationV2"
        case "Epm Aggregation Report By Publisher":
            reportType = "EpmAggregationReportByPublisher"
        case "Epm Aggregation Report By Publisher V2":
            reportType = "EpmAggregationReportByPublisherV2"
        case "Epm Aggregation Report By User":
            reportType = "EpmAggregationReportByUser"
        case "Epm Aggregation Report By User App By Month":
            reportType = "EpmAggregationReportByUserAppByMonth"
        case "Epm Aggregation Report By User V2":
            reportType = "EpmAggregationReportByUserV2"
        case "Epm Denied Report":
            reportType = "EpmDeniedReport"
        case "Epm Elevation Report By User App By Day To Reporting":
            reportType = "EpmElevationReportByUserAppByDayToReporting"
        case "Epm Elevation Report Elevation Event":
            reportType = "EpmElevationReportElevationEvent"
        case "Epm Insights Elevation Trend":
            reportType = "EpmInsightsElevationTrend"
        case "Epm Insights Most Frequent Elevations":
            reportType = "EpmInsightsMostFrequentElevations"
        case "Epm Insights Report":
            reportType = "EpmInsightsReport"
        case "Feature Update Device State":
            reportType = "FeatureUpdateDeviceState"
        case "Feature Update Policy Failures Aggregate":
            reportType = "FeatureUpdatePolicyFailuresAggregate"
        case "Feature Update Policy Status Summary":
            reportType = "FeatureUpdatePolicyStatusSummary"
        case "Filtered Apps List":
            reportType = "FilteredAppsList"
        case "Firewall Status":
            reportType = "FirewallStatus"
        case "Firewall Unhealthy Status":
            reportType = "FirewallUnhealthyStatus"
        case "GPAnalytics Setting Migration Readiness":
            reportType = "GPAnalyticsSettingMigrationReadiness"
        case "Inventory Policy Device Aggregates V3":
            reportType = "InventoryPolicyDeviceAggregatesV3"
        case "Inventory Policy Device Aggregates With PF":
            reportType = "InventoryPolicyDeviceAggregatesWithPF"
        case "MAM App Configuration Status":
            reportType = "MAMAppConfigurationStatus"
        case "MAM App Configuration Status Scoped V2":
            reportType = "MAMAppConfigurationStatusScopedV2"
        case "MAM App Configuration Status V2":
            reportType = "MAMAppConfigurationStatusV2"
        case "MAM App Protection Status":
            reportType = "MAMAppProtectionStatus"
        case "MAM App Protection Status Scoped V2":
            reportType = "MAMAppProtectionStatusScopedV2"
        case "MAM App Protection Status V2":
            reportType = "MAMAppProtectionStatusV2"
        case "Malware":
            reportType = "Malware"
        case "MEM Upgrade Readiness Org Asset":
            reportType = "MEMUpgradeReadinessOrgAsset"
        case "Non Compliant Compliance Policies Aggregate":
            reportType = "NonCompliantCompliancePoliciesAggregate"
        case "Non Compliant Compliance Policies Aggregate V3":
            reportType = "NonCompliantCompliancePoliciesAggregateV3"
        case "Non Compliant Configuration Policies Aggregate With PF":
            reportType = "NonCompliantConfigurationPoliciesAggregateWithPF"
        case "Non Compliant Configuration Policies Aggregate With PFV3":
            reportType = "NonCompliantConfigurationPoliciesAggregateWithPFV3"
        case "Noncompliant Devices And Settings":
            reportType = "NoncompliantDevicesAndSettings"
        case "Noncompliant Devices And Settings V3":
            reportType = "NoncompliantDevicesAndSettingsV3"
        case "Non Compliant Devices By Compliance Policy":
            reportType = "NonCompliantDevicesByCompliancePolicy"
        case "Non Compliant Devices By Compliance Policy V3":
            reportType = "NonCompliantDevicesByCompliancePolicyV3"
        case "Noncompliant Devices To Be Retired":
            reportType = "NoncompliantDevicesToBeRetired"
        case "Org Apps Install Status":
            reportType = "OrgAppsInstallStatus"
        case "Org Device Install Status":
            reportType = "OrgDeviceInstallStatus"
        case "Per Setting Device Summary By Configuration Policy":
            reportType = "PerSettingDeviceSummaryByConfigurationPolicy"
        case "Per Setting Device Summary By Configuration Policy For App Control":
            reportType = "PerSettingDeviceSummaryByConfigurationPolicyForAppControl"
        case "Per Setting Device Summary By Configuration Policy For EDR":
            reportType = "PerSettingDeviceSummaryByConfigurationPolicyForEDR"
        case "Per Setting Device Summary By Inventory Policy":
            reportType = "PerSettingDeviceSummaryByInventoryPolicy"
        case "Per Setting Device Summary By Inventory Policy V3":
            reportType = "PerSettingDeviceSummaryByInventoryPolicyV3"
        case "Per Setting Summary By Device Configuration Policy":
            reportType = "PerSettingSummaryByDeviceConfigurationPolicy"
        case "Policies":
            reportType = "Policies"
        case "Policy Compliance Agg Report":
            reportType = "PolicyComplianceAggReport"
        case "Policy Compliance Agg Report V3":
            reportType = "PolicyComplianceAggReportV3"
        case "Policy Non Compliance Agg":
            reportType = "PolicyNonComplianceAgg"
        case "Policy Non Compliance Agg Ver3":
            reportType = "PolicyNonComplianceAggVer3"
        case "Policy Non Compliance New":
            reportType = "PolicyNonComplianceNew"
        case "Policy Non Compliance New V3":
            reportType = "PolicyNonComplianceNewV3"
        case "Policy Run States By Proactive Remediation":
            reportType = "PolicyRunStatesByProactiveRemediation"
        case "Quality Update Device Errors By Policy":
            reportType = "QualityUpdateDeviceErrorsByPolicy"
        case "Quality Update Device Status By Policy":
            reportType = "QualityUpdateDeviceStatusByPolicy"
        case "Quality Update Policy Status Summary":
            reportType = "QualityUpdatePolicyStatusSummary"
        case "Remote Assistance Sessions":
            reportType = "RemoteAssistanceSessions"
        case "Resource Performance Aggregate By Device":
            reportType = "ResourcePerformanceAggregateByDevice"
        case "Resource Performance Aggregate By Model":
            reportType = "ResourcePerformanceAggregateByModel"
        case "Setting Compliance Agg Report":
            reportType = "SettingComplianceAggReport"
        case "Setting Compliance Agg Report V3":
            reportType = "SettingComplianceAggReportV3"
        case "Ticketing Security Task Apps List":
            reportType = "TicketingSecurityTaskAppsList"
        case "Tpm Attestation Status":
            reportType = "TpmAttestationStatus"
        case "Unhealthy Defender Agents":
            reportType = "UnhealthyDefenderAgents"
        case "User Install Status Aggregate By App":
            reportType = "UserInstallStatusAggregateByApp"
        case "Users":
            reportType = "Users"
        case "User Scale Test":
            reportType = "UserScaleTest"
        case "Windows Device Health Attestation Report":
            reportType = "WindowsDeviceHealthAttestationReport"
        case "Windows Update Per Policy Per Device Status":
            reportType = "WindowsUpdatePerPolicyPerDeviceStatus"
        case "Work From Anywhere Device List":
            reportType = "WorkFromAnywhereDeviceList"
        default:
            return nil
        }
        
        guard let reportType = reportType else {
            return nil
        }
        
        return (reportName: reportName, reportType: reportType)
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
        
        // Determine if this report type supports filtering
        let hasFilters = reportSupportsFiltering(reportType)
        
        // Create main accessory view - size based on filter support
        let dialogHeight = hasFilters ? 120 : 50
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: dialogHeight))
        
        // Format label and popup - position based on dialog size
        let formatLabelY = hasFilters ? 90 : 20
        let formatPopupY = hasFilters ? 88 : 18
        
        let formatLabel = NSTextField(labelWithString: "Export Format:")
        formatLabel.frame = NSRect(x: 0, y: formatLabelY, width: 100, height: 20)
        formatLabel.font = NSFont.boldSystemFont(ofSize: 13)
        accessoryView.addSubview(formatLabel)
        
        let formatPopup = NSPopUpButton(frame: NSRect(x: 110, y: formatPopupY, width: 80, height: 25))
        formatPopup.addItem(withTitle: "CSV")
        formatPopup.addItem(withTitle: "JSON")
        formatPopup.selectItem(at: 0) // Default to CSV
        accessoryView.addSubview(formatPopup)
        
        // Add filters based on report type (only for reports that support filtering)
        var filterControls: [String: NSControl] = [:]
        
        if hasFilters {
            if reportType == "Devices" {
                // Add device-specific filters (includes management state)
                filterControls = createDeviceFiltersSimple(in: accessoryView)
            } else if reportType == "DevicesWithInventory" {
                // Add device with inventory-specific filters (includes management state)
                filterControls = createDevicesWithInventoryFiltersSimple(in: accessoryView)
            } else if reportType == "DeviceCompliance" {
                // Add compliance-specific filters (no management state)
                filterControls = createComplianceFiltersSimple(in: accessoryView)
            } else if reportType == "DeviceNonCompliance" {
                // Add non-compliance-specific filters (same as compliance)
                filterControls = createNonComplianceFiltersSimple(in: accessoryView)
            } else if reportType == "AppInvRawData" {
                // Add app inventory filters
                filterControls = createAppFiltersSimple(in: accessoryView)
            }
        }
        
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: "Export")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let format = formatPopup.titleOfSelectedItem?.lowercased() ?? "csv"
            
            // Extract filter values
            let filters = extractFilterValues(from: filterControls)
            
            // Show save panel
            showSavePanelForFullReport(reportName: reportName, reportType: reportType, format: format, filters: filters)
        }
    }
    
    /// Shows save panel for full report export
    /// - Parameters:
    ///   - reportName: The report name for display
    ///   - reportType: The report type for API calls
    ///   - format: Export format (csv or json)
    ///   - filters: Dictionary of filter values to apply
    private func showSavePanelForFullReport(reportName: String, reportType: String, format: String, filters: [String: String] = [:]) {
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
                self?.performFullReportExport(reportName: reportName, reportType: reportType, format: format, filters: filters, saveUrl: url)
            }
        }
    }
    
    /// Performs the full report export using Microsoft Graph export jobs API
    /// - Parameters:
    ///   - reportName: The report name for display
    ///   - reportType: The report type for API calls
    ///   - format: Export format (csv or json)
    ///   - filters: Dictionary of filter values to apply
    ///   - saveUrl: The file URL to save to
    private func performFullReportExport(reportName: String, reportType: String, format: String, filters: [String: String] = [:], saveUrl: URL) {
        // Reset cancellation state
        isExportCancelled = false
        exportStartTime = Date()
        
        // Show progress and disable controls
        setExportInProgress(true)
        updateStatusLabel("Creating export job...", color: .controlAccentColor)
        
        Logger.info("Starting full report export for \(reportType) in \(format) format", category: .core, toUserDirectory: true)
        
        // Create export job
        // Call approprate XPC Manager function based on the reportType variable
        switch reportType {
        case "AllAppsList":
            performAllAppsListExportJob(reportType: reportType, format: format, saveUrl: saveUrl)
        case "AppInstallStatusAggregate":
            performAppInstallStatusAggregateExportJob(reportType: reportType, format: format, saveUrl: saveUrl)
        case "AppInvAggregate":
            performAppInvAggregateExportJob(reportType: reportType, format: format, saveUrl: saveUrl)
        case "AppInvRawData":
            performAppInventoryRawDataExportJob(reportType: reportType, format: format, filters: filters, saveUrl: saveUrl)
        case "DeviceCompliance":
            performDeviceComplianceExportJob(reportType: reportType, format: format, filters: filters, saveUrl: saveUrl)
        case "DeviceNonCompliance":
            performDeviceNonComplianceExportJob(reportType: reportType, format: format, filters: filters, saveUrl: saveUrl)
        case "Devices":
            performDevicesExportJob(reportType: reportType, format: format, filters: filters, saveUrl: saveUrl)
        case "DevicesWithInventory":
            performDevicesWithInventoryExportJob(reportType: reportType, format: format, filters: filters, saveUrl: saveUrl)
        case "DefenderAgents":
            performDefenderAgentsExportJob(reportType: reportType, format: format, saveUrl: saveUrl)
        case "UnhealthyDefenderAgents":
            performDefenderAgentsExportJob(reportType: reportType, format: format, saveUrl: saveUrl)
        case "FirewallStatus":
            performFirewallStatusExportJob(reportType: reportType, format: format, saveUrl: saveUrl)
        case "Malware":
            performMalwareExportJob(reportType: reportType, format: format, saveUrl: saveUrl)
        case "ActiveMalware":
            performMalwareExportJob(reportType: reportType, format: format, saveUrl: saveUrl)
        case "MAMAppProtectionStatus":
            performMAMAppProtectionStatusExportJob(reportType: reportType, format: format, saveUrl: saveUrl)
        case "MAMAppConfigurationStatus":
            performMAMAppConfigurationStatusExportJob(reportType: reportType, format: format, saveUrl: saveUrl)
        case "FeatureUpdatePolicyFailuresAggregate":
            performFeatureUpdatePolicyFailuresAggregateExportJob(reportType: reportType, format: format, saveUrl: saveUrl)
        default:
            return
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
        resetUIState()
        updateStatusLabel("Export failed", color: .systemRed)
        
        Logger.error("Full report export error: \(message)", category: .core, toUserDirectory: true)
        showError(message)
    }
    
    // MARK: - Export Job Types
    private func performAllAppsListExportJob(reportType: String, format: String, saveUrl: URL) {
        // Create AllAppsList job
        XPCManager.shared.createAllAppsListExportJob(
            includeColumns: nil,
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

    private func performAppInstallStatusAggregateExportJob(reportType: String, format: String, saveUrl: URL) {
        // Create AppInstallStatusAggregate job
        XPCManager.shared.createAppInstallStatusAggregateExportJob(
            platform: nil,
            failedDevicePercentage: nil,
            includeColumns: nil,
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


    private func performAppInvAggregateExportJob(reportType: String, format: String, saveUrl: URL) {
        // Create AppInvAggregate job
        XPCManager.shared.createAppInvAggregateExportJob(
            includeColumns: nil,
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

    private func performAppInventoryRawDataExportJob(reportType: String, format: String, filters: [String: String] = [:], saveUrl: URL) {
        // Extract filter values
        let platform = filters["platform"] != "All" ? filters["platform"] : nil
        let applicationName = filters["applicationName"]
        let applicationPublisher = filters["applicationPublisher"]
        
        // Create AppInventoryRawData job with filters
        XPCManager.shared.createAppInvRawDataExportJob(
            applicationName: applicationName,
            applicationPublisher: applicationPublisher,
            applicationShortVersion: nil,
            applicationVersion: nil,
            deviceId: nil,
            deviceName: nil,
            osDescription: nil,
            osVersion: nil,
            platform: platform,
            userId: nil,
            emailAddress: nil,
            userName: nil,
            includeColumns: nil,
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

    private func performDeviceComplianceExportJob(reportType: String, format: String, filters: [String: String] = [:], saveUrl: URL) {
        // Extract filter values for compliance reports
        let ownerType = filters["ownerType"] != "All" ? filters["ownerType"] : nil
        let complianceState = filters["complianceState"] != "All" ? filters["complianceState"] : nil
        let deviceType = filters["deviceType"] != "All" ? filters["deviceType"] : nil
        
        // Create DeviceCompliance job with filters
        XPCManager.shared.createDeviceComplianceExportJob(
            complianceState: complianceState,
            os: nil, // Could add OS filter later
            ownerType: ownerType,
            deviceType: deviceType,
            includeColumns: nil,
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

    private func performDeviceNonComplianceExportJob(reportType: String, format: String, filters: [String: String] = [:], saveUrl: URL) {
        // Extract filter values for non-compliance reports
        let ownerType = filters["ownerType"] != "All" ? filters["ownerType"] : nil
        let complianceState = filters["complianceState"] != "All" ? filters["complianceState"] : nil
        let deviceType = filters["deviceType"] != "All" ? filters["deviceType"] : nil
        
        // Create DeviceNonCompliance job with filters
        XPCManager.shared.createDeviceNonComplianceExportJob(
            complianceState: complianceState,
            os: nil, // Could add OS filter later
            ownerType: ownerType,
            deviceType: deviceType,
            userId: nil,
            includeColumns: nil,
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

    private func performDevicesExportJob(reportType: String, format: String, filters: [String: String] = [:], saveUrl: URL) {
        // Extract filter values (convert "All" to nil for API)
        let ownerType = filters["ownerType"] != "All" ? filters["ownerType"] : nil
        let managementState = filters["managementState"] != "All" ? filters["managementState"] : nil
        let compliantState = filters["compliantState"] != "All" ? filters["compliantState"] : nil
        let deviceType = filters["deviceType"] != "All" ? filters["deviceType"] : nil
        
        // Create Devices job with filters
        XPCManager.shared.createDevicesExportJob(
            ownerType: ownerType,
            deviceType: deviceType,
            managementAgents: nil,
            categoryName: nil,
            managementState: managementState,
            compliantState: compliantState,
            jailBroken: nil,
            enrollmentType: nil,
            includeColumns: nil,
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

    private func performDevicesWithInventoryExportJob(reportType: String, format: String, filters: [String: String] = [:], saveUrl: URL) {
        // Extract filter values (convert "All" to nil for API)
        let ownerType = filters["ownerType"] != "All" ? filters["ownerType"] : nil
        let managementState = filters["managementState"] != "All" ? filters["managementState"] : nil
        let compliantState = filters["compliantState"] != "All" ? filters["compliantState"] : nil
        let deviceType = filters["deviceType"] != "All" ? filters["deviceType"] : nil
        
        // Create Devices job with filters
        XPCManager.shared.createDevicesWithInventoryExportJob(
            createdDate: nil,
            lastContact: nil,
            categoryName: nil,
            compliantState: compliantState,
            managementAgents: nil,
            ownerType: ownerType,
            managementState: managementState,
            deviceType: deviceType,
            jailBroken: nil,
            enrollmentType: nil,
            includeColumns: nil,
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

    private func performDefenderAgentsExportJob(reportType: String, format: String, saveUrl: URL) {
        // Create DefenderAgents job
        XPCManager.shared.createDefenderAgentsExportJob(
            deviceState: nil,
            signatureUpdateOverdue: nil,
            malwareProtectionEnabled: nil,
            realTimeProtectionEnabled: nil,
            networkInspectionSystemEnabled: nil,
            includeColumns: nil,
            format: format,
            reportType: reportType
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

    private func performFirewallStatusExportJob(reportType: String, format: String, saveUrl: URL) {
        // Create FirewallStatus job
        XPCManager.shared.createFirewallStatusExportJob(
            firewallStatus: nil,
            includeColumns: nil,
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

    private func performMalwareExportJob(reportType: String, format: String, saveUrl: URL) {
        // Create Malware job
        XPCManager.shared.createMalwareExportJob(
            severity: nil,
            executionState: nil,
            state: nil,
            includeColumns: nil,
            format: format,
            reportType: reportType
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

    private func performMAMAppProtectionStatusExportJob(reportType: String, format: String, saveUrl: URL) {
        // Create MAMAppProtectionStatus job
        XPCManager.shared.createMAMAppProtectionStatusExportJob(
            includeColumns: nil,
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

    private func performMAMAppConfigurationStatusExportJob(reportType: String, format: String, saveUrl: URL) {
        // Create MAMAppConfigurationStatus job
        XPCManager.shared.createMAMAppConfigurationStatusExportJob(
            includeColumns: nil,
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

    private func performFeatureUpdatePolicyFailuresAggregateExportJob(reportType: String, format: String, saveUrl: URL) {
        // Create FeatureUpdatePolicyFailuresAggregate job
        XPCManager.shared.createFeatureUpdatePolicyFailuresAggregateExportJob(
            includeColumns: nil,
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


    // MARK: - UI State Management
    
    /// Sets the export in progress state
    /// - Parameter inProgress: Whether export is in progress
    private func setExportInProgress(_ inProgress: Bool) {
        runReportButton.isEnabled = !inProgress
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
            currentProgress += 5
            if currentProgress > 90 {
                currentProgress = 90
            }
            
            // Vary the message based on time elapsed
            let elapsed = Date().timeIntervalSince(self.exportStartTime ?? Date())
            let message: String
            if elapsed < 4 {
                message = "Processing export job…"
            } else if elapsed < 12 {
                message = "Creating export job…"
            } else if elapsed < 25 {
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
    
    // MARK: - Filter Support Detection
    
    /// Determines if a report type supports filtering
    /// - Parameter reportType: The report type to check
    /// - Returns: True if the report type supports filtering
    private func reportSupportsFiltering(_ reportType: String) -> Bool {
        switch reportType {
        case "Devices", "DevicesWithInventory", "DeviceCompliance", "DeviceNonCompliance", "AppInvRawData":
            return true
        default:
            return false
        }
    }
    
    // MARK: - Simple Filter Options
    
    /// Creates simplified device filter controls
    /// - Parameter container: The view to add controls to
    /// - Returns: Dictionary of filter controls for value extraction
    private func createDeviceFiltersSimple(in container: NSView) -> [String: NSControl] {
        var controls: [String: NSControl] = [:]
        
        // Add "Filters:" label
        let filtersLabel = NSTextField(labelWithString: "Filters:")
        filtersLabel.frame = NSRect(x: 0, y: 60, width: 60, height: 17)
        filtersLabel.font = NSFont.boldSystemFont(ofSize: 13)
        container.addSubview(filtersLabel)
        
        // Owner Type filter
        let ownerLabel = NSTextField(labelWithString: "Owner Type:")
        ownerLabel.frame = NSRect(x: 0, y: 35, width: 80, height: 17)
        container.addSubview(ownerLabel)
        
        let ownerPopup = NSPopUpButton(frame: NSRect(x: 90, y: 31, width: 120, height: 25))
        ownerPopup.addItem(withTitle: "All")
        ownerPopup.addItem(withTitle: "Company")
        ownerPopup.addItem(withTitle: "Personal")
        container.addSubview(ownerPopup)
        controls["ownerType"] = ownerPopup
        
        // Compliance State filter
        let complianceLabel = NSTextField(labelWithString: "Compliance:")
        complianceLabel.frame = NSRect(x: 220, y: 35, width: 80, height: 17)
        container.addSubview(complianceLabel)
        
        let compliancePopup = NSPopUpButton(frame: NSRect(x: 310, y: 31, width: 120, height: 25))
        compliancePopup.addItem(withTitle: "All")
        compliancePopup.addItem(withTitle: "Compliant")
        compliancePopup.addItem(withTitle: "Noncompliant")
        compliancePopup.addItem(withTitle: "InGracePeriod")
        container.addSubview(compliancePopup)
        controls["compliantState"] = compliancePopup
        
        // Management State filter
        let managementLabel = NSTextField(labelWithString: "Management:")
        managementLabel.frame = NSRect(x: 0, y: 8, width: 80, height: 17)
        container.addSubview(managementLabel)
        
        let managementPopup = NSPopUpButton(frame: NSRect(x: 90, y: 3, width: 120, height: 25))
        managementPopup.addItem(withTitle: "All")
        managementPopup.addItem(withTitle: "Managed")
        managementPopup.addItem(withTitle: "Discovered")
        managementPopup.addItem(withTitle: "Unhealthy")
        managementPopup.addItem(withTitle: "Retire Pending")
        managementPopup.addItem(withTitle: "Wipe Pending")
        container.addSubview(managementPopup)
        controls["managementState"] = managementPopup
        
        // Device Type filter
        let deviceTypeLabel = NSTextField(labelWithString: "Device Type:")
        deviceTypeLabel.frame = NSRect(x: 220, y: 8, width: 80, height: 17)
        container.addSubview(deviceTypeLabel)
        
        let deviceTypePopup = NSPopUpButton(frame: NSRect(x: 310, y: 3, width: 120, height: 25))
        deviceTypePopup.addItem(withTitle: "All")
        deviceTypePopup.addItem(withTitle: "Desktop")
        deviceTypePopup.addItem(withTitle: "Windows")
        deviceTypePopup.addItem(withTitle: "Mac")
        deviceTypePopup.addItem(withTitle: "MacMDM")
        deviceTypePopup.addItem(withTitle: "iPhone")
        deviceTypePopup.addItem(withTitle: "iPad")
        deviceTypePopup.addItem(withTitle: "iPod")
        deviceTypePopup.addItem(withTitle: "Android")
        deviceTypePopup.addItem(withTitle: "AndroidForWork")
        deviceTypePopup.addItem(withTitle: "AndroidEnterprise")
        deviceTypePopup.addItem(withTitle: "Windows10x")
        deviceTypePopup.addItem(withTitle: "AndroidnGMS")
        deviceTypePopup.addItem(withTitle: "CloudPC")
        deviceTypePopup.addItem(withTitle: "Linux")
        deviceTypePopup.addItem(withTitle: "WinMO6")
        deviceTypePopup.addItem(withTitle: "Nokia")
        deviceTypePopup.addItem(withTitle: "WindowsPhone")
        deviceTypePopup.addItem(withTitle: "WinCE")
        deviceTypePopup.addItem(withTitle: "WinEmbedded")
        deviceTypePopup.addItem(withTitle: "iSocConsumer")
        deviceTypePopup.addItem(withTitle: "Unix")
        deviceTypePopup.addItem(withTitle: "HoloLens")
        deviceTypePopup.addItem(withTitle: "SurfaceHub")
        container.addSubview(deviceTypePopup)
        controls["deviceType"] = deviceTypePopup
        
        return controls
    }

    /// Creates simplified device with inventory filter controls
    /// - Parameter container: The view to add controls to
    /// - Returns: Dictionary of filter controls for value extraction
    private func createDevicesWithInventoryFiltersSimple(in container: NSView) -> [String: NSControl] {
        var controls: [String: NSControl] = [:]
        
        // Add "Filters:" label
        let filtersLabel = NSTextField(labelWithString: "Filters:")
        filtersLabel.frame = NSRect(x: 0, y: 60, width: 60, height: 17)
        filtersLabel.font = NSFont.boldSystemFont(ofSize: 13)
        container.addSubview(filtersLabel)
        
        // Owner Type filter
        let ownerLabel = NSTextField(labelWithString: "Owner Type:")
        ownerLabel.frame = NSRect(x: 0, y: 35, width: 80, height: 17)
        container.addSubview(ownerLabel)
        
        let ownerPopup = NSPopUpButton(frame: NSRect(x: 90, y: 31, width: 120, height: 25))
        ownerPopup.addItem(withTitle: "All")
        ownerPopup.addItem(withTitle: "Company")
        ownerPopup.addItem(withTitle: "Personal")
        container.addSubview(ownerPopup)
        controls["ownerType"] = ownerPopup
        
        // Compliance State filter
        let complianceLabel = NSTextField(labelWithString: "Compliance:")
        complianceLabel.frame = NSRect(x: 220, y: 35, width: 80, height: 17)
        container.addSubview(complianceLabel)
        
        let compliancePopup = NSPopUpButton(frame: NSRect(x: 310, y: 31, width: 120, height: 25))
        compliancePopup.addItem(withTitle: "All")
        compliancePopup.addItem(withTitle: "Compliant")
        compliancePopup.addItem(withTitle: "Noncompliant")
        compliancePopup.addItem(withTitle: "InGracePeriod")
        container.addSubview(compliancePopup)
        controls["compliantState"] = compliancePopup
        
        // Management State filter
        let managementLabel = NSTextField(labelWithString: "Management:")
        managementLabel.frame = NSRect(x: 0, y: 8, width: 80, height: 17)
        container.addSubview(managementLabel)
        
        let managementPopup = NSPopUpButton(frame: NSRect(x: 90, y: 3, width: 120, height: 25))
        managementPopup.addItem(withTitle: "All")
        managementPopup.addItem(withTitle: "Managed")
        managementPopup.addItem(withTitle: "Discovered")
        managementPopup.addItem(withTitle: "Unhealthy")
        managementPopup.addItem(withTitle: "Retire Pending")
        managementPopup.addItem(withTitle: "Wipe Pending")
        container.addSubview(managementPopup)
        controls["managementState"] = managementPopup
        
        // Device Type filter
        let deviceTypeLabel = NSTextField(labelWithString: "Device Type:")
        deviceTypeLabel.frame = NSRect(x: 220, y: 8, width: 80, height: 17)
        container.addSubview(deviceTypeLabel)
        
        let deviceTypePopup = NSPopUpButton(frame: NSRect(x: 310, y: 3, width: 120, height: 25))
        deviceTypePopup.addItem(withTitle: "All")
        deviceTypePopup.addItem(withTitle: "Desktop")
        deviceTypePopup.addItem(withTitle: "Windows")
        deviceTypePopup.addItem(withTitle: "Mac")
        deviceTypePopup.addItem(withTitle: "MacMDM")
        deviceTypePopup.addItem(withTitle: "iPhone")
        deviceTypePopup.addItem(withTitle: "iPad")
        deviceTypePopup.addItem(withTitle: "iPod")
        deviceTypePopup.addItem(withTitle: "Android")
        deviceTypePopup.addItem(withTitle: "AndroidForWork")
        deviceTypePopup.addItem(withTitle: "AndroidEnterprise")
        deviceTypePopup.addItem(withTitle: "Windows10x")
        deviceTypePopup.addItem(withTitle: "AndroidnGMS")
        deviceTypePopup.addItem(withTitle: "CloudPC")
        deviceTypePopup.addItem(withTitle: "Linux")
        deviceTypePopup.addItem(withTitle: "WinMO6")
        deviceTypePopup.addItem(withTitle: "Nokia")
        deviceTypePopup.addItem(withTitle: "WindowsPhone")
        deviceTypePopup.addItem(withTitle: "WinCE")
        deviceTypePopup.addItem(withTitle: "WinEmbedded")
        deviceTypePopup.addItem(withTitle: "iSocConsumer")
        deviceTypePopup.addItem(withTitle: "Unix")
        deviceTypePopup.addItem(withTitle: "HoloLens")
        deviceTypePopup.addItem(withTitle: "SurfaceHub")
        container.addSubview(deviceTypePopup)
        controls["deviceType"] = deviceTypePopup

        return controls
    }

    /// Creates simplified app inventory filter controls
    /// - Parameter container: The view to add controls to
    /// - Returns: Dictionary of filter controls for value extraction
    private func createAppFiltersSimple(in container: NSView) -> [String: NSControl] {
        var controls: [String: NSControl] = [:]
        
        // Add "Filters:" label
        let filtersLabel = NSTextField(labelWithString: "Filters:")
        filtersLabel.frame = NSRect(x: 0, y: 60, width: 60, height: 17)
        filtersLabel.font = NSFont.boldSystemFont(ofSize: 13)
        container.addSubview(filtersLabel)
        
        // Platform filter
        let platformLabel = NSTextField(labelWithString: "Platform:")
        platformLabel.frame = NSRect(x: 0, y: 35, width: 70, height: 17)
        container.addSubview(platformLabel)
        
        let platformPopup = NSPopUpButton(frame: NSRect(x: 80, y: 33, width: 150, height: 25))
        platformPopup.addItem(withTitle: "All")
        platformPopup.addItem(withTitle: "Windows")
        platformPopup.addItem(withTitle: "MacOS")
        platformPopup.addItem(withTitle: "IOS")
        platformPopup.addItem(withTitle: "AndroidWorkProfile")
        platformPopup.addItem(withTitle: "AndroidFullyManagedDedicated")
        platformPopup.addItem(withTitle: "AndroidDeviceAdministrator")
        platformPopup.addItem(withTitle: "Other")
        container.addSubview(platformPopup)
        controls["platform"] = platformPopup
        
        // Application Name filter (text field)
        let appNameLabel = NSTextField(labelWithString: "App Name:")
        appNameLabel.frame = NSRect(x: 240, y: 35, width: 70, height: 17)
        container.addSubview(appNameLabel)
        
        let appNameField = NSTextField(frame: NSRect(x: 320, y: 33, width: 130, height: 25))
        appNameField.placeholderString = "e.g., Safari"
        container.addSubview(appNameField)
        controls["applicationName"] = appNameField
        
        // Publisher filter (text field)
        let publisherLabel = NSTextField(labelWithString: "Publisher:")
        publisherLabel.frame = NSRect(x: 0, y: 8, width: 70, height: 17)
        container.addSubview(publisherLabel)
        
        let publisherField = NSTextField(frame: NSRect(x: 80, y: 6, width: 130, height: 25))
        publisherField.placeholderString = "e.g., Microsoft"
        container.addSubview(publisherField)
        controls["applicationPublisher"] = publisherField
        
        return controls
    }
    
    /// Creates simplified compliance filter controls (no management state)
    /// - Parameter container: The view to add controls to
    /// - Returns: Dictionary of filter controls for value extraction
    private func createComplianceFiltersSimple(in container: NSView) -> [String: NSControl] {
        var controls: [String: NSControl] = [:]
        
        // Add "Filters:" label
        let filtersLabel = NSTextField(labelWithString: "Filters:")
        filtersLabel.frame = NSRect(x: 0, y: 60, width: 60, height: 17)
        filtersLabel.font = NSFont.boldSystemFont(ofSize: 13)
        container.addSubview(filtersLabel)
        
        // Owner Type filter
        let ownerLabel = NSTextField(labelWithString: "Owner Type:")
        ownerLabel.frame = NSRect(x: 0, y: 35, width: 80, height: 17)
        container.addSubview(ownerLabel)
        
        let ownerPopup = NSPopUpButton(frame: NSRect(x: 90, y: 31, width: 120, height: 25))
        ownerPopup.addItem(withTitle: "All")
        ownerPopup.addItem(withTitle: "Company")
        ownerPopup.addItem(withTitle: "Personal")
        container.addSubview(ownerPopup)
        controls["ownerType"] = ownerPopup
        
        // Compliance State filter
        let complianceLabel = NSTextField(labelWithString: "Compliance:")
        complianceLabel.frame = NSRect(x: 220, y: 35, width: 80, height: 17)
        container.addSubview(complianceLabel)
        
        let compliancePopup = NSPopUpButton(frame: NSRect(x: 310, y: 31, width: 120, height: 25))
        compliancePopup.addItem(withTitle: "All")
        compliancePopup.addItem(withTitle: "Compliant")
        compliancePopup.addItem(withTitle: "Noncompliant")
        compliancePopup.addItem(withTitle: "InGracePeriod")
        container.addSubview(compliancePopup)
        controls["complianceState"] = compliancePopup
        
        // Device Type filter
        let deviceTypeLabel = NSTextField(labelWithString: "Device Type:")
        deviceTypeLabel.frame = NSRect(x: 0, y: 8, width: 80, height: 17)
        container.addSubview(deviceTypeLabel)
        
        let deviceTypePopup = NSPopUpButton(frame: NSRect(x: 90, y: 3, width: 120, height: 25))
        deviceTypePopup.addItem(withTitle: "All")
        deviceTypePopup.addItem(withTitle: "Desktop")
        deviceTypePopup.addItem(withTitle: "Windows")
        deviceTypePopup.addItem(withTitle: "Mac")
        deviceTypePopup.addItem(withTitle: "MacMDM")
        deviceTypePopup.addItem(withTitle: "iPhone")
        deviceTypePopup.addItem(withTitle: "iPad")
        deviceTypePopup.addItem(withTitle: "Android")
        deviceTypePopup.addItem(withTitle: "AndroidForWork")
        deviceTypePopup.addItem(withTitle: "AndroidEnterprise")
        deviceTypePopup.addItem(withTitle: "CloudPC")
        deviceTypePopup.addItem(withTitle: "Linux")
        container.addSubview(deviceTypePopup)
        controls["deviceType"] = deviceTypePopup

        return controls
    }
    
    /// Creates simplified non-compliance filter controls (same as compliance)
    /// - Parameter container: The view to add controls to
    /// - Returns: Dictionary of filter controls for value extraction
    private func createNonComplianceFiltersSimple(in container: NSView) -> [String: NSControl] {
        var controls: [String: NSControl] = [:]
        
        // Add "Filters:" label
        let filtersLabel = NSTextField(labelWithString: "Filters:")
        filtersLabel.frame = NSRect(x: 0, y: 60, width: 60, height: 17)
        filtersLabel.font = NSFont.boldSystemFont(ofSize: 13)
        container.addSubview(filtersLabel)
        
        // Owner Type filter
        let ownerLabel = NSTextField(labelWithString: "Owner Type:")
        ownerLabel.frame = NSRect(x: 0, y: 35, width: 80, height: 17)
        container.addSubview(ownerLabel)
        
        let ownerPopup = NSPopUpButton(frame: NSRect(x: 90, y: 31, width: 100, height: 25))
        ownerPopup.addItem(withTitle: "All")
        ownerPopup.addItem(withTitle: "Company")
        ownerPopup.addItem(withTitle: "Personal")
        container.addSubview(ownerPopup)
        controls["ownerType"] = ownerPopup
        
        // Compliance State filter
        let complianceLabel = NSTextField(labelWithString: "Compliance:")
        complianceLabel.frame = NSRect(x: 200, y: 35, width: 80, height: 17)
        container.addSubview(complianceLabel)
        
        let compliancePopup = NSPopUpButton(frame: NSRect(x: 290, y: 31, width: 120, height: 25))
        compliancePopup.addItem(withTitle: "All")
        compliancePopup.addItem(withTitle: "Compliant")
        compliancePopup.addItem(withTitle: "Noncompliant")
        compliancePopup.addItem(withTitle: "InGracePeriod")
        container.addSubview(compliancePopup)
        controls["complianceState"] = compliancePopup
        
        // Device Type filter
        let deviceTypeLabel = NSTextField(labelWithString: "Device Type:")
        deviceTypeLabel.frame = NSRect(x: 0, y: 8, width: 80, height: 17)
        container.addSubview(deviceTypeLabel)
        
        let deviceTypePopup = NSPopUpButton(frame: NSRect(x: 90, y: 6, width: 120, height: 25))
        deviceTypePopup.addItem(withTitle: "All")
        deviceTypePopup.addItem(withTitle: "Desktop")
        deviceTypePopup.addItem(withTitle: "Windows")
        deviceTypePopup.addItem(withTitle: "Mac")
        deviceTypePopup.addItem(withTitle: "MacMDM")
        deviceTypePopup.addItem(withTitle: "iPhone")
        deviceTypePopup.addItem(withTitle: "iPad")
        deviceTypePopup.addItem(withTitle: "Android")
        deviceTypePopup.addItem(withTitle: "AndroidForWork")
        deviceTypePopup.addItem(withTitle: "AndroidEnterprise")
        deviceTypePopup.addItem(withTitle: "CloudPC")
        deviceTypePopup.addItem(withTitle: "Linux")
        container.addSubview(deviceTypePopup)
        controls["deviceType"] = deviceTypePopup
        
        return controls
    }
    
    /// Extracts filter values from UI controls
    /// - Parameter controls: Dictionary of filter controls
    /// - Returns: Dictionary of filter values
    private func extractFilterValues(from controls: [String: NSControl]) -> [String: String] {
        var filters: [String: String] = [:]
        
        for (key, control) in controls {
            if let popup = control as? NSPopUpButton {
                let selectedTitle = popup.titleOfSelectedItem ?? "All"
                
                // Handle compliance state for Devices report (uses string values)
                if key == "compliantState" && selectedTitle != "All" {
                    filters[key] = selectedTitle
                }
                // Handle compliance state for device compliance/non-compliance reports (uses numeric values)
                else if key == "complianceState" && selectedTitle != "All" {
                    switch selectedTitle {
                    case "Compliant":
                        filters[key] = "1"
                    case "Noncompliant":
                        filters[key] = "2"
                    case "InGracePeriod":
                        filters[key] = "0"
                    default:
                        break // Don't add filter for "All" or unknown values
                    }
                }
                // Handle management state mapping to numeric values
                else if key == "managementState" && selectedTitle != "All" {
                    switch selectedTitle {
                    case "Managed":
                        filters[key] = "0"
                    case "Retire Pending":
                        filters[key] = "1"
                    case "Wipe Pending":
                        filters[key] = "3"
                    case "Unhealthy":
                        filters[key] = "5"
                    case "Discovered":
                        filters[key] = "11"
                    default:
                        break // Don't add filter for "All" or unknown values
                    }
                }
                // Handle device type mapping to numeric values
                else if key == "deviceType" && selectedTitle != "All" {
                    switch selectedTitle {
                    case "Desktop":
                        filters[key] = "0"
                    case "Windows":
                        filters[key] = "1"
                    case "WinMO6":
                        filters[key] = "2"
                    case "Nokia":
                        filters[key] = "3"
                    case "WindowsPhone":
                        filters[key] = "4"
                    case "Mac":
                        filters[key] = "5"
                    case "WinCE":
                        filters[key] = "6"
                    case "WinEmbedded":
                        filters[key] = "7"
                    case "iPhone":
                        filters[key] = "8"
                    case "iPad":
                        filters[key] = "9"
                    case "iPod":
                        filters[key] = "10"
                    case "Android":
                        filters[key] = "11"
                    case "iSocConsumer":
                        filters[key] = "12"
                    case "Unix":
                        filters[key] = "13"
                    case "MacMDM":
                        filters[key] = "14"
                    case "HoloLens":
                        filters[key] = "15"
                    case "SurfaceHub":
                        filters[key] = "16"
                    case "AndroidForWork":
                        filters[key] = "17"
                    case "AndroidEnterprise":
                        filters[key] = "18"
                    case "Windows10x":
                        filters[key] = "19"
                    case "AndroidnGMS":
                        filters[key] = "20"
                    case "CloudPC":
                        filters[key] = "21"
                    case "Linux":
                        filters[key] = "22"
                    default:
                        break // Don't add filter for "All" or unknown values
                    }
                }
                // Handle owner type mapping to numeric values
                else if key == "ownerType" && selectedTitle != "All" {
                    switch selectedTitle {
                    case "Company":
                        filters[key] = "1"
                    case "Personal":
                        filters[key] = "2"
                    default:
                        break // Don't add filter for "All" or unknown values
                    }
                }
                // Handle platform filter (uses string values for AppInvRawData)
                else if key == "platform" && selectedTitle != "All" {
                    // For AppInvRawData report, platform uses specific string values
                    switch selectedTitle {
                    case "Windows":
                        filters[key] = "Windows"
                    case "MacOS":
                        filters[key] = "MacOS"
                    case "IOS":
                        filters[key] = "IOS"
                    case "AndroidWorkProfile":
                        filters[key] = "AndroidWorkProfile"
                    case "AndroidFullyManagedDedicated":
                        filters[key] = "AndroidFullyManagedDedicated"
                    case "AndroidDeviceAdministrator":
                        filters[key] = "AndroidDeviceAdministrator"
                    case "Other":
                        filters[key] = "Other"
                    default:
                        filters[key] = selectedTitle
                    }
                } else if selectedTitle != "All" {
                    filters[key] = selectedTitle
                }
            } else if let textField = control as? NSTextField {
                let value = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    filters[key] = value
                }
            }
        }
        
        return filters
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

}


struct MenuItemData {
    let title: String
    let tooltip: String
}
