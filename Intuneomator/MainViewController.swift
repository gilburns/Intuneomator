//
//  MainViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/11/25.
//

import Cocoa
import UniformTypeIdentifiers

class MainViewController: NSViewController {
    
    var appData: [AppInfo] = []
    var filteredAppData: [AppInfo] = []
    
    var validationCache: [String: Bool] = [:] // Cache with folder paths as keys
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var headerView: NSTableHeaderView!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var appSearchField: NSSearchField!
    @IBOutlet weak var labelCountField: NSTextField!
    
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var editButton: NSButton!
    @IBOutlet weak var infoButton: NSButton!
    
    @IBOutlet weak var labelVersionInfo: NSTextField!
    
    @IBOutlet weak var progressSpinner: NSProgressIndicator!
    
    var searchBuffer: String = ""
    var searchTimer: Timer?

    var scriptManagerWindowControllers: [NSWindowController] = []
    var customAttributeManagerWindowControllers: [NSWindowController] = []
    var appCategoryManagerWindowControllers: [NSWindowController] = []
    var discoveredAppsManagerWindowControllers: [NSWindowController] = []

    
    // MARK: -  Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start the heartbeat
        XPCManager.shared.beginXPCServiceTransaction { success in
            if success ?? false {
                print("XPC service transaction started")
            } else {
                print("Failed to start XPC service transaction")
            }
        }
        
        // Store reference in AppDelegate
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.mainViewController = self
        }

        registerNotifications()
        
        setupTableView()

        refreshUI()
        
        labelVersionInfo.stringValue = formattedAppVersion()

    }
    
    
    func applicationDidFinishLaunching(_ notification: Notification) {

    }
    
    func applicationWillTerminate(_ notification: Notification) {
        XPCManager.shared.endXPCServiceTransaction { success in
            if success ?? false {
//                print("XPC service transaction ended")
            }
        }
        
        XPCManager.shared.endXPCServiceTransaction { _ in }
    }
    
    
    // MARK: - Actions
    @IBAction func sendMessageToDaemon(_ sender: Any) {
        XPCManager.shared.sendMessageToDaemon(message: "Hello from GUI") { response in
            DispatchQueue.main.async {
//                print("GUI received: \(response ?? "")")
            }
        }
    }
    
    @IBAction func addRow(_ sender: Any) {
        presentSheet(withIdentifier: "LabelView")
    }

    @IBAction func removeRow(_ sender: Any) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }

        // Get the name of the selected item for the confirmation dialog
        let itemToRemove = filteredAppData[selectedRow]
        let itemName = itemToRemove.name
        let itemLabel = itemToRemove.label
        Logger.logUser("Button clicked to delete '\(itemName)' directory.")

        // Create a confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Confirm Deletion"
        alert.informativeText = "Are you sure you want to delete '\(itemName) - \(itemLabel)'? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        // Show the dialog and handle the response
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // User confirmed deletion
            Logger.logUser("User confirmed deletion of '\(itemName)' directory.")
            // Remove the directory associated with the item
            let directoryPath = (AppConstants.intuneomatorManagedTitlesFolderURL.path as NSString).appendingPathComponent("\(itemToRemove.label)_\(itemToRemove.guid)")

            
            XPCManager.shared.removeLabelContent(directoryPath) { success in
                if success! {
//                    Logger.logUser("Deleted directory: \(directoryPath)")
                } else {
                    Logger.logUser("Failed to delete directory: \(directoryPath)")
                    return
                }
            }
    
            // Remove the item from appData and reload the table view
            if let appDataIndex = appData.firstIndex(where: { $0.name == itemName }) {
                // Remove from the original array
                appData.remove(at: appDataIndex)
            }

            // Also remove from the filtered array
            filteredAppData.remove(at: selectedRow)
            tableView.reloadData()
            setLabelCount()

            // Disable buttons after deletion
            editButton.isEnabled = false
            removeButton.isEnabled = false
        } else {
            // User canceled deletion
            Logger.logUser("User canceled deletion")
        }
        refreshUI()
    }

    @IBAction func editAppItem(_ sender: Any) {
        guard tableView.selectedRow >= 0 else { return }
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let tabViewController = storyboard.instantiateController(withIdentifier: "TabView") as? TabViewController else { return }
        
        tabViewController.appData = filteredAppData[tableView.selectedRow]
        presentAsSheet(tabViewController)
        
        if let sheetWindow = tabViewController.view.window {
            sheetWindow.styleMask.insert(.resizable) // Allow resizing
            sheetWindow.titleVisibility = .hidden // Optional: Hide the sheet title
        }
    }
    
    @IBAction func openSettings(_ sender: Any) {
        presentSheet(withIdentifier: "SettingsView")
    }

    @IBAction func openCertificateGeneration(_ sender: Any) {
        presentSheet(withIdentifier: "CertificateView")
    }

    @IBAction func openScheduleEditor(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let controller = storyboard.instantiateController(withIdentifier: "ScheduleEditorViewController") as? ScheduleEditorViewController else { return }

        presentAsSheet(controller)

    }

    @IBAction func openStatisticsSheet(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let controller = storyboard.instantiateController(withIdentifier: "StatsViewController") as? StatsViewController else { return }

        presentAsSheet(controller)

    }

    
