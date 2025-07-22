//
//  ConfigReportingManagerViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/14/25.
//

import Cocoa

class ConfigReportingManagerViewController: NSViewController {
    // MARK: - Properties
    var intuneConfigProfiles: [[String: Any]] = []
    var filteredIntuneConfigProfiles: [[String: Any]] = []
    private var isLoading: Bool = false
    private var currentSearchText: String = ""
    private var showOnlyAssigned: Bool = false
    private var selectedProfileType: String = "All" // "All", "deviceConfiguration", "deviceCompliance", etc.
    private var selectedPlatform: String = "All" // "All", "Windows", "macOS", "iOS", "Android"
    
    // MARK: - UI Elements
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var showAssignedCheckbox: NSButton!
    @IBOutlet weak var profileTypePopUpButton: NSPopUpButton!
    @IBOutlet weak var platformPopUpButton: NSPopUpButton!
    @IBOutlet weak var profileCountLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var reportButton: NSButton!
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Configuration Profiles Status"
        setupUI()
        loadIntuneConfigProfiles()
        
        // Safety check for tableView
        if let tableView = tableView {
            tableView.reloadData()
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()

        if let window = view.window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowWillClose(_:)),
                name: NSWindow.willCloseNotification,
                object: window
            )
        }
    }
    
    @objc func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            saveWindowFrame(window, forElement: "ConfigReportingManagerViewController")
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Verify IBOutlets are connected
        guard let tableView = tableView,
              let searchField = searchField,
              let showAssignedCheckbox = showAssignedCheckbox,
              let profileTypePopUpButton = profileTypePopUpButton,
              let platformPopUpButton = platformPopUpButton,
              let profileCountLabel = profileCountLabel,
              let reportButton = reportButton,
              let activityIndicator = activityIndicator else {
            fatalError("IBOutlets are not properly connected in Interface Builder")
        }
        
        // Configure table view
        tableView.target = self
        tableView.doubleAction = #selector(showConfigReportButtonClicked(_:))
        
        // Setup column sorting
        setupColumnSorting()
        
        // Configure search field
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.placeholderString = "Search configuration profiles..."
        
        // Configure show assigned checkbox
        showAssignedCheckbox.title = "Show only assigned profiles"
        
        // Restore saved checkbox state from UserDefaults
        restoreShowAssignedSelection()
        
        // Setup profile type popup button
        setupProfileTypePopUpButton()
        
        // Setup platform popup button
        setupPlatformPopUpButton()
        
        // Update count label
        updateProfileCountLabel()
        
        // Apply window frame
