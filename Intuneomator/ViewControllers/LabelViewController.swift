import Foundation
import Cocoa

class LabelViewController: NSViewController {

    var labelData: [LabelInfo] = []
    var filteredLabelData: [LabelInfo] = []
    var customLabelData: [LabelInfo] = []

    @IBOutlet weak var labelTableView: NSTableView!
    
    @IBOutlet weak var labelScrollView: NSScrollView!
    
    @IBOutlet weak var labelSearchField: NSSearchField!
    
    @IBOutlet weak var labelDetailsField: NSTextView!
    @IBOutlet weak var labelCount: NSTextField!
    @IBOutlet weak var warningLabel: NSTextField!
    @IBOutlet weak var versionTextField: NSTextField!
    @IBOutlet weak var versionUpdateField: NSTextField!

    @IBOutlet weak var buttonAddLabel: NSButton!
    @IBOutlet weak var buttonCancel: NSButton!
    @IBOutlet weak var updateLabelsButton: NSButton!
    @IBOutlet weak var buttonShowHelpAppNewVersionMissing: NSButton!
    
    @IBOutlet weak var buttonShowCustomOnly: NSButton!
    
    @IBOutlet weak var progressIndicator: NSProgressIndicator!

    var searchBuffer: String = ""
    var searchTimer: Timer?
    
    // Create a reusable HelpPopover instance
    private let helpPopover = HelpPopover()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = self.view.frame.size

        // Set up the label table view
        labelScrollView.documentView = labelTableView
        loadLabelData()
        setLabelCount()

        // Check Installomator version
        InstallomatorLabels.compareInstallomatorVersion { isUpToDate, statusMessage in
            DispatchQueue.main.async {
                self.versionUpdateField.stringValue = statusMessage
                self.versionUpdateField.textColor = isUpToDate ? .systemGreen : .systemRed
                self.updateLabelsButton.isHidden = isUpToDate // Hide the button if up-to-date
            }
        }

