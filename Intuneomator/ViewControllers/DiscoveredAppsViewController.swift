//
//  DiscoveredAppsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/28/25.
//

import Cocoa

/**
 View controller for discovering and automating applications detected in Microsoft Intune.
 
 This controller fetches applications discovered on managed devices and matches them with
 available Installomator labels for automated packaging and deployment.
 
 **Key Features:**
 - Fetches discovered macOS applications from Microsoft Intune
 - Matches discovered apps with 700+ Installomator labels
 - Provides filtering for apps with available automation labels
 - Supports search functionality across app names and labels
 - Enables automated label creation and preview functionality
 - Shows device lists for selected applications
 - Handles duplicate label entries for apps with multiple matching labels
 */
class DiscoveredAppsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {

    // MARK: - UI Outlets
    
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

    /// Progress label shown while fetching discovered apps.
    @IBOutlet weak var progressLabel: NSTextField!

    // MARK: - Properties
    
    /// Array of all discovered applications retrieved from Intune
    var allApps: [DetectedApp] = []
    
    /// Array of applications after applying filter and duplication logic
    var filteredApps: [DetectedApp] = []
    
    /// Dictionary mapping application names to arrays of matching Installomator label names
    var installomatorMappings: [String: [String]] = [:]
    
    /// Stores the initial count of filtered apps before duplicates are generated
    var initialFilteredAppsCount: Int = 0
    
    /// HelpPopover for displaying contextual help in this view
    private let helpPopover = HelpPopover()

    // MARK: - View Lifecycle
    
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

    override func viewDidAppear() {
        super.viewDidAppear()
        progressIndicator.startAnimation(nil)
        progressLabel.isHidden = false
        if allApps.isEmpty {
            fetchDetectedApps()
        } else {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - Data Fetching & Processing
    
    /// Fetches detected macOS applications from Intune via XPC and updates the table
    func fetchDetectedApps() {
        Task {
            do {
                XPCManager.shared.fetchDiscoveredMacApps { apps in
                    DispatchQueue.main.async {
                        if let apps = apps {
                            DispatchQueue.main.async {
                                self.allApps = apps
                                self.filteredApps = apps
                                
                                self.applyFilter()
                                self.initialFilteredAppsCount = self.filteredApps.count
                                
                                self.tableView?.reloadData()
                                self.updateLabelShowCount()
                                self.progressIndicator.stopAnimation(nil)
                                self.progressLabel.isHidden = true
                            }
                        } else {
                            // handle error
                        }
                    }
                }
            }
        }
    }
    
    /// Reads all Installomator label scripts from disk to build mappings of app names to label names
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
                        installomatorMappings[nameMatch] = []
                    }
                    installomatorMappings[nameMatch]?.append(labelName)
                }