//        if let window = view.window {
//            restoreWindowFrame(window, forElement: "ConfigReportingManagerViewController")
//        }
    }
    
    private func setupColumnSorting() {
        guard let tableView = tableView else { return }
        
        for column in tableView.tableColumns {
            let sortDescriptor = NSSortDescriptor(key: column.identifier.rawValue, ascending: true)
            column.sortDescriptorPrototype = sortDescriptor
        }
        
        tableView.target = self
        tableView.action = #selector(tableViewClicked(_:))
    }
    
    private func setupProfileTypePopUpButton() {
        guard let profileTypePopUpButton = profileTypePopUpButton else { return }
        
        profileTypePopUpButton.removeAllItems()
        profileTypePopUpButton.addItems(withTitles: [
            "All",
//            "Device Configuration",
//            "Device Compliance",
//            "Device Enrollment",
//            "Endpoint Protection",
//            "Custom Configuration",
            "Settings Catalog",
            "Templates",
////            "Settings Catalog (Template)",
//            "Windows Feature Update",
//            "Windows Quality Update",
//            "Windows Driver Update"
            "Windows Update Rings"
        ])
        
        // Restore saved selection
        restoreProfileTypeSelection()
        
        profileTypePopUpButton.target = self
        profileTypePopUpButton.action = #selector(profileTypePopUpChanged(_:))
    }
    
    private func setupPlatformPopUpButton() {
        guard let platformPopUpButton = platformPopUpButton else { return }
        
        platformPopUpButton.removeAllItems()
        platformPopUpButton.addItems(withTitles: [
            "All",
            "Android",
            "iOS",
            "macOS", 
            "Windows"
        ])
        
        // Restore saved selection
        restorePlatformSelection()
        
        platformPopUpButton.target = self
        platformPopUpButton.action = #selector(platformPopUpChanged(_:))
    }
    
    // MARK: - Data Loading
    private func loadIntuneConfigProfiles() {
        guard !isLoading else { return }
        
        isLoading = true
        startActivityIndicator()
        
        Logger.log("Starting to load Intune configuration profiles...", category: .core, toUserDirectory: true)
        
        XPCManager.shared.fetchIntuneConfigurationProfiles { [weak self] configProfiles in
            DispatchQueue.main.async {
                self?.handleConfigProfilesResponse(configProfiles)
            }
        }
    }
    
    private func handleConfigProfilesResponse(_ configProfiles: [[String: Any]]?) {
        stopActivityIndicator()
        isLoading = false
        
        if let configProfiles = configProfiles {
            self.intuneConfigProfiles = configProfiles
            Logger.log("Successfully loaded \(configProfiles.count) configuration profiles", category: .core, toUserDirectory: true)
            applyFilters()
        } else {
            Logger.error("Failed to load configuration profiles", category: .core, toUserDirectory: true)
            showAlert(title: "Error", message: "Failed to load configuration profiles. Please check your connection and try again.")
        }
    }
    
    // MARK: - Filtering and Search
    private func applyFilters() {
        var filtered = intuneConfigProfiles
        
        // Apply search filter
        if !currentSearchText.isEmpty {
            filtered = filtered.filter { profile in
                let displayName = profile["displayName"] as? String ?? ""
                let description = profile["description"] as? String ?? ""
                let profileType = profile["@odata.type"] as? String ?? ""
                
                return displayName.localizedCaseInsensitiveContains(currentSearchText) ||
                       description.localizedCaseInsensitiveContains(currentSearchText) ||
                       profileType.localizedCaseInsensitiveContains(currentSearchText)
            }
        }
        
        // Apply assignment filter
        if showOnlyAssigned {
            filtered = filtered.filter { profile in
                return (profile["isAssigned"] as? Bool) == true
            }
        }
        
        // Apply profile type filter
        if selectedProfileType != "All" {
            filtered = filtered.filter { profile in
                let profileType = extractFriendlyProfileTypeFromProfile(profile)
                
                switch selectedProfileType {
                case "Device Configuration":
                    return profileType == "Device Configuration"
                case "Device Compliance":
                    return profileType == "Device Compliance"
                case "Device Enrollment":
                    return profileType == "Device Enrollment"
                case "Endpoint Protection":
                    return profileType == "Endpoint Protection"
                case "Settings Catalog":
                    return profileType == "Settings Catalog" || 
                           profileType == "Settings Catalog (Template)"
                case "Settings Catalog (Template)":
                    return profileType == "Settings Catalog (Template)"
                case "Templates":
                    return profileType.hasPrefix("Templates:")
                case "Windows Feature Update":
                    return profileType == "Windows Feature Update"
                case "Windows Quality Update":
                    return profileType == "Windows Quality Update"
                case "Windows Driver Update":
                    return profileType == "Windows Driver Update"
                case "Windows Update Rings":
                    return profileType == "Windows Update Rings"
                default:
                    return true
                }
            }
        }
        
        // Apply platform filter
        if selectedPlatform != "All" {
            filtered = filtered.filter { profile in
                let platform = extractPlatformFromProfile(profile)
                return platform == selectedPlatform
            }
        }
        
        filteredIntuneConfigProfiles = filtered
        updateProfileCountLabel()
        tableView?.reloadData()
    }
    
    private func updateProfileCountLabel() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let profileCountLabel = self.profileCountLabel else { return }
            
            let totalCount = self.intuneConfigProfiles.count
            let filteredCount = self.filteredIntuneConfigProfiles.count
            
            if totalCount == filteredCount {
                profileCountLabel.stringValue = "\(totalCount) configuration profiles"
            } else {
                profileCountLabel.stringValue = "\(filteredCount) of \(totalCount) configuration profiles"
            }
        }
    }
    
    // MARK: - Actions
    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        currentSearchText = sender.stringValue
        applyFilters()
    }
    
    @IBAction func showAssignedCheckboxChanged(_ sender: NSButton) {
        showOnlyAssigned = sender.state == .on
        saveShowAssignedSelection()
        applyFilters()
    }
    
    @objc private func profileTypePopUpChanged(_ sender: NSPopUpButton) {
        selectedProfileType = sender.titleOfSelectedItem ?? "All"
        saveProfileTypeSelection()
        applyFilters()
    }
    
    @objc private func platformPopUpChanged(_ sender: NSPopUpButton) {
        selectedPlatform = sender.titleOfSelectedItem ?? "All"
        savePlatformSelection()
        applyFilters()
    }
    
    @IBAction func refreshButtonClicked(_ sender: NSButton) {
        loadIntuneConfigProfiles()
    }
    
    @IBAction func showConfigReportButtonClicked(_ sender: NSButton) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < filteredIntuneConfigProfiles.count else {
            showError(message: "Please select a config profile.")
            return
        }

        // Check if the Option key is currently down
        let optionKeyDown = NSEvent.modifierFlags.contains(.option)
        if optionKeyDown {
            // Perform alternate action
            showProfileDetails(forSelectedRow: selectedRow)
        } else {
            showConfigReport(forSelectedRow: selectedRow)
        }
    }

    private func showConfigReport(forSelectedRow selectedRow: Int) {
        let intuneConfig = filteredIntuneConfigProfiles[selectedRow]
        
        let storyboard = NSStoryboard(name: "ConfigReporting", bundle: nil)
        let reportVC = storyboard.instantiateController(withIdentifier: "ConfigReportingViewController") as! ConfigReportingViewController
        
        reportVC.configure(with: intuneConfig)
        presentAsSheet(reportVC)
        
    }

    private func showProfileDetails(forSelectedRow selectedRow: Int) {
        let selectedProfile = filteredIntuneConfigProfiles[selectedRow]
        
        // TODO: Implement profile details view
        // For now, show basic info in an alert
        let profileName = selectedProfile["displayName"] as? String ?? "Unknown"
        let profileType = selectedProfile["@odata.type"] as? String ?? "Unknown"
        let isAssigned = (selectedProfile["isAssigned"] as? Bool) == true ? "Yes" : "No"
        
        showAlert(title: "Profile Details", 
                 message: "Name: \(profileName)\nType: \(profileType)\nAssigned: \(isAssigned)")
    }
    
    @objc private func tableViewClicked(_ sender: NSTableView) {
        // Handle table view selection if needed
    }
    
    // MARK: - UserDefaults Persistence
    private func saveShowAssignedSelection() {
        UserDefaults.standard.set(showOnlyAssigned, forKey: "ConfigReportingManager.showOnlyAssigned")
    }
    
    private func restoreShowAssignedSelection() {
        showOnlyAssigned = UserDefaults.standard.bool(forKey: "ConfigReportingManager.showOnlyAssigned")
        showAssignedCheckbox?.state = showOnlyAssigned ? .on : .off
    }
    
    private func saveProfileTypeSelection() {
        UserDefaults.standard.set(selectedProfileType, forKey: "ConfigReportingManager.selectedProfileType")
    }
    
    private func restoreProfileTypeSelection() {
        selectedProfileType = UserDefaults.standard.string(forKey: "ConfigReportingManager.selectedProfileType") ?? "All"
        profileTypePopUpButton?.selectItem(withTitle: selectedProfileType)
    }
    
    private func savePlatformSelection() {
        UserDefaults.standard.set(selectedPlatform, forKey: "ConfigReportingManager.selectedPlatform")
    }
    
    private func restorePlatformSelection() {
        selectedPlatform = UserDefaults.standard.string(forKey: "ConfigReportingManager.selectedPlatform") ?? "All"
        platformPopUpButton?.selectItem(withTitle: selectedPlatform)
    }
    
    // MARK: - Helper Methods
    private func startActivityIndicator() {
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator?.startAnimation(nil)
            self?.refreshButton?.isEnabled = false
        }
    }
    
    private func stopActivityIndicator() {
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator?.stopAnimation(nil)
            self?.refreshButton?.isEnabled = true
        }
    }
    
    // MARK: - User Feedback
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .informational
            
            if let window = self?.view.window {
                alert.beginSheetModal(for: window)
            } else {
                alert.runModal()
            }
        }
    }
        
    func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
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

}