// MARK: - Discovered Apps

    @IBAction func openDiscoveredAppsManagerWindow(_ sender: Any) {
        // Check if there's an existing Discovered Apps Manager window
        if let existingWindowController = discoveredAppsManagerWindowControllers.first(where: { $0.window?.isVisible == true }) {
            existingWindowController.window?.makeKeyAndOrderFront(nil) // Bring to front
            return
        }

        let storyboard = NSStoryboard(name: "Main", bundle: nil)

        guard let discoveredAppsManagerVC = storyboard.instantiateController(withIdentifier: "DiscoveredAppsViewController") as? DiscoveredAppsViewController else {
            print("Failed to instantiate DiscoveredAppsViewController")
            return
        }

        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 420

        let discoveredAppsManagerWindow = NSWindow(
            contentRect: NSMakeRect(0, 0, windowWidth, windowHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        discoveredAppsManagerWindow.contentViewController = discoveredAppsManagerVC
        discoveredAppsManagerWindow.title = "Intune Discovered Apps"

        // Explicitly set the window frame to fix initial sizing issue
        discoveredAppsManagerWindow.setFrame(NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight), display: true)

        // Set minimum and maximum window size
        discoveredAppsManagerWindow.minSize = NSSize(width: windowWidth, height: windowHeight)
//        discoveredAppsManagerWindow.maxSize = NSSize(width: windowWidth, height: windowHeight)

        // Center the window on the screen
        discoveredAppsManagerWindow.center()

        let windowController = NSWindowController(window: discoveredAppsManagerWindow)
        windowController.showWindow(self)

        // Keep reference to prevent deallocation
        discoveredAppsManagerWindowControllers.append(windowController)
    }

    @objc func appDiscoveredAppsManagerWindowClosed(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow {
            // Remove closed window from tracking
            discoveredAppsManagerWindowControllers.removeAll { $0.window == closedWindow }
        }
    }

    
    // MARK: - Open Folders
    @IBAction func openTempFolder(_ sender: Any) {
        NSWorkspace.shared.open(AppConstants.intuneomatorTempFolderURL)
    }

    @IBAction func openIntuneomatorFolder(_ sender: Any) {
        NSWorkspace.shared.open(AppConstants.intuneomatorFolderURL)
    }

    @IBAction func openLogDirectory(_ sender: Any) {
        let logURL = AppConstants.intuneomatorLogSystemURL

        if FileManager.default.fileExists(atPath: logURL.path) {
            do {
                NSWorkspace.shared.open(URL(fileURLWithPath: logURL.path))
                }
        } else {
//            print("Log folder doesn't exist yet.")
        }
    }

    @IBAction func openAppLogDirectory(_ sender: Any) {
        let logURL = AppConstants.intuneomatorLogApplicationURL

        if FileManager.default.fileExists(atPath: logURL.path) {
            do {
                NSWorkspace.shared.open(URL(fileURLWithPath: logURL.path))
                }
        } else {
//            print("App log folder doesn't exist yet.")
        }
    }

    
    // MARK: - Helpers
    private func setupTableView() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "New Label Item…", action: #selector(addRow(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Table Row Actions:", action: nil, keyEquivalent: ""))

        let editAutomationMenuItem = NSMenuItem(title: "Edit Automation Details…", action: #selector(editAppItem(_:)), keyEquivalent: "")
        editAutomationMenuItem .indentationLevel = 1
        menu.addItem(editAutomationMenuItem)

        let deleteAutomationMenuItem = NSMenuItem(title: "Delete Label Item…", action: #selector(removeRow(_:)), keyEquivalent: "")
        deleteAutomationMenuItem .indentationLevel = 1
        menu.addItem(deleteAutomationMenuItem)

        tableView.menu = menu

        tableView.target = self
        tableView.doubleAction = #selector(handleTableViewDoubleClick(_:))
    }

    @objc private func handleTableViewDoubleClick(_ sender: Any?) {
        guard tableView.selectedRow >= 0 else { return }
        
        // Get the current event to check for modifier keys
//        if let event = NSApp.currentEvent {
//            if event.modifierFlags.contains(.shift) {
//                editPrePostScripts(self)
//            } else if event.modifierFlags.contains(.option) {
//                editGroupAssignments(self)
//            } else {
//                editAppItem(self)
//            }
//        }
        
        editAppItem(self)
    }

    
    private func registerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(mainWindowDidLoad(_:)), name: .mainWindowDidLoad, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(labelWindowWillClose(_:)), name: .labelWindowWillClose, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(handleNewDirectoryAdded(_:)), name: .newDirectoryAdded, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(handleLabelEditCompleted(_:)), name: .labelEditCompleted, object: nil)
    }

    private func configureInitialState() {
        editButton.isEnabled = false
        removeButton.isEnabled = false
    }

    private func refreshUI() {
        tableView.reloadData()
        configureInitialState()
    }
    
    private func setLabelCount() {
        let allLabels = appData.count
        let visibleLabels = filteredAppData.count
        labelCountField.stringValue = "\(visibleLabels) of \(allLabels)"
    }

    
    func iconForFileExtension(_ fileExtension: String) -> NSImage? {
        if let utType = UTType(filenameExtension: fileExtension) {
            return NSWorkspace.shared.icon(for: utType)
        }
        return nil
    }
    
    func iconForApp(bundleIdentifier: String) -> NSImage? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }

    
    func iconForItemType(_ itemType: String, _ deliveryType: Int) -> NSImage? {
        if ["pkg", "pkgInDmg", "pkgInZip", "pkgInDmgInZip"].contains(itemType) {
            if deliveryType == 1 {
                return iconForFileExtension("pkg")
            } else if deliveryType == 2 {
                if let cpIconPath = Bundle.main.path(forResource: "CP", ofType: "png"),
                    let icon = NSImage(contentsOfFile: cpIconPath) {
                    return icon
                }
                return iconForApp(bundleIdentifier: "com.microsoft.CompanyPortalMac")
            } else {
                return iconForFileExtension("pkg")
            }
        } else if ["dmg", "zip", "tbz", "appInDmgInZip"].contains(itemType) {
            if deliveryType == 0 {
                return iconForFileExtension("dmg")
            } else if deliveryType == 1 {
                return iconForFileExtension("pkg")
            }
            else {
                return iconForFileExtension("dmg")
            }
        } else {
            return NSImage(named: NSImage.cautionName)
        }
    }
    
    
    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Permissions Missing"
        alert.informativeText = """
        This application does not have the required permissions to retrieve detected applications.
        
        Please ensure that the enterprise application has been assigned the following Microsoft Graph API permissions:

        - DeviceManagementManagedDevices.Read.All
        - DeviceManagementManagedDevices.ReadWrite.All (optional, if editing is needed)

        After granting permissions, an admin must consent to them in Entra ID.
        """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Reads CFBundleShortVersionString and CFBundleVersion from Info.plist
    private func formattedAppVersion() -> String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber  = info?["CFBundleVersion"]            as? String ?? "?"
        return "v\(shortVersion) (build \(buildNumber))"
    }


    // MARK: - Notifications
    @objc func mainWindowDidLoad(_ notification: Notification) {
        progressSpinner.startAnimation(self)
        statusLabel.isHidden = false
        loadAppData()
    }

    @objc func labelWindowWillClose(_ notification: Notification) {
        guard let editedLabel = notification.userInfo?["labelInfo"] as? String else { return }
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 {
            var editedAppInfo = filteredAppData[selectedRow]
            editedAppInfo.label = editedLabel
            filteredAppData[selectedRow] = editedAppInfo
            refreshUI()
        }
    }

    @IBAction func showAboutWindow(_ sender: Any) {
        // Show About
//        print("showAboutWindow")
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let aboutWindowVC = storyboard.instantiateController(withIdentifier: "AboutViewController") as? AboutViewController else {
            return
        }
        presentAsModalWindow(aboutWindowVC)
    }

    
    
    
    // MARK: - Validation Cache Management
    func invalidateValidationCache() {
        validationCache.removeAll()
//        print("Validation cache cleared.")
    }
    
    func invalidateValidationCache(for folderPath: String) {
        validationCache.removeValue(forKey: folderPath)
//        print("Validation cache invalidated for folder: \(folderPath)")
    }



    // MARK: - Data Handling
    func loadAppData() {
        
        Task {
            do {
                XPCManager.shared.scanAllInstallomatorManagedLabels() { success in
                    if let success = success {
                        if success {
//                            Logger.logUser("Scan completed successfully.", logType: "MainViewController")
                            DispatchQueue.main.async {
                                self.progressSpinner.stopAnimation(self)
                                self.statusLabel.isHidden = true
                                self.tableView.reloadData()
                                self.setLabelCount()
                            }
                        }
                    }
                }

                
                
                let directoryContents = try FileManager.default.contentsOfDirectory(
                    at: URL(fileURLWithPath: AppConstants.intuneomatorManagedTitlesFolderURL.path),
                    includingPropertiesForKeys: nil
                )
                let subdirectories = directoryContents.filter { $0.hasDirectoryPath }
                
                // Run scripts and load plist files concurrently
                await withTaskGroup(of: AppInfo?.self) { taskGroup in
                    for subdir in subdirectories {
//                        print("Loading \(subdir)")
                        taskGroup.addTask {
                            return await self.processSubdirectory(subdir)
                        }
                    }

                    var loadedAppData: [AppInfo] = []
                    for await appInfo in taskGroup {
                        if let appInfo = appInfo {
                            loadedAppData.append(appInfo)
                        }
                    }
                    DispatchQueue.main.async {
                        self.appData = loadedAppData.sorted(by: { $0.name < $1.name })
                        self.filteredAppData = loadedAppData.sorted(by: { $0.name < $1.name })
                    }
                }
            } catch {
//                print("Error loading app data: \(error)")
            }
        }
        
    }

    func controlTextDidChange(_ obj: Notification) {
        let query = appSearchField.stringValue
        filteredAppData = query.isEmpty
            ? appData
            : appData.filter { $0.label.localizedCaseInsensitiveContains(query) }
        tableView.reloadData()
        setLabelCount()
    }


    private func processSubdirectory(_ subdir: URL) async -> AppInfo? {
        let directoryName = subdir.lastPathComponent
        
        // Declare variables
        var name: String?
        
        let parts = directoryName.split(separator: "_")

        if parts.count == 2 {
            name = String(parts[0]) // Assign the name
        } else {
//            print("Invalid directory format.")
        }

        let plistPath = subdir.appendingPathComponent("\(name!).plist")

        // Load plist file
        if FileManager.default.fileExists(atPath: plistPath.path) {
            do {
                let plistData = try Data(contentsOf: plistPath)
                let plistDictionary = try PropertyListSerialization.propertyList(
                    from: plistData,
                    options: [],
                    format: nil
                ) as! [String: Any]

                return AppInfo(
                    CLIArguments: plistDictionary["CLIArguments"] as? String ?? "",
                    CLIInstaller: plistDictionary["CLIInstaller"] as? String ?? "",
                    appName: plistDictionary["appName"] as? String ?? "",
                    appNewVersion: plistDictionary["appNewVersion"] as? String ?? "",
                    archiveName: plistDictionary["archiveName"] as? String ?? "",
                    blockingProcesses: plistDictionary["blockingProcesses"] as? String ?? "",
                    curlOptions: plistDictionary["curlOptions"] as? String ?? "",
                    downloadFile: plistDictionary["downloadFile"] as? String ?? "",
                    downloadURL: plistDictionary["downloadURL"] as? String ?? "",
                    expectedTeamID: plistDictionary["expectedTeamID"] as? String ?? "",
                    guid: plistDictionary["guid"] as? String ?? "",
                    installerTool: plistDictionary["installerTool"] as? String ?? "",
                    label: plistDictionary["label"] as? String ?? "",
                    labelIcon: plistDictionary["labelIcon"] as? String ?? "",
                    name: plistDictionary["name"] as? String ?? directoryName,
                    packageID: plistDictionary["packageID"] as? String ?? "",
                    pkgName: plistDictionary["pkgName"] as? String ?? "",
                    targetDir: plistDictionary["targetDir"] as? String ?? "",
                    transformToPkg: plistDictionary["asPkg"]as? Bool ?? false,
                    type: plistDictionary["type"] as? String ?? "",
                    versionKey: plistDictionary["versionKey"] as? String ?? ""
                )
            } catch {
//                print("Error loading plist for \(directoryName): \(error)")
            }
        } else {
//            print("Plist file not found for directory: \(directoryName)")
        }

        return nil
    }


