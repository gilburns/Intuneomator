///
///  DevicesSheetViewController.swift
///  Intuneomator
///
///  View controller for displaying a list of devices that have a specific application installed.
///  Provides a searchable table view of device details and functionality to export the device list to CSV.
///
///  **Key Features:**
///  - Displays device name, ID, and email address in a table view
///  - Supports dynamic resizing and persists sheet size across launches
///  - Allows exporting the displayed device list to a CSV file
///  - Provides helper dialogs for success and error messages
///
//  DevicesSheetViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

/// `DevicesSheetViewController` manages the sheet UI showing devices associated with a given application.
/// Implements table view data source and delegate methods to display device details,
/// and provides actions for dismissing the sheet and exporting to CSV.
class DevicesSheetViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    /// Text field displaying the name of the application whose devices are shown.
    @IBOutlet weak var appNameField: NSTextField!
    
    /// Table view presenting the list of devices with columns for name, ID, and email.
    @IBOutlet weak var tableView: NSTableView!
    
    /// Button to dismiss the sheet when clicked.
    @IBOutlet weak var okButton: NSButton!
    
    /// Button to initiate exporting the current device list to a CSV file.
    @IBOutlet weak var buttonExportCSV: NSButton!
    
    /// Image view to present the potential icon of the application
    @IBOutlet weak var appIconImageView: NSImageView!

    
    /// The application name used to set the sheet title and CSV file default name.
    var appName: String = ""
    
    /// The application label used to set the sheet icon.
    var appLabelName: String = ""
    
    /// Array of `DeviceInfo` objects representing devices where the app is installed.
    var devices: [DeviceInfo] = []
    
    
    // MARK: - Lifecycle
    /// Called after the view has loaded into memory.
    /// - Configures the table view’s delegate and data source.
    /// - Sets the application name field and reloads the table data.
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        appNameField.stringValue = appName
        if appLabelName != "No match detected" || appLabelName != "" {
            fetchAppIcon(for: appLabelName)
        }
        tableView.reloadData()
    }

    /// Called just before the view appears on screen.
    /// - Restores the saved sheet size from UserDefaults or applies a default size.
    /// - Enforces a minimum window size to prevent overly small sheet dimensions.
    override func viewWillAppear() {
        super.viewWillAppear()

        // Load the saved size or use the default size
        let defaultSize = NSSize(width: 700, height: 400)
        let savedSize = loadSavedSheetSize() ?? defaultSize

        if let sheetWindow = view.window {
            sheetWindow.setContentSize(savedSize) // Apply the saved or default size
            sheetWindow.minSize = NSSize(width: 700, height: 400) // Set minimum size
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
            dismissSheet(self)
        } else {
            super.keyDown(with: event)
        }
    }
    

    
    /// Loads the previously saved sheet size from user defaults.
    /// - Returns: An `NSSize` representing the saved dimensions, or `nil` if none exist.
    private func loadSavedSheetSize() -> NSSize? {
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "DiscoveredDevicesViewSheetSize") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
            return NSSize(width: width, height: height)
        }
        return nil
    }

    
    private func fetchAppIcon(for labelName: String) {
        guard labelName != "No match detected" else { return }

        let urlString = "https://icons.intuneomator.org/\(labelName).png"
        guard let iconURL = URL(string: urlString) else { return }

        let task = URLSession.shared.dataTask(with: iconURL) { [weak self] data, response, error in
            guard let self = self else { return }
            guard let data = data, error == nil, let image = NSImage(data: data) else {
                return
            }

            DispatchQueue.main.async {
                self.appIconImageView.image = image
            }
        }
        task.resume()
    }
    
    // MARK: - Tableview
    /// NSTableViewDataSource: Returns the number of rows to display, based on the `devices` array count.
    /// - Parameter tableView: The table view requesting the row count.
    /// - Returns: The total number of devices.
    func numberOfRows(in tableView: NSTableView) -> Int {
        return devices.count
    }

    /// NSTableViewDelegate/DataSource: Provides the view for each cell in the table.
    /// Populates cells for columns identified by "deviceName", "id", or "emailAddress".
    ///
    /// - Parameters:
    ///   - tableView: The table view requesting the cell view.
    ///   - tableColumn: The table column for which the cell is needed.
    ///   - row: The row index corresponding to a `DeviceInfo` entry.
    /// - Returns: An `NSTableCellView` configured with the appropriate device property, or `nil`.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnIdentifier = tableColumn?.identifier.rawValue else { return nil }
        let device = devices[row]

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(columnIdentifier), owner: self) as? NSTableCellView {
            switch columnIdentifier {
                case "deviceName":
                    cell.textField?.stringValue = device.deviceName
                case "id":
                    cell.textField?.stringValue = device.id
                case "emailAddress":
                    cell.textField?.stringValue = device.emailAddress
                default:
                    break
            }

            cell.textField?.isSelectable = true
            cell.textField?.allowsEditingTextAttributes = false
            cell.textField?.lineBreakMode = .byTruncatingTail // Prevents overflow

            return cell
        }
        return nil
    }
    
    // MARK: - Actions
    /// IBAction to dismiss the sheet view.
    /// - Parameter sender: The button that triggered the dismissal.
    @IBAction func dismissSheet(_ sender: Any) {
        self.dismiss(self)
    }
    
    /// IBAction to begin exporting the displayed device list to a CSV file.
    /// - Parameter sender: The button that triggered the export action.
    @IBAction func exportToCSV(_ sender: NSButton) {
        saveDevicesToCSV()
    }

    
    // MARK: - Export
    /// Gathers device data and prompts the user to choose a file location for CSV export.
    /// - Constructs a CSV string with headers and each device’s properties.
    /// - Writes the CSV content to the selected file URL, showing an alert on success or error.
    func saveDevicesToCSV() {
        let appName = appNameField.stringValue
        let savePanel = NSSavePanel()
        savePanel.message = "Save \(appName) Device List"
        savePanel.nameFieldStringValue = "\(appName)_Device_List.csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    var csvString = "Device Name, ID, Email Address\n" // CSV Headers
                    
                    for device in self.devices {
                        let row = "\"\(device.deviceName)\",\"\(device.id)\",\"\(device.emailAddress)\""
                        csvString.append("\(row)\n")
                    }

                    try csvString.write(to: url, atomically: true, encoding: .utf8)
//                    self.showSuccessDialog(message: "CSV file successfully saved to:\n\(url.path)")

                } catch {
                    self.showErrorDialog(message: "Failed to save CSV:\n\(error.localizedDescription)")
                }
            }
        }
    }
    
    
    /// Displays an informational alert with a success message.
    /// - Parameter message: The descriptive text to show in the alert.
    func showSuccessDialog(message: String) {
        let alert = NSAlert()
        alert.messageText = "Success"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Displays a critical error alert with the provided message.
    /// - Parameter message: The descriptive error text to show in the alert.
    func showErrorDialog(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