// MARK: - NSTableViewDataSource
extension ConfigReportingManagerViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredIntuneConfigProfiles.count
    }
}

// MARK: - NSTableViewDelegate  
extension ConfigReportingManagerViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredIntuneConfigProfiles.count else { return nil }
        
        let profile = filteredIntuneConfigProfiles[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("ConfigProfileCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier
            
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            cell?.addSubview(textField)
            cell?.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }
        
        switch identifier {
        case "ProfileNameColumn":
            cell?.textField?.stringValue = profile["displayName"] as? String ?? ""
            
        case "AssignedColumn":
            let isAssigned = (profile["isAssigned"] as? Bool) == true
            cell?.textField?.stringValue = isAssigned ? "✅" : "☑️"
            cell?.textField?.alignment = .center
            
        case "ProfileTypeColumn":
            let friendlyType = extractFriendlyProfileTypeFromProfile(profile)
            cell?.textField?.stringValue = friendlyType
            let odataType = profile["@odata.type"] as? String ?? "No @odata.type"
            cell?.toolTip = odataType
            
        case "PlatformColumn":
            let platform = extractPlatformFromProfile(profile)
            cell?.textField?.stringValue = platform
            cell?.textField?.alignment = .center

        case "CreatedColumn":
            let createdDate = profile["createdDateTime"] as? String ?? ""
            cell?.textField?.stringValue = createdDate.formatIntuneDate()
            
        case "ModifiedColumn":
            let modifiedDate = profile["lastModifiedDateTime"] as? String ?? ""
            cell?.textField?.stringValue = modifiedDate.formatIntuneDate()
            
        default:
            cell?.textField?.stringValue = ""
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        let sortDescriptors = tableView.sortDescriptors
        
        filteredIntuneConfigProfiles.sort { profile1, profile2 in
            for sortDescriptor in sortDescriptors {
                let key = sortDescriptor.key ?? ""
                let ascending = sortDescriptor.ascending
                
                var value1: String = ""
                var value2: String = ""
                
                switch key {
                case "ProfileNameColumn":
                    value1 = profile1["displayName"] as? String ?? ""
                    value2 = profile2["displayName"] as? String ?? ""
                case "ProfileTypeColumn":
                    value1 = extractFriendlyProfileTypeFromProfile(profile1)
                    value2 = extractFriendlyProfileTypeFromProfile(profile2)
                case "PlatformColumn":
                    value1 = extractPlatformFromProfile(profile1)
                    value2 = extractPlatformFromProfile(profile2)
                case "AssignedColumn":
                    value1 = (profile1["isAssigned"] as? Bool) == true ? "1" : "0"
                    value2 = (profile2["isAssigned"] as? Bool) == true ? "1" : "0"
                case "CreatedColumn":
                    value1 = profile1["createdDateTime"] as? String ?? ""
                    value2 = profile2["createdDateTime"] as? String ?? ""
                case "ModifiedColumn":
                    value1 = profile1["lastModifiedDateTime"] as? String ?? ""
                    value2 = profile2["lastModifiedDateTime"] as? String ?? ""
                default:
                    continue
                }
                
                let comparison = value1.localizedCaseInsensitiveCompare(value2)
                if comparison != .orderedSame {
                    return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
                }
            }
            return false
        }
        
        tableView.reloadData()
    }
    
    // MARK: - Helper Methods for Data Extraction
    private func extractFriendlyProfileType(from odataType: String) -> String {
        if odataType.lowercased().contains("devicecompliance") || odataType.lowercased().contains("compliancepolicy") {
            return "Device Compliance"
        } else if odataType.lowercased().contains("deviceenrollment") {
            return "Device Enrollment"
        } else if odataType.lowercased().contains("customconfiguration") {
            return "Templates: Custom"
        } else if odataType.lowercased().contains("derivedcredentialauthentication") {
            return "Templates: Derived Credential"
        } else if odataType.lowercased().contains("devicefeatures") {
            return "Templates: Device Features"
        } else if odataType.lowercased().contains("devicefirmware") {
            return "Templates: Device Firmware"
        } else if odataType.lowercased().contains("windows10general") || odataType.lowercased().contains("generaldevice") {
            return "Templates: Device Restrictions"
        } else if odataType.lowercased().contains("windows10teamgeneral") {
            return "Templates: Device Restrictions (Windows 10 Team)"
        } else if odataType.lowercased().contains("domainjoin") {
            return "Templates: Domain Join"
        } else if odataType.lowercased().contains("editionupgrade") || odataType.lowercased().contains("iosupdateconfiguration") {
            return "Templates: Edition Upgrade"
        } else if odataType.lowercased().contains("easemailprofile") {
            return "Templates: Email"
        } else if odataType.lowercased().contains("endpointprotection") || odataType.lowercased().contains("antivirus") {
            return "Templates: Endpoint Protection"
        } else if odataType.lowercased().contains("extensionsconfiguration") {
            return "Templates: Extensions"
        } else if odataType.lowercased().contains("healthmonitoring") {
            return "Templates: Health Monitoring"
        } else if odataType.lowercased().contains("windowskiosk") {
            return "Templates: Kiosk"
        } else if odataType.lowercased().contains("networkboundary") {
            return "Templates: Network Boundary"
        } else if odataType.lowercased().contains("pkcscertificateprofile") {
            return "Templates: PKCS Certificate"
        } else if odataType.lowercased().contains("pfxcertificateprofile") {
            return "Templates: PKCS Imported Certificate"
        } else if odataType.lowercased().contains("customappconfiguration") {
            return "Templates: Preference File"
        } else if odataType.lowercased().contains("scepcertificateprofile") {
            return "Templates: SCEP Certificate"
        } else if odataType.lowercased().contains("edudevice") {
            return "Templates: Secure Assessment"
        } else if odataType.lowercased().contains("sharedpc") {
            return "Templates: Shared Device"
        } else if odataType.lowercased().contains("softwareupdate") {
            return "Templates: Software Update"
        } else if odataType.lowercased().contains("trustedrootcertificate") {
            return "Templates: Trusted Cert"
        } else if odataType.lowercased().contains("vpnconfiguration") {
            return "Templates: VPN"
        } else if odataType.lowercased().contains("wificonfiguration") {
            return "Templates: Wi-Fi"
        } else if odataType.lowercased().contains("wifienterpriseeap") {
            return "Templates: Wi-Fi EAP"
        } else if odataType.lowercased().contains("wirednetwork") {
            return "Templates: Wired Network"
        } else if odataType.lowercased().contains("enterprisewifi") {
            return "Enterprise WiFi"
        } else if odataType.lowercased().contains("expeditedcheckin") {
            return "Expedited Check In"
        } else if odataType.lowercased().contains("hardwareconfiguration") {
            return "Hardware"
        } else if odataType.lowercased().contains("updateconfiguration") {
            return "Update"
        } else if odataType.lowercased().contains("updateforbusiness") {
            return "Windows Update Rings"
        } else {
            return "Configuration Profile"
        }
    }
    
    private func extractFriendlyProfileTypeFromProfile(_ profile: [String: Any]) -> String {
        // First try to extract from @odata.type if available
        if let odataType = profile["@odata.type"] as? String, !odataType.isEmpty {
            return extractFriendlyProfileType(from: odataType)
        }
        
        // Check for injected profile type hints from API processing
        if let profileTypeHint = profile["_profileTypeHint"] as? String {
            switch profileTypeHint {
            case "AdministrativeTemplates":
                return "Templates: Administrative Templates"
            case "WindowsFeatureUpdate":
                return "Windows Feature Update"
            case "WindowsQualityUpdate":
                return "Windows Quality Update"
            case "WindowsDriverUpdate":
                return "Windows Driver Update"
            default:
                break
            }
        }
        
        // Fallback logic for profiles without @odata.type (from modern endpoints)
        
        // Check if this is from groupPolicyConfigurations endpoint
        if let policyConfigurationIngestionType = profile["policyConfigurationIngestionType"] as? String {
            return "Group Policy"
        }
        
        // Check if this profile came from configurationPolicies endpoint (Settings Catalog)
        if let technologies = profile["technologies"] as? String {
            // Technologies field indicates this is from configurationPolicies endpoint
            let techArray = technologies.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            if techArray.contains("mdm") || techArray.contains("android") {
                return "Settings Catalog"
            }
        }
        
        // Check if this profile has templateReference (another indicator of Settings Catalog)
        if let templateReference = profile["templateReference"] as? [String: Any] {
            // This indicates it's from configurationPolicies endpoint
            if let templateDisplayName = templateReference["templateDisplayName"] as? String, !templateDisplayName.isEmpty {
                return "Settings Catalog (Template)"
            } else {
                return "Settings Catalog"
            }
        }
        
        // Check for settingCount field (specific to configurationPolicies)
        if let settingCount = profile["settingCount"] as? Int {
            return "Settings Catalog"
        }
        
        // Check for Windows Update profile types based on profile structure
        // These come from the windowsUpdateForBusinessConfigurations endpoint
        if let profileId = profile["id"] as? String {
            // Check for Windows Update for Business characteristics
            if profile["automaticUpdateMode"] != nil || 
               profile["businessReadyUpdatesOnly"] != nil ||
               profile["deliveryOptimizationMode"] != nil {
                return "Windows Update Ring"
            }
            
            // Check for Feature Update profile characteristics  
            if profile["featureUpdateVersion"] != nil ||
               profile["rolloutSettings"] != nil {
                return "Windows Feature Update"
            }
            
            // Check for Quality Update profile characteristics
            if profile["expeditedUpdateSettings"] != nil ||
               profile["hotpatchSettings"] != nil {
                return "Windows Quality Update"
            }
            
            // Check for Driver Update profile characteristics
            if profile["driverUpdateSettings"] != nil ||
               profile["approvalType"] != nil {
                return "Windows Driver Update"
            }
        }
        
        // If no specific indicators, return generic type
        return "Configuration Profile"
    }
    
    private func extractPlatform(from odataType: String) -> String {
        let lowercaseType = odataType.lowercased()
        
        // Check for Windows first (most specific patterns)
        if lowercaseType.contains("windows") {
            return "Windows"
        }
        // Check for Windows-specific profile types that don't contain "windows" in the name
        else if lowercaseType.contains("editionupgrade") || 
                lowercaseType.contains("sharedpc") {
            return "Windows"
        }
        // Check for Android
        else if lowercaseType.contains("android") {
            return "Android"
        }
        // Check for macOS
        else if lowercaseType.contains("macos") {
            return "macOS"
        }
        // Check for iOS with word boundaries to avoid false matches like "kiosk"
        else if lowercaseType.contains("ipad") || 
                (lowercaseType.contains("ios") && !lowercaseType.contains("kiosk")) {
            return "iOS"
        }
        else {
            return "Unknown"
        }
    }
    
    private func extractPlatformFromProfile(_ profile: [String: Any]) -> String {
        // First try to extract from @odata.type if available
        if let odataType = profile["@odata.type"] as? String, !odataType.isEmpty {
            return extractPlatform(from: odataType)
        }
        
        // Check for injected platform information (from Windows Update endpoints)
        if let injectedPlatform = profile["_injectedPlatform"] as? Bool, injectedPlatform == true {
            if let platforms = profile["platforms"] as? String {
                let platformLower = platforms.lowercased()
                if platformLower.contains("windows") {
                    return "Windows"
                }
            }
        }
        
        // Fallback logic for profiles without @odata.type
        // Check platforms field (configurationPolicies endpoint returns this as a string, not array)
        if let platforms = profile["platforms"] as? String {
            let platformLower = platforms.lowercased()
            if platformLower.contains("windows") || platformLower.contains("windows10") {
                return "Windows"
            } else if platformLower.contains("macos") {
                return "macOS"
            } else if platformLower.contains("ios") {
                return "iOS"
            } else if platformLower.contains("android") || platformLower.contains("aosp") {
                return "Android"
            }
        }
        
        // Check platforms array if available (alternative format)
        if let platforms = profile["platforms"] as? [String] {
            if platforms.count == 1 {
                let platform = platforms[0].lowercased()
                if platform.contains("windows") || platform.contains("windows10") {
                    return "Windows"
                } else if platform.contains("macos") {
                    return "macOS"
                } else if platform.contains("ios") {
                    return "iOS"
                } else if platform.contains("android") {
                    return "Android"
                }
            } else if platforms.count > 1 {
                return "Multi-Platform"
            }
        }
        
        // Check platform field if available (alternative field name)
        if let platform = profile["platform"] as? String {
            let platformLower = platform.lowercased()
            if platformLower.contains("windows") || platformLower.contains("windows10") {
                return "Windows"
            } else if platformLower.contains("macos") {
                return "macOS"
            } else if platformLower.contains("ios") {
                return "iOS"
            } else if platformLower.contains("android") {
                return "Android"
            }
        }
        
        // Check if this is a Group Policy configuration (typically Windows)
        if let policyConfigurationIngestionType = profile["policyConfigurationIngestionType"] as? String {
            return "Windows"
        }
        
        // Check for Windows Update profiles (all Windows-specific)
        if profile["automaticUpdateMode"] != nil || 
           profile["businessReadyUpdatesOnly"] != nil ||
           profile["deliveryOptimizationMode"] != nil ||
           profile["featureUpdateVersion"] != nil ||
           profile["rolloutSettings"] != nil ||
           profile["expeditedUpdateSettings"] != nil ||
           profile["hotpatchSettings"] != nil ||
           profile["driverUpdateSettings"] != nil ||
           profile["approvalType"] != nil {
            return "Windows"
        }
        
        // If no platform information available, return unknown
        return "Unknown"
    }
}
