//
//  AppsReportingManagerViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/11/25.
//

import Cocoa

class AppsReportingManagerViewController: NSViewController {
    // MARK: - Properties
    var intuneApps: [[String: Any]] = []
    var filteredIntuneApps: [[String: Any]] = []
    private var isLoading: Bool = false
    private var currentSearchText: String = ""
    private var showOnlyAssigned: Bool = false
    private var selectedAppType: String = "All" // "All", "macOSDmgApp", "macOSPkgApp", "macOSLobApp"
    private var selectedPlatform: String = "All" // "All", "Android", "iOS", "macOS", "Windows"
    
    // MARK: - UI Elements
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var showAssignedCheckbox: NSButton!
    @IBOutlet weak var appTypePopUpButton: NSPopUpButton!
    @IBOutlet weak var platformPopUpButton: NSPopUpButton!
    @IBOutlet weak var appCountLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    
    //    @IBOutlet weak var addButton: NSButton!
    //    @IBOutlet weak var editButton: NSButton!
    //    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var reportButton: NSButton!
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Apps Installation Status"
        setupUI()
        loadIntuneApps()
        
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
            saveWindowFrame(window, forElement: "AppsReportingManagerViewController")
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Verify IBOutlets are connected
        guard let tableView = tableView,
              let searchField = searchField,
              let showAssignedCheckbox = showAssignedCheckbox,
              let appTypePopUpButton = appTypePopUpButton,
              let platformPopUpButton = platformPopUpButton,
              let appCountLabel = appCountLabel,
              let reportButton = reportButton,
              let activityIndicator = activityIndicator else {
            fatalError("IBOutlets are not properly connected in Interface Builder")
        }
        
        // Configure table view
        tableView.target = self
        tableView.doubleAction = #selector(showDeviceReportButtonClicked(_:))
        
        // Setup column sorting
        setupColumnSorting()
        
        // Configure search field
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.placeholderString = "Search Intune apps..."
        
        // Configure show assigned checkbox
        showAssignedCheckbox.title = "Show only assigned apps"
        
        // Restore saved checkbox state from UserDefaults
        restoreShowAssignedSelection()
        
        showAssignedCheckbox.target = self
        showAssignedCheckbox.action = #selector(showAssignedCheckboxChanged(_:))
        
        // Configure app type popup button
        setupAppTypePopUpButton()
        
        // Configure platform popup button
        setupPlatformPopUpButton()
        
        // Configure app count label
        appCountLabel.stringValue = "0 apps"
        appCountLabel.textColor = NSColor.secondaryLabelColor
        