                if let appNameMatch = extractValue(from: content, using: #"appName="([^"]+)""#) {
                    let appNameWithoutExtension = appNameMatch.replacingOccurrences(of: ".app", with: "")
                    if installomatorMappings[appNameWithoutExtension] == nil {
                        installomatorMappings[appNameWithoutExtension] = []
                    }
                    installomatorMappings[appNameWithoutExtension]?.append(labelName)
                }
            }
        } catch {
            // Handle error silently
        }
    }
    
    // MARK: - Helper Methods
    
    /// Extracts a value from the given text using a regular expression pattern
    private func extractValue(from text: String, using pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        } catch {
            // Handle regex error silently
        }
        return nil
    }
    
    /// Returns matching Installomator label names for the given application name
    func getInstallomatorMatches(for appName: String?) -> [String] {
        guard let appName = appName else { return [] }
        let matches = installomatorMappings[appName] ?? []
        return matches.isEmpty ? ["No match detected"] : matches
    }
    
    /// Applies filtering and duplication logic to `allApps` based on the checkbox and search query
    func applyFilter() {
        buttonAutomateLabel.isEnabled = false
        buttonPreviewLabel.isEnabled = false

        let shouldFilterMatches = (checkboxFilterMatched.state == .on)
        let searchQuery = searchField.stringValue.lowercased()

        var tempFilteredApps: [DetectedApp] = []

        for app in allApps {
            let matchingLabels = getInstallomatorMatches(for: app.displayName)

            if shouldFilterMatches {
                if !matchingLabels.isEmpty && !matchingLabels.contains("No match detected") {
                    for label in matchingLabels {
                        tempFilteredApps.append(app.withLabel(label))
                    }
                }
            } else {
                if matchingLabels.isEmpty {
                    tempFilteredApps.append(app.withLabel("No match detected"))
                } else {
                    for label in matchingLabels {
                        tempFilteredApps.append(app.withLabel(label))
                    }
                }
            }
        }

        // Apply search filter after checkbox filtering
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
    
    /// Updates the `labelShowCount` text with the number of visible rows and initial count
    func updateLabelShowCount() {
        labelShowCount.stringValue = "\(filteredApps.count) of \(initialFilteredAppsCount)"
    }
    
    // MARK: - Actions
    
    /// Initiates automation for the selected label
    @IBAction func saveNewContent(_ sender: NSButton) {
        guard tableView.selectedRow >= 0 else {
            return
        }
        progressIndicator.startAnimation(nil)
        progressLabel.isHidden = false
        let selectedApp = filteredApps[tableView.selectedRow]
        let labelName = selectedApp.installomatorLabel
        
        XPCManager.shared.addNewLabel(labelName, "installomator") { dirPath in
            DispatchQueue.main.async {
                if dirPath != nil {
                    self.progressIndicator.stopAnimation(nil)
                    self.progressLabel.isHidden = true
                    NotificationCenter.default.post(
                        name: .newDirectoryAdded,
                        object: nil,
                        userInfo: ["directoryPath": dirPath!]
                    )
                } else {
                    self.progressIndicator.stopAnimation(nil)
                    self.progressLabel.isHidden = true
                }
            }
        }

        showSuccessDialog(message: "Label \(labelName) successfully automated!\n\nComplete the setup in the Main window.")
    }
    
    /// Shows a popover containing the selected label's script contents
    @IBAction func previewLabelContents(_ sender: NSButton) {
        guard tableView.selectedRow >= 0 else { return }

        let selectedApp = filteredApps[tableView.selectedRow]
        let labelName = selectedApp.installomatorLabel
        let labelPath = (AppConstants.installomatorLabelsFolderURL.path as NSString).appendingPathComponent("\(labelName).sh")

        do {
            let labelContents = try String(contentsOfFile: labelPath, encoding: .utf8)
            showPopover(with: labelContents, atRow: tableView.selectedRow)
        } catch {
            // Handle error silently
        }
    }
    
    /// Fetches and displays a sheet of devices where the selected app is detected
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
                                self.showDevicesSheet(for: selectedApp.displayName ?? "Unknown App", labelName: selectedApp.installomatorLabel, devices: devices)
                            }
                        } else {
                            // show an error or empty state
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func searchFieldChanged(_ sender: NSSearchField) {
        applyFilter()
    }
    
    @IBAction func toggleFilterMatchedApps(_ sender: NSButton) {
        applyFilter()
    }
    
    @objc private func handleTableViewDoubleClick(_ sender: Any?) {
        guard tableView.selectedRow >= 0 else { return }
        viewDevicesForSelectedApp(buttonViewDevices)
    }
    
    // MARK: - Dialog Methods
    
    func showSuccessDialog(message: String) {
        let alert = NSAlert()
        alert.messageText = "Success"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showErrorDialog(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showDevicesSheet(for appName: String, labelName appLabelName: String, devices: [DeviceInfo]) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let sheetController = storyboard.instantiateController(withIdentifier: "DevicesSheetViewController") as? DevicesSheetViewController else {
            return
        }
        
        sheetController.appName = appName
        sheetController.devices = devices
        sheetController.appLabelName = appLabelName

        self.presentAsSheet(sheetController)
    }
    
    func showPopover(with text: String, atRow row: Int) {
        let popover = NSPopover()
        popover.behavior = .transient

        let popoverVC = NSViewController()
        
        // Create a scroll view
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 530, height: 380))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        // Create the text view with padding
        let textView = NSTextView(frame: NSRect(x: 15, y: 15, width: 500, height: 350))
        textView.isEditable = false
        textView.string = text
        textView.textContainerInset = NSSize(width: 15, height: 15)

        scrollView.documentView = textView
        popoverVC.view = scrollView
        popover.contentViewController = popoverVC
        popover.contentSize = scrollView.frame.size

        if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) {
            popover.show(relativeTo: rowView.bounds, of: rowView, preferredEdge: .maxY)
        }
    }
    
    // MARK: - NSTableView DataSource & Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredApps.count
    }
    
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
                cell.textField?.stringValue = app.installomatorLabel
                default:
                    break
            }
            return cell
        }
        return nil
    }
    
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
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }

        let key = sortDescriptor.key ?? ""
        let ascending = sortDescriptor.ascending

        filteredApps.sort {
            // Special handling for deviceCount to sort numerically
            if key == "deviceCount" {
                let firstValue = $0.deviceCount ?? 0
                let secondValue = $1.deviceCount ?? 0
                return ascending ? (firstValue < secondValue) : (firstValue > secondValue)
            } else {
                let firstValue = getSortableValue(for: $0, key: key)
                let secondValue = getSortableValue(for: $1, key: key)
                return ascending ? (firstValue < secondValue) : (firstValue > secondValue)
            }
        }
        
        tableView.reloadData()
    }
    
    private func getSortableValue(for app: DetectedApp, key: String) -> String {
        switch key {
        case "displayName":
            return app.displayName ?? ""
        case "version":
            return app.version ?? ""
        case "publisher":
            return app.publisher ?? ""
        case "deviceCount":
            return String(app.deviceCount ?? 0)
        case "installomatorLabel":
            return app.installomatorLabel
        default:
            return ""
        }
    }
}