//    private func runZshScriptAsync(withLabelPath labelPath: String) async throws -> String {
//        guard let scriptPath = Bundle.main.path(forResource: "process_label", ofType: "sh") else {
//            throw NSError(domain: "Script not found in app bundle", code: 1)
//        }
//
//        return try await withCheckedThrowingContinuation { continuation in
//            let process = Process()
//            let pipe = Pipe()
//
//            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
//            process.arguments = [scriptPath, labelPath]  // Pass the directory's .sh file as an argument
//            process.standardOutput = pipe
//            process.standardError = pipe
//
//            process.terminationHandler = { _ in
//                let data = pipe.fileHandleForReading.readDataToEndOfFile()
//                if let output = String(data: data, encoding: .utf8) {
//                    continuation.resume(returning: output)
//                } else {
//                    continuation.resume(throwing: NSError(domain: "Failed to read script output", code: 2))
//                }
//            }
//
//            do {
//                try process.run()
//            } catch {
//                continuation.resume(throwing: error)
//            }
//        }
//    }
//
    
    @objc private func handleLabelEditCompleted(_ notification: Notification) {
//        print ("handleLabelEditCompleted")
        
        // Recheck label automation status after editing
        let editedLabel = notification.userInfo?["label"] as? String ?? ""
        let editedGUID = notification.userInfo?["guid"] as? String ?? ""
        let editedLabelPath = AppConstants.intuneomatorManagedTitlesFolderURL.appendingPathComponent("\(editedLabel)_\(editedGUID)")
            .path
            .removingPercentEncoding!
        invalidateValidationCache(for: editedLabelPath)

        // Update the cached status after invalidating the existing
        let isValid: Bool
        isValid = AutomationCheck.validateFolder(at: editedLabelPath)
        validationCache[editedLabelPath] = isValid
        tableView.reloadData()
        
    }
    
    @objc private func handleNewDirectoryAdded(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let directoryPath = userInfo["directoryPath"] as? String else {
//            print("No directoryPath found in notification")
            return
        }

        let directoryURL = URL(fileURLWithPath: directoryPath)

        Task {
            if let newAppInfo = await processSubdirectory(directoryURL) {
                DispatchQueue.main.async {
                    self.appData.append(newAppInfo)
                    self.appData.sort(by: { $0.name < $1.name })
                    self.filteredAppData.append(newAppInfo)
                    self.filteredAppData.sort(by: { $0.name < $1.name })
                    self.tableView.reloadData()
//                    print("New directory processed and added to table view.")
                    
                    self.invalidateValidationCache()
                }
            }
        }
    }
    
}