        // Initially disable edit/delete buttons
        //        deleteButton.isEnabled = false
        //        editButton.isEnabled = false
        reportButton.isEnabled = false
    }
    
    private func setupAppTypePopUpButton() {
        appTypePopUpButton?.target = self
        appTypePopUpButton?.action = #selector(appTypePopUpChanged(_:))
        updateAppTypePopUpButton(for: "All") // Initialize with all platforms
    }
    
    /// Updates the app type popup button based on the selected platform
    /// - Parameter platform: The selected platform ("All", "Android", "iOS", "macOS", "Windows")
    private func updateAppTypePopUpButton(for platform: String) {
        appTypePopUpButton?.removeAllItems()
        
        switch platform {
        case "All":
            appTypePopUpButton?.addItem(withTitle: "All App Types")
            appTypePopUpButton?.item(at: 0)?.tag = 0
            
        case "Android":
            appTypePopUpButton?.addItem(withTitle: "All Android Apps")
            appTypePopUpButton?.addItem(withTitle: "Android LOB")
            appTypePopUpButton?.addItem(withTitle: "Android Store")
            appTypePopUpButton?.addItem(withTitle: "Managed Android LOB")
            appTypePopUpButton?.addItem(withTitle: "Managed Android Store")
            
            appTypePopUpButton?.item(at: 0)?.tag = 0 // All
            appTypePopUpButton?.item(at: 1)?.tag = 1 // LOB
            appTypePopUpButton?.item(at: 2)?.tag = 2 // Store
            appTypePopUpButton?.item(at: 3)?.tag = 3 // Managed LOB
            appTypePopUpButton?.item(at: 4)?.tag = 4 // Managed Store
            
        case "iOS":
            appTypePopUpButton?.addItem(withTitle: "All iOS Apps")
            appTypePopUpButton?.addItem(withTitle: "iOS LOB")
            appTypePopUpButton?.addItem(withTitle: "iOS Store")
            appTypePopUpButton?.addItem(withTitle: "iOS VPP App")
            appTypePopUpButton?.addItem(withTitle: "iOS VPP Ebook")
            appTypePopUpButton?.addItem(withTitle: "iOS WebClip")
            
            appTypePopUpButton?.item(at: 0)?.tag = 0 // All
            appTypePopUpButton?.item(at: 1)?.tag = 1 // LOB
            appTypePopUpButton?.item(at: 2)?.tag = 2 // Store
            appTypePopUpButton?.item(at: 3)?.tag = 3 // VPP App
            appTypePopUpButton?.item(at: 4)?.tag = 4 // VPP Ebook
            appTypePopUpButton?.item(at: 5)?.tag = 5 // WebClip
            
        case "macOS":
            appTypePopUpButton?.addItem(withTitle: "All macOS Apps")
            appTypePopUpButton?.addItem(withTitle: "macOS DMG")
            appTypePopUpButton?.addItem(withTitle: "macOS PKG")
            appTypePopUpButton?.addItem(withTitle: "macOS LOB")
            appTypePopUpButton?.addItem(withTitle: "macOS VPP")
            appTypePopUpButton?.addItem(withTitle: "macOS WebClip")
            appTypePopUpButton?.addItem(withTitle: "macOS Defender")
            appTypePopUpButton?.addItem(withTitle: "macOS Edge")
            appTypePopUpButton?.addItem(withTitle: "macOS Office")
            
            appTypePopUpButton?.item(at: 0)?.tag = 0 // All
            appTypePopUpButton?.item(at: 1)?.tag = 1 // DMG
            appTypePopUpButton?.item(at: 2)?.tag = 2 // PKG
            appTypePopUpButton?.item(at: 3)?.tag = 3 // LOB
            appTypePopUpButton?.item(at: 4)?.tag = 4 // VPP
            appTypePopUpButton?.item(at: 5)?.tag = 5 // WebClip
            appTypePopUpButton?.item(at: 6)?.tag = 6 // Defender
            appTypePopUpButton?.item(at: 7)?.tag = 7 // Edge
            appTypePopUpButton?.item(at: 8)?.tag = 8 // Office
            
        case "Windows":
            appTypePopUpButton?.addItem(withTitle: "All Windows Apps")
            appTypePopUpButton?.addItem(withTitle: "Windows Win32 LOB")
            appTypePopUpButton?.addItem(withTitle: "Windows Store")
            appTypePopUpButton?.addItem(withTitle: "Windows AppX")
            appTypePopUpButton?.addItem(withTitle: "Windows Universal AppX")
            appTypePopUpButton?.addItem(withTitle: "Windows MSI")
            appTypePopUpButton?.addItem(withTitle: "Windows Office")
            appTypePopUpButton?.addItem(withTitle: "Windows Business Store")
            appTypePopUpButton?.addItem(withTitle: "Windows WebApp")
            appTypePopUpButton?.addItem(withTitle: "Windows Edge")
            
            appTypePopUpButton?.item(at: 0)?.tag = 0 // All
            appTypePopUpButton?.item(at: 1)?.tag = 1 // Win32 LOB
            appTypePopUpButton?.item(at: 2)?.tag = 2 // Store
            appTypePopUpButton?.item(at: 3)?.tag = 3 // AppX
            appTypePopUpButton?.item(at: 4)?.tag = 4 // Universal AppX
            appTypePopUpButton?.item(at: 5)?.tag = 5 // MSI
            appTypePopUpButton?.item(at: 6)?.tag = 6 // Office
            appTypePopUpButton?.item(at: 7)?.tag = 7 // Business Store
            appTypePopUpButton?.item(at: 8)?.tag = 8 // WebApp
            appTypePopUpButton?.item(at: 9)?.tag = 9 // Edge
            
        default:
            appTypePopUpButton?.addItem(withTitle: "All App Types")
            appTypePopUpButton?.item(at: 0)?.tag = 0
        }
        
        // Always select "All" for the platform when switching
        appTypePopUpButton?.selectItem(at: 0)
        selectedAppType = "All"
    }
    
    private func setupPlatformPopUpButton() {
        platformPopUpButton?.removeAllItems()
        
        // Add platform options
        platformPopUpButton?.addItem(withTitle: "All Platforms")
        platformPopUpButton?.addItem(withTitle: "Android")
        platformPopUpButton?.addItem(withTitle: "iOS")
        platformPopUpButton?.addItem(withTitle: "macOS")
        platformPopUpButton?.addItem(withTitle: "Windows")
        
        // Set tags for easy identification
        platformPopUpButton?.item(at: 0)?.tag = 0 // All
        platformPopUpButton?.item(at: 1)?.tag = 1 // Android
        platformPopUpButton?.item(at: 2)?.tag = 2 // iOS
        platformPopUpButton?.item(at: 3)?.tag = 3 // macOS
        platformPopUpButton?.item(at: 4)?.tag = 4 // Windows
        
        // Restore saved platform selection from UserDefaults
        restorePlatformSelection()
        
        platformPopUpButton?.target = self
        platformPopUpButton?.action = #selector(platformPopUpChanged(_:))
    }
    
    /// Restores the platform selection from UserDefaults
    private func restorePlatformSelection() {
        let savedPlatform = UserDefaults.standard.string(forKey: "AppsReportingManager.SelectedPlatform") ?? "All"
        
        let platformMapping: [String: Int] = [
            "All": 0,
            "Android": 1,
            "iOS": 2,
            "macOS": 3,
            "Windows": 4
        ]
        
        if let index = platformMapping[savedPlatform] {
            platformPopUpButton?.selectItem(at: index)
            selectedPlatform = savedPlatform
        } else {
            // Fallback to "All" if saved value is invalid
            platformPopUpButton?.selectItem(at: 0)
            selectedPlatform = "All"
        }
        
        // Update app type popup based on restored platform
        updateAppTypePopUpButton(for: selectedPlatform)
    }
    
    /// Saves the current platform selection to UserDefaults
    private func savePlatformSelection() {
        UserDefaults.standard.set(selectedPlatform, forKey: "AppsReportingManager.SelectedPlatform")
    }
    
    /// Restores the show assigned checkbox state from UserDefaults
    private func restoreShowAssignedSelection() {
        let savedShowAssigned = UserDefaults.standard.bool(forKey: "AppsReportingManager.ShowOnlyAssigned")
        
        showOnlyAssigned = savedShowAssigned
        showAssignedCheckbox.state = showOnlyAssigned ? .on : .off
    }
    
    /// Saves the current show assigned checkbox state to UserDefaults
    private func saveShowAssignedSelection() {
        UserDefaults.standard.set(showOnlyAssigned, forKey: "AppsReportingManager.ShowOnlyAssigned")
    }
    
    /// Sets up column sorting for sortable table columns (excludes ID and button columns)
    private func setupColumnSorting() {
        for column in tableView.tableColumns {
            // Skip non-sortable columns
            guard column.identifier.rawValue != "id" && column.identifier.rawValue != "openInIntune" else { continue }
            
            let sortDescriptor = NSSortDescriptor(key: column.identifier.rawValue, ascending: true)
            column.sortDescriptorPrototype = sortDescriptor
        }
    }
    
    // MARK: - Data Loading
    private func loadIntuneApps() {
        // Prevent concurrent loading
        guard !isLoading else {
            Logger.info("Intune Apps already loading, skipping duplicate request", toUserDirectory: true)
            return
        }
        
        // Safety check for activityIndicator
        guard let activityIndicator = activityIndicator else {
            Logger.error("activityIndicator is nil - IBOutlet not connected", category: .core, toUserDirectory: true)
            return
        }
        
        isLoading = true
        activityIndicator.isHidden = false
        activityIndicator.startAnimation(nil)
        
        XPCManager.shared.fetchIntuneApps { [weak self] intuneApps in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let intuneApps = intuneApps {
                    // Update the Intune apps array
                    self.intuneApps = intuneApps
                    
                    // Sort Intune apps and reload table view consistently
                    self.reloadTableData()
                    
                    // Reset selection and update button state
                    self.tableView?.deselectAll(nil)
                    self.updateButtonState()
                    
                    Logger.info("Loaded \(self.intuneApps.count) Intune apps", toUserDirectory: true)
                } else {
                    Logger.error("Failed to fetch Intune apps", category: .core, toUserDirectory: true)
                    self.showAlert(title: "Error", message: "Failed to load apps from Intune")
                }
                
                // Stop activity indicator and reset loading flag
                self.activityIndicator?.stopAnimation(nil)
                self.activityIndicator?.isHidden = true
                self.isLoading = false
            }
        }
    }
    
    // Ensuring sorting consistency
    func reloadTableData() {
        sortIntuneApps()
        applySearchFilter()
        updateAppCount()
        tableView?.reloadData()
    }
    
    private func sortIntuneApps() {
        intuneApps.sort { intuneApp1, intuneApp2 in
            let name1 = intuneApp1["displayName"] as? String ?? ""
            let name2 = intuneApp2["displayName"] as? String ?? ""
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    // MARK: - Search and Filtering
    
    private func applySearchFilter() {
        filteredIntuneApps = intuneApps.filter { intuneApp in
            // Apply text search filter
            let matchesTextSearch: Bool
            if currentSearchText.isEmpty {
                matchesTextSearch = true
            } else {
                let displayName = intuneApp["displayName"] as? String ?? ""
                let appType = intuneApp["@odata.type"] as? String ?? ""
                let appId = intuneApp["id"] as? String ?? ""
                
                matchesTextSearch = displayName.localizedCaseInsensitiveContains(currentSearchText) ||
                appType.localizedCaseInsensitiveContains(currentSearchText) ||
                appId.localizedCaseInsensitiveContains(currentSearchText)
            }
            
            // Apply assignment filter
            let matchesAssignmentFilter: Bool
            if showOnlyAssigned {
                let isAssigned = intuneApp["isAssigned"] as? Bool ?? false
                matchesAssignmentFilter = isAssigned
            } else {
                matchesAssignmentFilter = true
            }
            
            // Apply app type filter
            let matchesAppTypeFilter: Bool
            if selectedAppType == "All" {
                matchesAppTypeFilter = true
            } else {
                let appDataType = intuneApp["@odata.type"] as? String ?? ""
                matchesAppTypeFilter = appDataType == "#microsoft.graph.\(selectedAppType)"
            }
            
            // Apply platform filter
            let matchesPlatformFilter: Bool
            if selectedPlatform == "All" {
                matchesPlatformFilter = true
            } else {
                let appDataType = intuneApp["@odata.type"] as? String ?? ""
                matchesPlatformFilter = checkPlatformMatch(appDataType: appDataType, selectedPlatform: selectedPlatform)
            }
            
            // All filters must match
            return matchesTextSearch && matchesAssignmentFilter && matchesAppTypeFilter && matchesPlatformFilter
        }
    }
    
    private func updateAppCount() {
        let totalCount = intuneApps.count
        let filteredCount = filteredIntuneApps.count
        
        let hasActiveFilters = !currentSearchText.isEmpty || showOnlyAssigned || selectedAppType != "All" || selectedPlatform != "All"
        
        if hasActiveFilters {
            appCountLabel?.stringValue = "\(filteredCount) of \(totalCount) apps"
        } else {
            appCountLabel?.stringValue = "\(totalCount) apps"
        }
    }
    
    private func refreshFiltersAndTable() {
        applySearchFilter()
        updateAppCount()
        tableView?.reloadData()
        
        // Reset selection when filters change
        tableView?.deselectAll(nil)
        updateButtonState()
    }
    
    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        currentSearchText = sender.stringValue
        refreshFiltersAndTable()
    }
    
    @objc private func showAssignedCheckboxChanged(_ sender: NSButton) {
        showOnlyAssigned = sender.state == .on
        
        // Save the selection to UserDefaults
        saveShowAssignedSelection()
        
        refreshFiltersAndTable()
    }
    
    @objc private func appTypePopUpChanged(_ sender: NSPopUpButton) {
        let selectedTag = sender.selectedTag()
        selectedAppType = getAppTypeFromTag(selectedTag, platform: selectedPlatform)
        refreshFiltersAndTable()
    }
    
    /// Maps popup button tag to app type based on current platform
    /// - Parameters:
    ///   - tag: The selected tag from the popup button
    ///   - platform: The currently selected platform
    /// - Returns: The app type string for filtering
    private func getAppTypeFromTag(_ tag: Int, platform: String) -> String {
        if tag == 0 { return "All" } // First item is always "All"
        
        switch platform {
        case "Android":
            switch tag {
            case 1: return "androidLobApp"
            case 2: return "androidStoreApp"
            case 3: return "managedAndroidLobApp"
            case 4: return "managedAndroidStoreApp"
            default: return "All"
            }
        case "iOS":
            switch tag {
            case 1: return "iosLobApp"
            case 2: return "iosStoreApp"
            case 3: return "iosVppApp"
            case 4: return "iosVppEBook"
            case 5: return "iosiPadOSWebClip"
            default: return "All"
            }
        case "macOS":
            switch tag {
            case 1: return "macOSDmgApp"
            case 2: return "macOSPkgApp"
            case 3: return "macOSLobApp"
            case 4: return "macOsVppApp"
            case 5: return "macOSWebClip"
            case 6: return "macOSMicrosoftDefenderApp"
            case 7: return "macOSMicrosoftEdgeApp"
            case 8: return "macOSOfficeSuiteApp"
            default: return "All"
            }
        case "Windows":
            switch tag {
            case 1: return "win32LobApp"
            case 2: return "winGetApp"
            case 3: return "windowsAppX"
            case 4: return "windowsUniversalAppX"
            case 5: return "windowsMobileMSI"
            case 6: return "officeSuiteApp"
            case 7: return "microsoftStoreForBusinessApp"
            case 8: return "windowsWebApp"
            case 9: return "windowsMicrosoftEdgeApp"
            default: return "All"
            }
        default:
            return "All"
        }
    }
    
    @objc private func platformPopUpChanged(_ sender: NSPopUpButton) {
        let selectedTag = sender.selectedTag()
        switch selectedTag {
        case 0:
            selectedPlatform = "All"
        case 1:
            selectedPlatform = "Android"
        case 2:
            selectedPlatform = "iOS"
        case 3:
            selectedPlatform = "macOS"
        case 4:
            selectedPlatform = "Windows"
        default:
            selectedPlatform = "All"
        }
        
        // Update app type popup button based on platform selection
        updateAppTypePopUpButton(for: selectedPlatform)
        
        // Save the selection to UserDefaults
        savePlatformSelection()
        
        refreshFiltersAndTable()
    }
    
    /// Checks if an app's @odata.type matches the selected platform
    /// - Parameters:
    ///   - appDataType: The @odata.type string from Microsoft Graph
    ///   - selectedPlatform: The platform to filter by (Android, iOS, macOS, Windows)
    /// - Returns: True if the app matches the platform filter
    private func checkPlatformMatch(appDataType: String, selectedPlatform: String) -> Bool {
        switch selectedPlatform {
        case "Android":
            return appDataType.contains("android") || appDataType.contains("Android")
        case "iOS":
            return appDataType.contains("ios") || appDataType.contains("iOS") || appDataType.contains("iPadOS")
        case "macOS":
            return appDataType.contains("macOS") || appDataType.contains("macos")
        case "Windows":
            return appDataType.contains("windows") || appDataType.contains("Windows") || appDataType.contains("win32") || appDataType.contains("officeSuiteApp") || appDataType.contains("microsoftStoreForBusinessApp")
        default:
            return true
        }
    }
    
    // MARK: - Actions
    @IBAction func refreshButtonClicked(_ sender: NSButton) {
        refreshIntuneApps()
    }
    
    //    @IBAction func tableViewDoubleClicked(_ sender: NSTableView) {
    //        editWebClip()
    //    }
    
    // MARK: - Button Actions
    
    @objc private func refreshIntuneApps() {
        loadIntuneApps()
    }
    
    @IBAction func showDeviceReportButtonClicked(_ sender: NSButton) {
        showDeviceReport()
    }
    
    /// Opens the selected app in the Intune web console
    @objc private func openInIntuneButtonClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < filteredIntuneApps.count else {
            Logger.error("Invalid row index for opening in Intune: \(row)", category: .core)
            return
        }
        
        let intuneApp = filteredIntuneApps[row]
        guard let appId = intuneApp["id"] as? String else {
            showError(message: "Unable to get app ID for opening in Intune console")
            return
        }
        
        openAppInIntuneConsole(appId: appId)
    }
    
    /// Opens the specified app in the Intune web console using the default browser
    /// - Parameter appId: The app GUID to open in the console
    private func openAppInIntuneConsole(appId: String) {
        let intuneURL = "https://intune.microsoft.com/#view/Microsoft_Intune_Apps/SettingsMenu/~/0/appId/\(appId)"
        
        guard let url = URL(string: intuneURL) else {
            showError(message: "Failed to create valid Intune console URL")
            return
        }
        
        NSWorkspace.shared.open(url)
        Logger.info("Opened app \(appId) in Intune console: \(intuneURL)", category: .core)
    }
    
    private func showDeviceReport() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < filteredIntuneApps.count else {
            showError(message: "Please select an app.")
            return
        }
        let intuneApp = filteredIntuneApps[selectedRow]
        
        let storyboard = NSStoryboard(name: "AppsReporting", bundle: nil)
        let reportVC = storyboard.instantiateController(withIdentifier: "AppsReportingViewController") as! AppsReportingViewController
        
        reportVC.configure(with: intuneApp)
        presentAsSheet(reportVC)
        
    }
    
    // MARK: - Assignment Data Transformation
    
    /// Looks up group display name by ID from cached Entra groups
    /// - Parameter groupId: The group GUID to look up
    /// - Returns: Display name if found, or formatted GUID if not found
    private func getGroupDisplayName(for groupId: String) -> String {
        let cachedGroups = AppDataManager.shared.getEntraGroups()
        if let group = cachedGroups.first(where: { $0["id"] as? String == groupId }),
           let displayName = group["displayName"] as? String {
            return displayName
        }
        // Fallback to formatted GUID if group not found in cache
        return "Group \(groupId.prefix(8))..."
    }
    
    /// Transforms Microsoft Graph assignment data to GroupAssignmentViewController format
    /// - Parameter graphAssignments: Raw assignments from Microsoft Graph API
    /// - Returns: Transformed assignments compatible with GroupAssignmentViewController
    private func transformAssignmentsForGroupView(_ graphAssignments: [[String: Any]]) -> [[String: Any]] {
        var transformedAssignments: [[String: Any]] = []
        
        for assignment in graphAssignments {
            guard let target = assignment["target"] as? [String: Any],
                  let targetType = target["@odata.type"] as? String else {
                continue
            }
            
            var transformedAssignment: [String: Any] = [:]
            
            // Extract the actual assignment intent (required/available/uninstall) from Graph API
            let assignmentIntent = assignment["intent"] as? String ?? "required"
            let assignmentType = assignmentIntent.capitalized // Convert to Required, Available, Uninstall
            
            // Transform based on target type
            switch targetType {
            case "#microsoft.graph.allDevicesAssignmentTarget":
                transformedAssignment["displayName"] = "All Devices"
                transformedAssignment["groupId"] = "adadadad-808e-44e2-905a-0b7873a8a531"
                transformedAssignment["isVirtual"] = true
                transformedAssignment["mode"] = "include"
                transformedAssignment["assignmentType"] = assignmentType
                
            case "#microsoft.graph.allLicensedUsersAssignmentTarget":
                transformedAssignment["displayName"] = "All Users"
                transformedAssignment["groupId"] = "acacacac-9df4-4c7d-9d50-4ef0226f57a9"
                transformedAssignment["isVirtual"] = true
                transformedAssignment["mode"] = "include"
                transformedAssignment["assignmentType"] = assignmentType
                
            case "#microsoft.graph.groupAssignmentTarget":
                if let groupId = target["groupId"] as? String {
                    transformedAssignment["groupId"] = groupId
                    
                    // Check if this is a virtual group
                    if groupId == "adadadad-808e-44e2-905a-0b7873a8a531" {
                        transformedAssignment["displayName"] = "All Devices"
                        transformedAssignment["isVirtual"] = true
                    } else if groupId == "acacacac-9df4-4c7d-9d50-4ef0226f57a9" {
                        transformedAssignment["displayName"] = "All Users"
                        transformedAssignment["isVirtual"] = true
                    } else {
                        transformedAssignment["displayName"] = getGroupDisplayName(for: groupId)
                        transformedAssignment["isVirtual"] = false
                        transformedAssignment["id"] = groupId  // Add id field for real groups
                    }
                    
                    transformedAssignment["mode"] = "include"
                    transformedAssignment["assignmentType"] = assignmentType
                }
                
            case "#microsoft.graph.exclusionGroupAssignmentTarget":
                if let groupId = target["groupId"] as? String {
                    transformedAssignment["groupId"] = groupId
                    
                    // Check if this is a virtual group (though exclude shouldn't be used for virtual groups)
                    if groupId == "adadadad-808e-44e2-905a-0b7873a8a531" {
                        transformedAssignment["displayName"] = "All Devices"
                        transformedAssignment["isVirtual"] = true
                    } else if groupId == "acacacac-9df4-4c7d-9d50-4ef0226f57a9" {
                        transformedAssignment["displayName"] = "All Users"
                        transformedAssignment["isVirtual"] = true
                    } else {
                        transformedAssignment["displayName"] = getGroupDisplayName(for: groupId)
                        transformedAssignment["isVirtual"] = false
                        transformedAssignment["id"] = groupId  // Add id field for real groups
                    }
                    
                    transformedAssignment["mode"] = "exclude"
                    transformedAssignment["assignmentType"] = assignmentType
                }
                
            default:
                // Skip unknown target types
                continue
            }
            
            // Extract filter information from the target if present
            if let filterId = target["deviceAndAppManagementAssignmentFilterId"] as? String,
               let filterType = target["deviceAndAppManagementAssignmentFilterType"] as? String {
                
                // Look up filter display name from cached filters
                let cachedFilters = AppDataManager.shared.getEntraFilters()
                let filterDisplayName = cachedFilters.first(where: { $0["id"] as? String == filterId })?["displayName"] as? String ?? "Unknown Filter"
                
                transformedAssignment["filter"] = [
                    "id": filterId,
                    "mode": filterType, // Keep original case (include/exclude)
                    "displayName": filterDisplayName
                ]
                
            }
            
            // Add assignment ID for future operations
            if let assignmentId = assignment["id"] as? String {
                transformedAssignment["assignmentId"] = assignmentId
            }
            
            transformedAssignments.append(transformedAssignment)
        }
        
        return transformedAssignments
    }
    
    // MARK: - Helper Methods
    
    private func updateButtonState() {
        let hasSelection = tableView.selectedRow >= 0
        //        deleteButton?.isEnabled = hasSelection
        //        editButton?.isEnabled = hasSelection
        reportButton?.isEnabled = hasSelection
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - User Feedback
    
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

extension AppsReportingManagerViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredIntuneApps.count
    }
}

