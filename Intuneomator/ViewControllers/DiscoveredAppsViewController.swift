//
///
///  DiscoveredAppsViewController.swift
///  Intuneomator
///
///  View controller for discovering and automating applications detected in Microsoft Intune.
///  Fetches applications discovered on managed devices and matches them with available Installomator labels
///  for automated packaging and deployment.
///
///  **Key Features:**
///  - Fetches discovered macOS applications from Microsoft Intune
///  - Matches discovered apps with 700+ Installomator labels
///  - Provides filtering for apps with available automation labels
///  - Supports search functionality across app names and labels
///  - Enables automated label creation and preview functionality
///  - Shows device lists for selected applications
///  - Handles duplicate label entries for apps with multiple matching labels
///
//  DiscoveredAppsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/28/25.
//

import Cocoa

/// `DiscoveredAppsViewController` manages the UI for displaying discovered macOS applications
/// and their matching Installomator labels. It handles fetching app data, filtering/search,
/// automating labels, previewing scripts, and viewing devices.
class DiscoveredAppsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {


    /// Table view displaying the list of discovered applications.
    @IBOutlet weak var tableView: NSTableView!

    /// Search field to filter displayed applications by name or label.
    @IBOutlet weak var searchField: NSSearchField!

    /// Checkbox to toggle filtering only apps with matching Installomator labels.
    @IBOutlet weak var checkboxFilterMatched: NSButton!

    /// Label showing the count of visible rows versus the original filtered count.
    @IBOutlet weak var labelShowCount: NSTextField!

    /// Button to initiate automated creation of the selected Installomator label.
    @IBOutlet weak var buttonAutomateLabel: NSButton!

    /// Button to preview the contents of the selected label’s script.
    @IBOutlet weak var buttonPreviewLabel: NSButton!

    /// Button to display a list of devices where the selected app is detected.
    @IBOutlet weak var buttonViewDevices: NSButton!

    /// Progress indicator shown while fetching discovered apps.
    @IBOutlet weak var progressIndicator: NSProgressIndicator!


    /// Array of all discovered applications retrieved from Intune.
    var allApps: [DetectedApp] = []
    /// Array of applications after applying filter and duplication logic.
    var filteredApps: [DetectedApp] = []
    /// Dictionary mapping application names to arrays of matching Installomator label names.
    var installomatorMappings: [String: [String]] = [:] // Maps app names to multiple labels

    /// Stores the initial count of filtered apps before duplicates are generated.
    var initialFilteredAppsCount: Int = 0

    /// HelpPopover for displaying contextual help in this view.
    private let helpPopover = HelpPopover()

    
    /// Called after the view has been loaded.
    /// - Initializes Installomator label mappings and configures table view behaviors.
    override func viewDidLoad() {
        super.viewDidLoad()
        loadInstallomatorLabels()
        
        buttonAutomateLabel.isEnabled = false
        buttonPreviewLabel.isEnabled = false
        buttonViewDevices.isEnabled = false

        if let publisherColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("publisher")) {
            tableView.removeTableColumn(publisherColumn)
        }
        
