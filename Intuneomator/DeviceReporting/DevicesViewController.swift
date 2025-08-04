//
//  DevicesViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/20/25.
//

import Cocoa

class DevicesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var detailsButton: NSButton!
    @IBOutlet weak var reportButton: NSButton!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var deviceCountLabel: NSTextField!
    
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
        
    var allManagedDevices: [[String: Any]] = []
    private var filteredDevices: [[String: Any]] = []
    private var searchText: String = ""

    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(doubleClickTableRow(_:))
        
        // Set up search field
        searchField.delegate = self
        searchField.placeholderString = "Search devices..."
        
        // Initial button state

        detailsButton.isEnabled = false

        loadManagedDevices()
    }
    
    func loadManagedDevices() {
        // Show loading state
        DispatchQueue.main.async {
            self.detailsButton.isEnabled = false
            self.progressIndicator.isHidden = false
            self.progressIndicator.startAnimation(self)
        }
        
        Task {
            // Now load managed devices
            DispatchQueue.main.async {
                self.fetchAndLoadManagedDevices()
            }
        }
    }
    
    private func fetchAndLoadManagedDevices() {
        XPCManager.shared.fetchManagedDevices { managedDevices in
                DispatchQueue.main.async {
                    if let managedDevices = managedDevices {
                        Logger.info("Successfully loaded \(managedDevices.count) managed devices ", category: .core, toUserDirectory: true)
                        
                        // Sort devices alphabetically by device name
                        self.allManagedDevices = managedDevices.sorted {
                            guard let name1 = $0["deviceName"] as? String, let name2 = $1["deviceName"] as? String else { return false }
                            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
                        }
                        
                        self.filteredDevices = self.allManagedDevices
                        self.updateDeviceCount()
                        self.tableView.reloadData()

                        // Re-enable buttons based on selection
                        let selectedRow = self.tableView.selectedRow
                        let hasSelection = selectedRow >= 0 && selectedRow < self.filteredDevices.count
                        self.detailsButton.isEnabled = hasSelection
                        self.progressIndicator.isHidden = true
                        self.progressIndicator.stopAnimation(self)


                    } else {
                        Logger.error("Failed to fetch managed devices from Intune", category: .core, toUserDirectory: true)
                        self.showError(message: "Failed to load managed devices from Intune. Please check your connection and authentication.")
                        self.allManagedDevices = []
                        self.filteredDevices = []
                        self.updateDeviceCount()
                    }
                }
            }
    }

    // MARK: - Actions
    
    @IBAction func showReports(_ sender: Any?) {
        openIntuneReportsWindow(preselectedReportType: "Devices with Inventory")
    }
    
    @IBAction func showDeviceDetails(_ sender: Any?) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < filteredDevices.count else {
            showError(message: "Please select a device to view.")
            return
        }
        let device = filteredDevices[selectedRow]
        openDeviceDetailsViewAsSheet(forDevice: device)

    }
    
    func openDeviceDetailsViewAsSheet(forDevice device: [String: Any]) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("DevicesManager"), bundle: nil)
        guard let deviceDetailsViewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("DeviceDetailsViewController")) as? DeviceDetailsViewController else {
            fatalError("Failed to instantiate DeviceDetailsViewController")
        }
        deviceDetailsViewController.deviceName = device["deviceName"] as? String ?? "Unknown Device"
        deviceDetailsViewController.deviceId = device["id"] as? String ?? "Unknown Device ID"
        
        presentAsSheet(deviceDetailsViewController)
        
        
    }
    
    // MARK: - Double Click Table
    @objc func doubleClickTableRow(_ sender: AnyObject) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < filteredDevices.count else { return }
        let device = filteredDevices[selectedRow]
        openDeviceDetailsViewAsSheet(forDevice: device)
    }

    // MARK: - NSTableView DataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredDevices.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnIdentifier = tableColumn?.identifier.rawValue else { return nil }
        let managedDevice = filteredDevices[row]
        
        if columnIdentifier == "NameColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("NameCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = managedDevice["deviceName"] as? String ?? "Unknown"
            cell?.textField?.toolTip = managedDevice["id"] as? String ?? "ID Pending"
            return cell
        } else if columnIdentifier == "UserPrincipalNameColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("UserPrincipalNameCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = managedDevice["userPrincipalName"] as? String ?? "Unknown"
            cell?.textField?.toolTip = managedDevice["userId"] as? String ?? "Unknown"
            return cell
        } else if columnIdentifier == "UserDisplayNameColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("UserDisplayNameCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = managedDevice["userDisplayName"] as? String ?? "Unknown"
            cell?.textField?.toolTip = managedDevice["userId"] as? String ?? "Unknown"
            return cell
        } else if columnIdentifier == "OperatingSystemColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("OperatingSystemCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = managedDevice["operatingSystem"] as? String ?? "Unknown"
            return cell
        } else if columnIdentifier == "ManufacturerColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ManufacturerCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = managedDevice["manufacturer"] as? String ?? "Unknown"
            return cell
        } else if columnIdentifier == "ModelColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ModelCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = managedDevice["model"] as? String ?? "Unknown"
            return cell
        } else if columnIdentifier == "SerialNumberColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("SerialNumberCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = managedDevice["serialNumber"] as? String ?? "Unknown"
            return cell
        } else if columnIdentifier == "EnrolledDateTimeColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("EnrolledDateTimeCell"), owner: self) as? NSTableCellView
            let enrolledDateTime = managedDevice["enrolledDateTime"] as? String
            cell?.textField?.stringValue = formatDate(enrolledDateTime)
            return cell
        } else if columnIdentifier == "LastSyncDateTimeColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("LastSyncDateTimeCell"), owner: self) as? NSTableCellView
            let lastSyncDate = managedDevice["lastSyncDateTime"] as? String
            cell?.textField?.stringValue = formatDate(lastSyncDate)
            return cell
        }
        return nil
    }
        
    // MARK: - NSTableView Delegate
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        let hasSelection = selectedRow >= 0 && selectedRow < filteredDevices.count

        detailsButton.isEnabled = hasSelection
    }
            
    // MARK: - Microsoft Date Formatting
    // Date formatter for human-friendly dates
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private lazy var isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /// Converts Microsoft Graph ISO8601 date string to human-friendly format
    /// - Parameter dateString: ISO8601 date string from Microsoft Graph API
    /// - Returns: Human-friendly date string or "Unknown" if parsing fails
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString, !dateString.isEmpty else {
            return "Unknown"
        }
        
        // Try parsing with ISO8601 formatter first
        if let date = isoDateFormatter.date(from: dateString) {
            return dateFormatter.string(from: date)
        }
        
        // Fallback: try with standard ISO formatter without fractional seconds
        let fallbackFormatter = ISO8601DateFormatter()
        if let date = fallbackFormatter.date(from: dateString) {
            return dateFormatter.string(from: date)
        }
        
        // If all parsing fails, return the original string
        return dateString
    }
    
    // MARK: - Reports Window Management
    
    /// Opens the Intune Reports window with preselection using MainViewController's singleton window management
    /// - Parameter preselectedReportType: The report type to preselect in the popup menu
    private func openIntuneReportsWindow(preselectedReportType: String? = nil) {
        // Find the MainViewController to delegate window management
        guard let reportType = preselectedReportType else {
            Logger.error("Could not find preselectedReportType to open Reports window", category: .core, toUserDirectory: true)
            return
        }
        
        WindowManager.shared.openWindow(
            identifier: "IntuneReportsViewController",
            storyboardName: "IntuneReports",
            controllerType: IntuneReportsViewController.self,
            windowTitle: "Intune Reports Export",
            defaultSize: NSSize(width: 550, height: 250),
            restoreKey: "IntuneReportsViewController",
            customization: { viewController in
                if let vc = viewController as? IntuneReportsViewController {
                    vc.preselectedReport = reportType
                }
            }
        )
    }
        
    // MARK: - Search and Filtering
    
    func controlTextDidChange(_ obj: Notification) {
        guard let searchField = obj.object as? NSSearchField else { return }
        searchText = searchField.stringValue
        filterDevices()
    }
    
    private func filterDevices() {
        if searchText.isEmpty {
            filteredDevices = allManagedDevices
        } else {
            filteredDevices = allManagedDevices.filter { device in
                let deviceName = device["deviceName"] as? String ?? ""
                let userPrincipalName = device["userPrincipalName"] as? String ?? ""
                let userDisplayName = device["userDisplayName"] as? String ?? ""
                let operatingSystem = device["operatingSystem"] as? String ?? ""
                let manufacturer = device["manufacturer"] as? String ?? ""
                let model = device["model"] as? String ?? ""
                let serialNumber = device["serialNumber"] as? String ?? ""
                
                return deviceName.localizedCaseInsensitiveContains(searchText) ||
                       userPrincipalName.localizedCaseInsensitiveContains(searchText) ||
                       userDisplayName.localizedCaseInsensitiveContains(searchText) ||
                       operatingSystem.localizedCaseInsensitiveContains(searchText) ||
                       manufacturer.localizedCaseInsensitiveContains(searchText) ||
                       model.localizedCaseInsensitiveContains(searchText) ||
                       serialNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        updateDeviceCount()
        tableView.reloadData()
        
        // Update button states after filtering
        let selectedRow = tableView.selectedRow
        let hasSelection = selectedRow >= 0 && selectedRow < filteredDevices.count

        detailsButton.isEnabled = hasSelection
    }
    
    private func updateDeviceCount() {
        let totalCount = allManagedDevices.count
        let filteredCount = filteredDevices.count
        
        if filteredCount == totalCount {
            deviceCountLabel.stringValue = "\(totalCount) device(s)"
        } else {
            deviceCountLabel.stringValue = "\(filteredCount) of \(totalCount) device(s)"
        }
    }

    
    // MARK: - User Feedback
    
    private func showErrorAlert(_ message: String, info: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showSuccess(message: String) {
        let alert = NSAlert()
        alert.messageText = "Success"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

}