// MARK: - NSTableViewDelegate

extension AppsReportingManagerViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredIntuneApps.count else { return nil }
        
        let intuneApp = filteredIntuneApps[row]
        let cellIdentifier = tableColumn?.identifier.rawValue ?? ""
        
        let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(cellIdentifier), owner: self) as? NSTableCellView
        
        switch cellIdentifier {
        case "displayName":
            cellView?.textField?.stringValue = intuneApp["displayName"] as? String ?? "Unknown"
            cellView?.textField?.toolTip = intuneApp["displayName"] as? String ?? "Unknown"
        case "isAssigned":
            let isAssigned = intuneApp["isAssigned"] as? Bool ?? false
            cellView?.textField?.stringValue = isAssigned ? "✅" : "☑️"
            cellView?.textField?.textColor = isAssigned ? NSColor.systemGreen : NSColor.systemYellow
            cellView?.textField?.toolTip = isAssigned ? "Assigned to Entra ID groups" : "Not assigned to Entra ID groups"
        case "isAutomatedByIntuneomator":
            let notes = intuneApp["notes"] as? String ?? ""
            // Regex pattern: ends with "Intuneomator ID: " + UUID
            let pattern = #"Intuneomator ID: [A-F0-9\-]{36}$"#
            let isAutomated = notes.range(of: pattern, options: .regularExpression) != nil
            cellView?.textField?.stringValue = isAutomated ? "✅" : "☑️"
            cellView?.textField?.toolTip = isAutomated ? "Automated by Intuneomator" : "Unmanaged"

        case "appType":
            let appDataType = intuneApp["@odata.type"] as? String ?? "Unknown"
            cellView?.textField?.stringValue = convertAppTypeToSortableString(appDataType)
            cellView?.textField?.toolTip = appDataType
        case "openInIntune":
            // Create a button for opening in Intune console
            if let button = cellView?.subviews.first as? NSButton {
                button.title = "Open in Intune"
                button.target = self
                button.action = #selector(openInIntuneButtonClicked(_:))
                button.tag = row // Store row index in button tag
                button.bezelStyle = .rounded
                button.bezelColor = NSColor.systemBlue
                button.controlSize = .mini
                button.toolTip = "Open in Intune console"

            } else {
                // Create button if it doesn't exist
                let button = NSButton(frame: NSRect(x: 5, y: 2, width: 100, height: 20))
                button.title = "Open in Intune"
                button.target = self
                button.action = #selector(openInIntuneButtonClicked(_:))
                button.tag = row
                button.bezelStyle = .rounded
                button.bezelColor = NSColor.systemBlue
                button.controlSize = .mini
                button.font = NSFont.systemFont(ofSize: 9)
                button.toolTip = "Open in Intune console"
                
                cellView?.addSubview(button)
            }
            cellView?.textField?.stringValue = ""
        case "id":
            cellView?.textField?.stringValue = intuneApp["id"] as? String ?? "Unknown"
        default:
            cellView?.textField?.stringValue = ""
        }
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonState()
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }
        
        sortFilteredIntuneApps(by: sortDescriptor)
        tableView.reloadData()
    }
    
    /// Sorts the filtered Intune apps array by the given sort descriptor
    /// - Parameter sortDescriptor: The sort descriptor to apply
    private func sortFilteredIntuneApps(by sortDescriptor: NSSortDescriptor) {
        filteredIntuneApps.sort { intuneApp1, intuneApp2 in
            var value1: Any?
            var value2: Any?
            
            switch sortDescriptor.key {
            case "displayName":
                value1 = intuneApp1["displayName"] as? String ?? ""
                value2 = intuneApp2["displayName"] as? String ?? ""
            case "isAssigned":
                value1 = intuneApp1["isAssigned"] as? Bool ?? false
                value2 = intuneApp2["isAssigned"] as? Bool ?? false
            case "appType":
                // Convert @odata.type to user-friendly string for sorting
                let appDataType1 = intuneApp1["@odata.type"] as? String ?? ""
                let appDataType2 = intuneApp2["@odata.type"] as? String ?? ""
                value1 = convertAppTypeToSortableString(appDataType1)
                value2 = convertAppTypeToSortableString(appDataType2)
            default:
                return false
            }
            
            // Handle different value types
            if let bool1 = value1 as? Bool, let bool2 = value2 as? Bool {
                return sortDescriptor.ascending ? (!bool1 && bool2) : (bool1 && !bool2)
            } else if let string1 = value1 as? String, let string2 = value2 as? String {
                let result = string1.localizedCaseInsensitiveCompare(string2)
                return sortDescriptor.ascending ? (result == .orderedAscending) : (result == .orderedDescending)
            }
            
            return false
        }
    }
    
    /// Converts @odata.type to a user-friendly string for display and sorting purposes
    /// - Parameter appDataType: The @odata.type string from Microsoft Graph
    /// - Returns: User-friendly string for consistent display and sorting
    private func convertAppTypeToSortableString(_ appDataType: String) -> String {
        switch appDataType {
        // Android Apps
        case "#microsoft.graph.androidLobApp":
            return "Android LOB"
        case "#microsoft.graph.androidStoreApp":
            return "Android Store"
        case "#microsoft.graph.managedAndroidLobApp":
            return "Managed Android LOB"
        case "#microsoft.graph.managedAndroidStoreApp":
            return "Managed Android Store"
        case "#microsoft.graph.webApp":
            return "Web App"

        // iOS Apps
        case "#microsoft.graph.iosLobApp":
            return "iOS LOB"
        case "#microsoft.graph.iosStoreApp":
            return "iOS Store"
        case "#microsoft.graph.iosVppApp":
            return "iOS VPP App"
        case "#microsoft.graph.iosVppEBook":
            return "iOS VPP Ebook"
        case "#microsoft.graph.iosiPadOSWebClip":
            return "iOS WebClip"
            
        // macOS Apps
        case "#microsoft.graph.macOSDmgApp":
            return "macOS DMG"
        case "#microsoft.graph.macOSLobApp":
            return "macOS LOB"
        case "#microsoft.graph.macOSPkgApp":
            return "macOS PKG"
        case "#microsoft.graph.macOSMicrosoftDefenderApp":
            return "macOS Defender"
        case "#microsoft.graph.macOSMicrosoftEdgeApp":
            return "macOS Edge"
        case "#microsoft.graph.macOSOfficeSuiteApp":
            return "macOS Office"
        case "#microsoft.graph.macOsVppApp":
            return "macOS VPP"
        case "#microsoft.graph.macOSWebClip":
            return "macOS WebClip"
            
        // Windows Apps
        case "#microsoft.graph.windowsAppX":
            return "Windows AppX"
        case "#microsoft.graph.windowsMicrosoftEdgeApp":
            return "Windows Edge"
        case "#microsoft.graph.windowsMobileMSI":
            return "Windows MSI"
        case "#microsoft.graph.officeSuiteApp":
            return "Windows Office"
        case "#microsoft.graph.win32LobApp":
            return "Windows Win32 LOB"
        case "#microsoft.graph.winGetApp":
            return "Windows Store (New)"
        case "#microsoft.graph.windowsUniversalAppX":
            return "Windows Universal AppX"
        case "#microsoft.graph.windowsUniversalAppXContainedApp":
            return "Windows Universal AppX Contained"
        case "#microsoft.graph.microsoftStoreForBusinessApp":
            return "Windows Store (Legacy)"
        case "#microsoft.graph.windowsWebApp":
            return "Windows WebApp"
            
        default:
            return appDataType
        }
    }
}