        tableView.target = self
        tableView.doubleAction = #selector(handleTableViewDoubleClick(_:))

    }

    /// Called when the view appears onscreen.
    /// - Starts the progress indicator and triggers fetching of discovered apps if needed.
    override func viewDidAppear() {
        super.viewDidAppear()
        progressIndicator.startAnimation(nil)
        if allApps.isEmpty {
            fetchDetectedApps()
        } else {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    /// Fetches detected macOS applications from Intune via XPC and updates the table.
    /// - Retrieves apps asynchronously, applies filters, updates counts, and reloads the table.
    func fetchDetectedApps() {
        Task {
            do {
                
                XPCManager.shared.fetchDiscoveredMacApps { apps in
                    DispatchQueue.main.async {
                        if let apps = apps {
                            DispatchQueue.main.async {
                                self.allApps = apps
                                self.filteredApps = apps
                                
                                self.applyFilter() // ✅ First, apply filtering and duplication logic
                                
                                self.initialFilteredAppsCount = self.filteredApps.count // ✅ Store count after duplicates are created
//                                print("✅ Initial filtered apps count set to: \(self.initialFilteredAppsCount)")
                                
                                self.tableView?.reloadData()
                                self.updateLabelShowCount() // ✅ Update the label count
                                self.progressIndicator.stopAnimation(nil)
                            }
                            
                        } else {
                            // handle error
                        }
                    }
                }
            }
        }
    }
    
    /// Reads all Installomator label scripts from disk to build mappings of app names to label names.
    /// - Parses script files to extract `name` and `appName` fields for matching.
    func loadInstallomatorLabels() {
        let labelDirectory = URL(fileURLWithPath: AppConstants.installomatorLabelsFolderURL.path)

        do {
            let files = try FileManager.default.contentsOfDirectory(at: labelDirectory, includingPropertiesForKeys: nil)
            let shellFiles = files.filter { $0.pathExtension == "sh" }

            for file in shellFiles {
                let content = try String(contentsOf: file, encoding: .utf8)
                let labelName = file.deletingPathExtension().lastPathComponent

                if let nameMatch = extractValue(from: content, using: #"name="([^"]+)""#) {
                    if installomatorMappings[nameMatch] == nil {
                        installomatorMappings[nameMatch] = []  // ✅ Ensure it's an array
                    }
                    installomatorMappings[nameMatch]?.append(labelName)
                }

                if let appNameMatch = extractValue(from: content, using: #"appName="([^"]+)""#) {
                    let appNameWithoutExtension = appNameMatch.replacingOccurrences(of: ".app", with: "")
                    if installomatorMappings[appNameWithoutExtension] == nil {
                        installomatorMappings[appNameWithoutExtension] = []  // ✅ Ensure it's an array
                    }
                    installomatorMappings[appNameWithoutExtension]?.append(labelName)
                }
            }
        } catch {
//            print("❌ Error reading Installomator labels: \(error)")
        }
    }
    
    /// Extracts a value from the given text using a regular expression pattern.
    /// - Parameters:
    ///   - text: The source string to search.
    ///   - pattern: The regular expression with a capture group for the desired value.
    /// - Returns: The first captured substring, or nil if no match is found.
    private func extractValue(from text: String, using pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        } catch {
//            print("Regex error: \(error)")
        }
        return nil
    }
    
    /// Returns matching Installomator label names for the given application name.
    /// - Parameter appName: The application display name.
    /// - Returns: Array of label names, or ["No match detected"] if none found.
    func getInstallomatorMatches(for appName: String?) -> [String] {
        guard let appName = appName else { return [] }

        let matches = installomatorMappings[appName] ?? []

//        print("🔍 Matches for \(appName): \(matches)") // Debugging output

        return matches.isEmpty ? ["No match detected"] : matches
    }
    
    /// Applies filtering and duplication logic to `allApps` based on the checkbox and search query.
    /// - Duplicates rows for apps with multiple labels, then filters by search text.
    /// - Updates `filteredApps` and the count label, then reloads the table view.
    func applyFilter() {
        buttonAutomateLabel.isEnabled = false
        buttonPreviewLabel.isEnabled = false

        let shouldFilterMatches = (checkboxFilterMatched.state == .on)
        let searchQuery = searchField.stringValue.lowercased()

        var tempFilteredApps: [DetectedApp] = []

        for app in allApps {
            let matchingLabels = getInstallomatorMatches(for: app.displayName)

            if shouldFilterMatches {
                // ✅ Only add apps that have at least one matching Installomator label
                if !matchingLabels.isEmpty && !matchingLabels.contains("No match detected") {
                    for label in matchingLabels {
                        tempFilteredApps.append(app.withLabel(label))
                    }
                }
            } else {
                // ✅ Keep all apps, but still duplicate rows for multiple labels
                if matchingLabels.isEmpty {
                    tempFilteredApps.append(app.withLabel("No match detected"))
                } else {
                    for label in matchingLabels {
                        tempFilteredApps.append(app.withLabel(label))
                    }
                }
            }
        }

//        print("🛠 Final filtered apps count: \(tempFilteredApps.count) (should be higher if multiple labels exist)")

        // ✅ Apply search filter after checkbox filtering
        if !searchQuery.isEmpty {
            tempFilteredApps = tempFilteredApps.filter { app in
                let displayName = app.displayName?.lowercased() ?? ""
                let installomatorMatch = app.installomatorLabel.lowercased()
                return displayName.contains(searchQuery) || installomatorMatch.contains(searchQuery)
            }
        }

        filteredApps = tempFilteredApps
        updateLabelShowCount()
        tableView.reloadData()
    }
    
    /// Updates the `labelShowCount` text with the number of visible rows and initial count.
    func updateLabelShowCount() {
        labelShowCount.stringValue = "\(filteredApps.count) of \(initialFilteredAppsCount)"
    }
    
    // MARK: - Actions

    /// Initiates automation for the selected label.
    /// - Sends the label name to the XPC service for adding to managed titles.
    /// - Displays a success dialog upon completion.
    @IBAction func saveNewContent(_ sender: NSButton) {
        guard tableView.selectedRow >= 0 else {
//            print("❌ No row selected.")
            return
        }
        progressIndicator.startAnimation(nil)

        let selectedApp = filteredApps[tableView.selectedRow]
        let labelName = selectedApp.installomatorLabel
        
        // Send the new content to the XPC service
        XPCManager.shared.addNewLabel(labelName, "installomator") { dirPath in
            DispatchQueue.main.async {
                if dirPath != nil {
                    // stop the progress indicator
                    self.progressIndicator.stopAnimation(nil)
                    
                    // Notify MainViewController of the new directory
                    NotificationCenter.default.post(
                        name: .newDirectoryAdded,
                        object: nil,
                        userInfo: ["directoryPath": dirPath!]
                    )

                } else {
                    // stop the progress indicator
                    self.progressIndicator.stopAnimation(nil)
//                    print("Failed to update label content")
                }
            }
        }

        showSuccessDialog(message: "Label \(labelName) successfully automated!\n\nComplete the setup in the Main window.")

    }

    
    /// Shows a popover containing the selected label’s script contents.
    /// - Reads the `.sh` file for the label and displays its contents.
    @IBAction func previewLabelContents(_ sender: NSButton) {
        guard tableView.selectedRow >= 0 else { return }

        let selectedApp = filteredApps[tableView.selectedRow]
        let labelName = selectedApp.installomatorLabel
        let labelPath = (AppConstants.installomatorLabelsFolderURL.path as NSString).appendingPathComponent("\(labelName).sh")

        do {
            let labelContents = try String(contentsOfFile: labelPath, encoding: .utf8)
            showPopover(with: labelContents, atRow: tableView.selectedRow)
        } catch {
//            print("❌ Failed to read label file \(labelName).sh: \(error)")
        }
    }
    
    /// Fetches and displays a sheet of devices where the selected app is detected.
    /// - Uses XPC to retrieve a list of `DeviceInfo` for the given app ID.
    @IBAction func viewDevicesForSelectedApp(_ sender: NSButton) {
        guard tableView.selectedRow >= 0 else { return }

        let selectedApp = filteredApps[tableView.selectedRow]
        guard let appID = selectedApp.id else {
            showErrorDialog(message: "No ID found for selected app.")
            return
        }

        Task {
            do {
                XPCManager.shared.fetchDevices(forAppID: appID) { devices in
                    DispatchQueue.main.async {
                        if let devices = devices {
                            DispatchQueue.main.async {
                                self.showDevicesSheet(for: selectedApp.displayName ?? "Unknown App", devices: devices)
                            }
                        } else {
                            // show an error or empty state
                        }
                    }
                }
            }
        }
    }
    
    /// Displays an informational success alert with the given message.
    func showSuccessDialog(message: String) {
        let alert = NSAlert()
        alert.messageText = "Success"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Displays a critical error alert with the given message.
    func showErrorDialog(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Presents a sheet showing the list of devices for the specified application.
    /// - Parameters:
    ///   - appName: The name of the application.
    ///   - devices: Array of `DeviceInfo` objects to display.
    func showDevicesSheet(for appName: String, devices: [DeviceInfo]) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let sheetController = storyboard.instantiateController(withIdentifier: "DevicesSheetViewController") as? DevicesSheetViewController else {
//            print("❌ Failed to instantiate DevicesSheetViewController")
            return
        }
        
        sheetController.appName = appName
        sheetController.devices = devices

        self.presentAsSheet(sheetController)
    }
    
    /// Displays a transient popover showing the provided text at the specified table row.
    /// - Parameters:
    ///   - text: The content to display inside the popover.
    ///   - row: The table row index to anchor the popover.
    func showPopover(with text: String, atRow row: Int) {
        let popover = NSPopover()
        popover.behavior = .transient // Dismisses when clicking outside

        let popoverVC = NSViewController()
        
        // Create a scroll view
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 530, height: 380))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        // Create the text view with padding
        let textView = NSTextView(frame: NSRect(x: 15, y: 15, width: 500, height: 350)) // Extra space for padding
        textView.isEditable = false
        textView.string = text
        textView.textContainerInset = NSSize(width: 15, height: 15) // ✅ Adds padding inside the text area

        // Assign text view to scroll view
        scrollView.documentView = textView

        // Assign scroll view to popover
        popoverVC.view = scrollView
        popover.contentViewController = popoverVC
        popover.contentSize = scrollView.frame.size

        // Determine row view to anchor the popover to
        if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) {
            popover.show(relativeTo: rowView.bounds, of: rowView, preferredEdge: .maxY)
        }
    }
    
    /// Called when the search field value changes.
    /// - Applies the filter to update displayed rows.
    @IBAction func searchFieldChanged(_ sender: NSSearchField) {
        applyFilter()
    }
    
    /// Called when the “Filter Matched” checkbox state changes.
    /// - Reapplies the filter to show only apps with matching labels if checked.
    @IBAction func toggleFilterMatchedApps(_ sender: NSButton) {
        applyFilter()
    }
    
    /// Handles double-click events on the table view.
    /// - When a row is double-clicked, performs the default action of viewing devices for that app.
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
        
        viewDevicesForSelectedApp(buttonViewDevices)
    }
    
    // MARK: - NSTableView DataSource & Delegate Methods

    /// NSTableViewDataSource: Returns the number of rows (apps) to display.
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredApps.count
    }
    
    /// NSTableViewDelegate/DataSource: Provides a configured cell view for each column and row.
    /// - Populates columns: displayName, version, publisher, deviceCount, and installomatorLabel.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnIdentifier = tableColumn?.identifier.rawValue else { return nil }
        let app = filteredApps[row]

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(columnIdentifier), owner: self) as? NSTableCellView {
            switch columnIdentifier {
                case "displayName":
                    cell.textField?.stringValue = app.displayName ?? "Unknown"
                case "version":
                    cell.textField?.stringValue = app.version ?? "N/A"
                case "publisher":
                    cell.textField?.stringValue = app.publisher ?? "Unknown"
                case "deviceCount":
                    cell.textField?.stringValue = "\(app.deviceCount ?? 0)"
                case "installomatorLabel":
                cell.textField?.stringValue = app.installomatorLabel // Now uses the label from `DetectedApp`
                default:
                    break
            }
            return cell
        }
        return nil
    }
    
    /// NSTableViewDelegate: Called when the selected table row changes.
    /// - Enables or disables action buttons based on whether the selected app has a matching label.
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow >= 0 else {
            buttonAutomateLabel.isEnabled = false
            buttonPreviewLabel.isEnabled = false
            buttonViewDevices.isEnabled = false
            return
        }

        let selectedApp = filteredApps[tableView.selectedRow]

        let match = selectedApp.installomatorLabel

        let isMatchingLabel = (match != "No match detected")

        buttonAutomateLabel.isEnabled = isMatchingLabel
        buttonPreviewLabel.isEnabled = isMatchingLabel
        buttonViewDevices.isEnabled = true
    }
    
    /// NSTableViewDelegate: Called when sort descriptors change.
    /// - Sorts `filteredApps` based on the selected column key and reloads the table.
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }

        let key = sortDescriptor.key ?? ""
        let ascending = sortDescriptor.ascending

        filteredApps.sort {
            let firstValue = getSortableValue(for: $0, key: key)
            let secondValue = getSortableValue(for: $1, key: key)
            return ascending ? (firstValue < secondValue) : (firstValue > secondValue)
        }
        
        tableView.reloadData()
    }
    
    /// Returns a sortable string for the given app based on the specified key.
    /// - Used to compare values when sorting the table.
    /// - Parameters:
    ///   - app: The `DetectedApp` object.
    ///   - key: The column identifier key to sort by.
    private func getSortableValue(for app: DetectedApp, key: String) -> String {
        switch key {
        case "displayName":
            return app.displayName ?? ""
        case "version":
            return app.version ?? ""
        case "publisher":
            return app.publisher ?? ""
        case "deviceCount":
            return String(app.deviceCount ?? 0) // Convert to String for consistent sorting
        case "installomatorLabel":
            return app.installomatorLabel // Now directly accessing the stored label
        default:
            return ""
        }
    }
    
}
