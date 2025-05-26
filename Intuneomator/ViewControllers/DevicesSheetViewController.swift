//
//  DevicesSheetViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

class DevicesSheetViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet weak var appNameField: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var okButton: NSButton!
    
    @IBOutlet weak var buttonExportCSV: NSButton!

    
    var appName: String = ""
    var devices: [DeviceInfo] = []
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        appNameField.stringValue = appName
        tableView.reloadData()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        // Load the saved size or use the default size
        let defaultSize = NSSize(width: 700, height: 400)
        let savedSize = loadSavedSheetSize() ?? defaultSize

        if let sheetWindow = view.window {
            sheetWindow.setContentSize(savedSize) // Apply the saved or default size
            sheetWindow.minSize = NSSize(width: 700, height: 400) // Set minimum size
        }
    }

    
    // Load the size from UserDefaults
    private func loadSavedSheetSize() -> NSSize? {
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "DiscoveredDevicesViewSheetSize") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
            return NSSize(width: width, height: height)
        }
        return nil
    }

    
    // MARK: Table Functions
    func numberOfRows(in tableView: NSTableView) -> Int {
        return devices.count
    }

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
    
    // MARK: Actions
    @IBAction func dismissSheet(_ sender: NSButton) {
        self.dismiss(self)
    }
    
    // Function to save devices to CSV
    @IBAction func exportToCSV(_ sender: NSButton) {
        saveDevicesToCSV()
    }

    
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
    
    
    // MARK: Dialog Helpers
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
}