// MARK: - Table View
extension MainViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
//        print("Number of rows: \(appData.count)")
        return filteredAppData.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filteredAppData[row]

        guard let columnIdentifier = tableColumn?.identifier.rawValue else { return nil }

        // Ensure the cell view exists
        guard let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as? NSTableCellView else {
//            print("Failed to create cell for column: \(columnIdentifier)")
            return nil
        }

        // Construct the folder path for validation
        let baseURL = AppConstants.intuneomatorManagedTitlesFolderURL
        let folderURL = baseURL
            .appendingPathComponent("\(item.label)_\(item.guid)")
        // Icon for label automation title
        let labelIconURL = folderURL.appendingPathComponent("\(item.label).png")
        
        var metadata: Metadata!
        // Load metadata.json
        let labelMetaDataURL = folderURL
            .appendingPathComponent("metadata.json")
        do {
            let data = try Data(contentsOf: labelMetaDataURL)
            metadata = try JSONDecoder().decode(Metadata.self, from: data)
        } catch {
//            print("Could not load metadata")
        }
        
        // determine Arch string
        var archString: String = ""
        var deployAsArch = 0
        if titleIsDualPlatform(forTable: row) {
            deployAsArch = metadata.deployAsArchTag

            if deployAsArch == 0 {
                archString = "arm64"
            } else if metadata.deployAsArchTag == 1 {
                archString = "i386"
            } else {
                archString = "Universal"
            }
            
        } else {
            archString = "Universal"
        }

        let deploymentType = metadata.deploymentTypeTag
        

        // Check the cache first
        let isValid: Bool
        if let cachedResult = validationCache[folderURL.path] {
            isValid = cachedResult
        } else {
            // Perform validation and cache the result
            isValid = AutomationCheck.validateFolder(at: folderURL.path)
            validationCache[folderURL.path] = isValid
        }
        var readyState: String?
        var iconImage: NSImage!
        // Load the appropriate icon based on validation
        if isValid {
            readyState = String("Ready for Automation")
            iconImage = AutomationStatusImage.Ready.image
        }
        else {
            readyState = String("Not Ready for Automation")
            iconImage = AutomationStatusImage.NotReady.image
        }

        switch columnIdentifier {
        case "ValidationColumn":
            if let icon = iconImage {
                cell.imageView?.image = icon
                cell.toolTip = readyState
            } else {
//                print("Failed to load icon for validation result")
            }
        case "IconColumn":
            // Load the icon
            if let icon = NSImage(contentsOfFile: labelIconURL.path) {
//                print("Icon loaded for path: \(item.labelIcon)")
                cell.imageView?.image = icon
                cell.toolTip = "\(URL(fileURLWithPath: item.labelIcon).lastPathComponent)"
            } else {
//                print("Failed to load icon for path: \(item.labelIcon)")
                let fallbackIconPath = Bundle.main.path(forResource: "app_icon", ofType: "png") ?? ""
                cell.imageView?.image = NSImage(contentsOfFile: fallbackIconPath)
                cell.toolTip = "Failed to load icon"
            }
        case "NameColumn":
            cell.textField?.stringValue = item.name
            cell.toolTip = readyState
        case "ArchColumn":
            cell.textField?.stringValue = archString
            cell.toolTip = readyState
        case "DeliveryColumn":
            cell.imageView?.image = iconForItemType(item.type, deploymentType)
        case "LabelColumn":
            cell.textField?.stringValue = item.label
            cell.toolTip = "Tracking ID: \(item.guid)"
        case "SourceColumn":
            cell.textField?.stringValue = item.type
            cell.toolTip = item.downloadURL
        case "TeamIDColumn":
            cell.textField?.stringValue = item.expectedTeamID
        default:
            cell.textField?.stringValue = ""
        }

        return cell
    }

    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let hasSelection = tableView.selectedRow >= 0
        editButton.isEnabled = hasSelection
        removeButton.isEnabled = hasSelection
    }
    
    private func titleIsDualPlatform(forTable row: Int) -> Bool {
        
        let label = filteredAppData[row].label
        let guid = filteredAppData[row].guid
        
        let labelX86PlistPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(label)_\(guid)", isDirectory: true)
            .appendingPathComponent("\(label)_i386.plist", isDirectory: true)
        
        let labelPlistPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(label)_\(guid)", isDirectory: true)
            .appendingPathComponent("\(label).plist", isDirectory: true)
        
        return FileManager.default.fileExists(atPath: labelX86PlistPath.path) &&
        FileManager.default.fileExists(atPath: labelPlistPath.path)
    }

    // MARK: - Handle Keyboard Input
    override func keyDown(with event: NSEvent) {
        guard let characters = event.characters else { return }

        // Check if the Escape key was pressed
        if event.keyCode == 53 { // 53 is the key code for Escape
            // Pass the event to the next responder (e.g., default behavior)
            super.keyDown(with: event)
            return
        }

        // Append to the search buffer
        searchBuffer += characters.lowercased()

        // Invalidate any existing timer
        searchTimer?.invalidate()

        // Set a timer to clear the buffer after a short delay
        searchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.searchBuffer = ""
        }

        // Search for a matching row
        if let index = appData.firstIndex(where: { $0.name.hasPrefix(searchBuffer) }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            tableView.scrollRowToVisible(index)
        }
    }

}