        loadVersionFile()
    }

    // MARK: - Actions
    @IBAction func saveNewContent(_ sender: Any) {
        guard let selectedRow = labelTableView.selectedRowIndexes.first else { return }
        
        progressIndicator.startAnimation(nil)
        
        let selectedItem = filteredLabelData[selectedRow]
        let labelName = (selectedItem.label as NSString).deletingPathExtension
        let labelSource = selectedItem.labelSource

        // Send the new content to the XPC service
        XPCManager.shared.addNewLabel(labelName, labelSource) { dirPath in
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

                    // Close the sheet
                    self.dismiss(self)
                } else {
                    // stop the progress indicator
                    self.progressIndicator.stopAnimation(nil)
                    print("Failed to update label content")
                }
            }
        }
    }
    
    @IBAction func updateLabels(_ sender: Any) {
        XPCManager.shared.updateLabelsFromGitHub { success in
            DispatchQueue.main.async {
                if success! {
                    self.versionUpdateField.stringValue = "Labels updated successfully."
                    self.versionUpdateField.textColor = .systemGreen
                    self.updateLabelsButton.isHidden = true
                    self.loadVersionFile()
                    self.loadLabelData() // Reload the table data after updating
                    self.setLabelCount()
                } else {
                    self.versionUpdateField.stringValue = "Failed to update labels."
                    self.versionUpdateField.textColor = .systemRed
                }
            }
        }
    }
    
    @IBAction func toggleFilterCustomLabels(_ sender: NSButton) {
        
        labelSearchField.stringValue = ""

        switch sender.state {
        case .on:
            self.filteredLabelData = self.customLabelData
        case .off:
            self.filteredLabelData = self.labelData
        default:
            break
        }

        labelTableView.reloadData()
        setLabelCount()
    }


    // MARK: - Help Buttons
    @IBAction func showHelpForInstallomator(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Installomator is an open-source project designed for macOS that automates the installation and updating of various applications by downloading the latest versions directly from vendor websites.\n\nLearn more here: https://github.com/Installomator/Installomator")

        // Add a hyperlink to Installomator
        let hyperlinkRange = (helpText.string as NSString).range(of: "https://github.com/Installomator/Installomator")
        helpText.addAttribute(.link, value: "https://github.com/Installomator/Installomator", range: hyperlinkRange)
        helpText.addAttributes([
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ], range: hyperlinkRange)

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }
    
    
    
    @IBAction func showHelpForAppNewVersionMissing(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "When the label is missing the 'appNewVersion' variable, Intuneomator will not be able to check for a new version without downloading it.\n\nThis will cause a download every time automation runs. Once downloaded, it can check for updates againt the downloaded content, but this will not be as efficient.\n\nIt will only upload to Intune if an update is available.\n")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
        
    }

    // MARK: - Data Loading
    func loadLabelData() {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: AppConstants.installomatorLabelsFolderURL.path), includingPropertiesForKeys: nil)

            labelData = directoryContents
                .filter { $0.lastPathComponent.hasSuffix(".sh") }
                .compactMap { labelItem in
                    guard let labelContents = try? String(contentsOf: labelItem) else { return nil }
                    return LabelInfo(
                        label: labelItem.lastPathComponent,
                        labelContents: labelContents,
                        labelFileURL: labelItem.absoluteString,
                        labelSource: "installomator"
                    )
                }
                .sorted(by: { $0.label < $1.label })

            let directoryCustomContents = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: AppConstants.installomatorCustomLabelsFolderURL.path), includingPropertiesForKeys: nil)

            customLabelData = directoryCustomContents
                .filter { $0.lastPathComponent.hasSuffix(".sh") }
                .compactMap { labelItem in
                    guard let labelContents = try? String(contentsOf: labelItem) else { return nil }
                    return LabelInfo(
                        label: labelItem.lastPathComponent,
                        labelContents: labelContents,
                        labelFileURL: labelItem.absoluteString,
                        labelSource: "custom"
                    )
                }
                .sorted(by: { $0.label < $1.label })

            
            labelData += customLabelData.sorted(by: { $0.label < $1.label })
            
            filteredLabelData = labelData
            labelTableView.reloadData()
        } catch {
            print("Failed to load label data: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func setLabelCount() {
        let allLabelsCount = labelData.count
        let visibleLabelsCount = filteredLabelData.count
        labelCount.stringValue = "Viewing \(visibleLabelsCount) of \(allLabelsCount) labels"
    }

    

    

    
    // MARK: - Load Version File
    private func loadVersionFile() {
        do {
            let versionContent = try String(contentsOfFile: AppConstants.installomatorVersionFileURL.path, encoding: .utf8)
            versionTextField.stringValue = versionContent.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            versionTextField.stringValue = "Failed to load version file: \(error.localizedDescription)"
            print("Error loading Version.txt: \(error)")
        }
    }
}

// MARK: - Table View Delegate & Data Source
extension LabelViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredLabelData.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filteredLabelData[row]
        
        
        if tableColumn?.identifier == NSUserInterfaceItemIdentifier("SourceColumn") {
            // Display icon based on labelSource ("github" or "custom")
            let imageName = NSImage.Name(item.labelSource)
            // Attempt to dequeue a cell view with an image view outlet
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("SourceCell"), owner: self) as? NSTableCellView {
                cell.imageView?.image = NSImage(named: imageName)
                cell.toolTip = item.labelSource
                return cell
            } else {
                // Fallback: standalone image view
                if let icon = NSImage(named: imageName) {
                    return NSImageView(image: icon)
                } else {
                    // If image not found, return an empty view
                    return NSView()
                }
            }
        }

        if tableColumn?.identifier == NSUserInterfaceItemIdentifier("LabelColumn") {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("LabelCell"), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = item.label
            cell?.toolTip = item.labelSource
            return cell
        }

        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = labelTableView.selectedRow
        guard selectedRow >= 0 else {
            labelDetailsField.string = ""
            buttonAddLabel.isEnabled = false
            warningLabel.isHidden = true // Ensure the warning label is hidden when no row is selected
            buttonShowHelpAppNewVersionMissing.isHidden = true
            return
        }

        let selectedItem = filteredLabelData[selectedRow]
        labelDetailsField.string = selectedItem.labelContents

        // Extract label name and search for matching folders
        let labelName = (selectedItem.label as NSString).deletingPathExtension
        let folderPath = AppConstants.intuneomatorManagedTitlesFolderURL.path
        let fileManager = FileManager.default

        do {
            // Get all folders in the parent directory
            let directoryContents = try fileManager.contentsOfDirectory(atPath: folderPath)

            // Check for any folders that start with "labelname_"
            let matchingFolders = directoryContents.filter { $0.hasPrefix("\(labelName)_") && $0.contains("_") }
            if matchingFolders.isEmpty {
                buttonAddLabel.title = "Add Label"
            } else {
                buttonAddLabel.title = "Add Again"
            }

            // Enable the button regardless of whether matching folders exist
            buttonAddLabel.isEnabled = true

        } catch {
            print("Error reading directory contents: \(error.localizedDescription)")
            buttonAddLabel.isEnabled = false
            buttonAddLabel.title = "Error"
        }

        // Search for `appNewVersion=` in `labelContents`
        let lines = selectedItem.labelContents.components(separatedBy: .newlines)
        if let appNewVersionLine = lines.first(where: { $0.contains("appNewVersion=") }) {
            let value = appNewVersionLine.replacingOccurrences(of: "appNewVersion=", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                warningLabel.stringValue = "Warning: appNewVersion is missing or empty."
                warningLabel.isHidden = false
                buttonShowHelpAppNewVersionMissing.isHidden = false

            } else {
                warningLabel.isHidden = true
                buttonShowHelpAppNewVersionMissing.isHidden = true

            }
        } else {
            warningLabel.stringValue = "Warning: appNewVersion is missing."
            warningLabel.isHidden = false
            buttonShowHelpAppNewVersionMissing.isHidden = false
        }

    }

    // MARK: - Label Search
    func controlTextDidChange(_ obj: Notification) {
        let query = labelSearchField.stringValue
        filteredLabelData = query.isEmpty
            ? labelData
            : labelData.filter { $0.label.localizedCaseInsensitiveContains(query) }
        labelTableView.reloadData()
        labelDetailsField.string = ""
        setLabelCount()

    }
    
    // MARK: - Handle Keyboard Input
    override func keyDown(with event: NSEvent) {
        // Ignore Escape and Return keys
        if event.keyCode == 53 || event.keyCode == 36 { // 53 = Escape, 36 = Return
            super.keyDown(with: event)
            return
        }

        guard let characters = event.characters else { return }

        // Append to the search buffer
        searchBuffer += characters.lowercased()

        // Invalidate any existing timer
        searchTimer?.invalidate()

        // Set a timer to clear the buffer after a short delay
        searchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.searchBuffer = ""
        }

        // Search for an exact match
        if let exactIndex = labelData.firstIndex(where: { $0.label.lowercased().hasPrefix(searchBuffer) }) {
            // Exact match found
            labelTableView.selectRowIndexes(IndexSet(integer: exactIndex), byExtendingSelection: false)
            labelTableView.scrollRowToVisible(exactIndex)
        } else {
            // Nearest match search
            let sortedLabels = labelData.sorted { $0.label.lowercased() < $1.label.lowercased() }

            if let nearestIndex = sortedLabels.firstIndex(where: { $0.label.lowercased() > searchBuffer }) {
                // Select the nearest higher row
                let originalIndex = labelData.firstIndex(where: { $0.label == sortedLabels[nearestIndex].label })
                if let originalIndex = originalIndex {
                    labelTableView.selectRowIndexes(IndexSet(integer: originalIndex), byExtendingSelection: false)
                    labelTableView.scrollRowToVisible(originalIndex)
                }
            } else {
                // If no higher match, select the last row
                labelTableView.selectRowIndexes(IndexSet(integer: labelData.count - 1), byExtendingSelection: false)
                labelTableView.scrollRowToVisible(labelData.count - 1)
            }
        }
    }

}

