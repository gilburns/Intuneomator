//
//  LabelViewController.swift
//  Intuneomator
//
//  Created to display and manage Installomator labels in a table view,
//  providing search and filter functionality, version checks, and actions
//  to add or update labels via an XPC service.
//
import Foundation
import Cocoa

/// View controller responsible for displaying and managing a list of Installomator labels.
/// Handles loading labels from the file system, filtering/searching, showing label details,
/// and providing actions to add or update labels via XPC.
class LabelViewController: NSViewController {

    /// All label definitions loaded from the Installomator and custom label directories.
    var labelData: [LabelInfo] = []
    /// Subset of `labelData` matching the current search query or filter.
    var filteredLabelData: [LabelInfo] = []
    /// Labels loaded specifically from the custom labels folder.
    var customLabelData: [LabelInfo] = []

    /// Table view displaying the list of filtered labels.
    @IBOutlet weak var labelTableView: NSTableView!
    
    /// Scroll view containing the `labelTableView`.
    @IBOutlet weak var labelScrollView: NSScrollView!
    
    /// Search field for filtering labels by name.
    @IBOutlet weak var labelSearchField: NSSearchField!
    
    /// Text view that displays the contents of the selected label script.
    @IBOutlet weak var labelDetailsField: NSTextView!
    /// Label showing the number of visible labels versus total labels.
    @IBOutlet weak var labelCount: NSTextField!
    /// Warning field displayed if a selected label is missing the `appNewVersion` variable.
    @IBOutlet weak var warningLabel: NSTextField!
    /// Text field displaying the current version of the Installomator labels.
    @IBOutlet weak var versionTextField: NSTextField!
    /// Text field indicating whether the label definitions are up to date, with status color.
    @IBOutlet weak var versionUpdateField: NSTextField!

    /// Button to add the selected label (or “Add Again” if it already exists locally).
    @IBOutlet weak var buttonAddLabel: NSButton!
    /// Button to cancel and dismiss the label view sheet.
    @IBOutlet weak var buttonCancel: NSButton!
    /// Button to fetch and update labels from GitHub when an older version is detected.
    @IBOutlet weak var updateLabelsButton: NSButton!
    /// Button that shows help explaining the implications of missing `appNewVersion`.
    @IBOutlet weak var buttonShowHelpAppNewVersionMissing: NSButton!
    
    /// Checkbox to filter the table to show only custom labels.
    @IBOutlet weak var buttonShowCustomOnly: NSButton!
    
    /// Progress indicator shown while saving or adding a new label.
    @IBOutlet weak var progressIndicator: NSProgressIndicator!

    /// Buffer accumulating typed characters for keyboard-based row selection.
    var searchBuffer: String = ""
    /// Timer used to clear `searchBuffer` after a short delay between keystrokes.
    var searchTimer: Timer?
    
    /// Reusable popover instance for displaying contextual help overlays.
    private let helpPopover = HelpPopover()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set the view’s preferred size and initialize UI components.
        self.preferredContentSize = self.view.frame.size

        // Embed the label table view inside the scroll view.
        labelScrollView.documentView = labelTableView
        // Load all label scripts and update the displayed count.
        loadLabelData()
        setLabelCount()

        // Check if the local Installomator labels folder is up to date, then update UI accordingly.
        InstallomatorLabels.compareInstallomatorVersion { isUpToDate, statusMessage in
            DispatchQueue.main.async {
                self.versionUpdateField.stringValue = statusMessage
                self.versionUpdateField.textColor = isUpToDate ? .systemGreen : .systemRed
                self.updateLabelsButton.isHidden = isUpToDate // Hide the button if up-to-date
            }
        }

        // Load the stored version string from disk into the UI.
        loadVersionFile()
    }

    // MARK: - Actions
    @IBAction func saveNewContent(_ sender: Any) {
        /// Action invoked when the user clicks to save or “Add” a new label.
        /// Retrieves the selected label, shows a spinner, and triggers XPC call to add the label on disk.
        // Ensure a row is selected; otherwise, do nothing.
        guard let selectedRow = labelTableView.selectedRowIndexes.first else { return }
        
        // Show the progress indicator while the new label is being added.
        progressIndicator.startAnimation(nil)
        
        let selectedItem = filteredLabelData[selectedRow]
        let labelName = (selectedItem.label as NSString).deletingPathExtension
        let labelSource = selectedItem.labelSource

        // Call the XPC service to add the selected label to the local managed titles directory.
        XPCManager.shared.addNewLabel(labelName, labelSource) { dirPath in
            DispatchQueue.main.async {
                // Upon success, stop indicator, notify main view, and dismiss this sheet.
                if dirPath != nil {
                    self.progressIndicator.stopAnimation(nil)
                    
                    NotificationCenter.default.post(
                        name: .newDirectoryAdded,
                        object: nil,
                        userInfo: ["directoryPath": dirPath!]
                    )
                    self.dismiss(self)
                } else {
                    // On failure, stop the spinner and log the error.
                    self.progressIndicator.stopAnimation(nil)
                    print("Failed to update label content")
                }
            }
        }
    }
    
    @IBAction func updateLabels(_ sender: Any) {
        /// Action to update all labels from the GitHub repository.
        /// Triggers an XPC call; updates UI on completion.
        // Invoke XPC service to pull the latest labels from GitHub.
        XPCManager.shared.updateLabelsFromGitHub { success in
            DispatchQueue.main.async {
                // On success, update UI to reflect the new version and reload table.
                if success! {
                    self.versionUpdateField.stringValue = "Labels updated successfully."
                    self.versionUpdateField.textColor = .systemGreen
                    self.updateLabelsButton.isHidden = true
                    self.loadVersionFile()
                    self.loadLabelData() // Reload the table data after updating
                    self.setLabelCount()
                } else {
                    // On failure, display an error message in red.
                    self.versionUpdateField.stringValue = "Failed to update labels."
                    self.versionUpdateField.textColor = .systemRed
                }
            }
        }
    }
    
    @IBAction func toggleFilterCustomLabels(_ sender: NSButton) {
        /// Toggles showing only custom labels or all labels.
        /// Clears any existing search text.
        // Clear the search field when toggling filter.
        labelSearchField.stringValue = ""

        // Update `filteredLabelData` based on whether the custom-only checkbox is checked.
        switch sender.state {
        case .on:
            // If on, show only custom labels; otherwise, show all labels.
            self.filteredLabelData = self.customLabelData
            self.labelDetailsField.string.removeAll()
        case .off:
            // If on, show only custom labels; otherwise, show all labels.
            self.filteredLabelData = self.labelData
            self.labelDetailsField.string.removeAll()
        default:
            break
        }

        // Refresh the table and update the count display.
        labelTableView.reloadData()
        setLabelCount()
    }


    // MARK: - Help Buttons
    @IBAction func showHelpForInstallomator(_ sender: NSButton) {
        /// Displays a popover explaining what Installomator is and linking to the GitHub repo.
        // Build the attributed string with hyperlink styling for the GitHub URL.
        let helpText = NSMutableAttributedString(string: "Installomator is an open-source project designed for macOS that automates the installation and updating of various applications by downloading the latest versions directly from vendor websites.\n\nLearn more here: https://github.com/Installomator/Installomator")

        // Style the hyperlink and the remaining text.
        let hyperlinkRange = (helpText.string as NSString).range(of: "https://github.com/Installomator/Installomator")
        helpText.addAttribute(.link, value: "https://github.com/Installomator/Installomator", range: hyperlinkRange)
        helpText.addAttributes([
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ], range: hyperlinkRange)
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the configured popover anchored to the help button.
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }
    
    
    
    @IBAction func showHelpForAppNewVersionMissing(_ sender: NSButton) {
        /// Shows a popover explaining the impact of missing the `appNewVersion` variable in a label script.
        // Build the explanatory text for missing `appNewVersion`.
        let helpText = NSMutableAttributedString(string: "When the label is missing the 'appNewVersion' variable, Intuneomator will not be able to check for a new version without downloading it.\n\nThis will cause a download every time automation runs. Once downloaded, it can check for updates againt the downloaded content, but this will not be as efficient.\n\nIt will only upload to Intune if an update is available.\n")

        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Display the help popover.
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
        
    }

    // MARK: - Data Loading
    func loadLabelData() {
        /// Loads all `.sh` label files from the Installomator and custom label directories,
        /// parses them into `LabelInfo` objects, sorts, and populates `labelData` and `filteredLabelData`.
        do {
            // Fetch all files in the main labels folder.
            let directoryContents = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: AppConstants.installomatorLabelsFolderURL.path), includingPropertiesForKeys: nil)

            // Filter for `.sh` scripts, read contents, create `LabelInfo`, and sort by name.
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

            // Fetch all files in the custom labels folder.
            let directoryCustomContents = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: AppConstants.installomatorCustomLabelsFolderURL.path), includingPropertiesForKeys: nil)

            // Similarly process custom label scripts into `LabelInfo` objects.
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

            // Combine built-in and custom labels, then sort again.
            labelData += customLabelData
            labelData = labelData.sorted(by: { $0.label < $1.label })
            // Initialize the filtered array to show all labels by default.
            filteredLabelData = labelData
            // Refresh the NSTableView with the loaded data.
            labelTableView.reloadData()
        } catch {
            // On any error, print to console (e.g., if directories are missing).
            print("Failed to load label data: \(error)")
        }
    }
    
    // MARK: - Helpers
    /// Updates the `labelCount` text field to reflect the number of visible vs. total labels.
    private func setLabelCount() {
        // Compute counts for all and filtered labels.
        let allLabelsCount = labelData.count
        let visibleLabelsCount = filteredLabelData.count
        // Display the counts in the format “Viewing X of Y labels”.
        labelCount.stringValue = "Viewing \(visibleLabelsCount) of \(allLabelsCount) labels"
    }
    
    /// Reads the `Version.txt` file from disk and updates `versionTextField`; shows an error if loading fails.
    private func loadVersionFile() {
        do {
            // Attempt to read the version string from the file.
            let versionContent = try String(contentsOfFile: AppConstants.installomatorVersionFileURL.path, encoding: .utf8)
            // Trim whitespace and show the version in the UI.
            versionTextField.stringValue = versionContent.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            // On failure, show an error message in `versionTextField` and log the error.
            versionTextField.stringValue = "Failed to load version file: \(error.localizedDescription)"
            print("Error loading Version.txt: \(error)")
        }
    }
}

// MARK: - NSTableView Data Source & Delegate
extension LabelViewController: NSTableViewDataSource, NSTableViewDelegate {
    /// Returns the number of rows (labels) to display in the table view.
    func numberOfRows(in tableView: NSTableView) -> Int {
        // The number of filtered labels determines the table row count.
        filteredLabelData.count
    }

    /// Provides the view for each table cell, customizing based on column identifier (Source or Label).
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Determine which label info corresponds to this row.
        let item = filteredLabelData[row]
        
        // If the “Source” column, display an icon based on `labelSource`.
        if tableColumn?.identifier == NSUserInterfaceItemIdentifier("SourceColumn") {
            // Choose an image resource matching the source (“installomator” or “custom”).
            let imageName = NSImage.Name(item.labelSource)
            // Populate the image view in the cell or fallback to a standalone `NSImageView`.
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("SourceCell"), owner: self) as? NSTableCellView {
                cell.imageView?.image = NSImage(named: imageName)
                cell.toolTip = item.labelSource
                return cell
            } else {
                if let icon = NSImage(named: imageName) {
                    return NSImageView(image: icon)
                } else {
                    // If image not found, return an empty view
                    return NSView()
                }
            }
        }

        // If the “Label” column, display the label’s file name.
        if tableColumn?.identifier == NSUserInterfaceItemIdentifier("LabelColumn") {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("LabelCell"), owner: self) as? NSTableCellView
            // Set the cell’s text to the script name.
            cell?.textField?.stringValue = item.label
            cell?.toolTip = item.labelSource
            return cell
        }

        // If no known column, return an empty view.
        return nil
    }

    /// Called when the user changes the selected row in the table.
    /// Updates the detail view, warning label, and Add button based on the selected label.
    func tableViewSelectionDidChange(_ notification: Notification) {
        // Get the index of the selected row; if none, clear details and disable actions.
        let selectedRow = labelTableView.selectedRow
        guard selectedRow >= 0 else {
            // No row selected: clear detail view, disable Add button, hide warnings and help button.
            labelDetailsField.string = ""
            buttonAddLabel.isEnabled = false
            warningLabel.isHidden = true // Ensure the warning label is hidden when no row is selected
            buttonShowHelpAppNewVersionMissing.isHidden = true
            return
        }

        // Retrieve the `LabelInfo` for the selected row.
        let selectedItem = filteredLabelData[selectedRow]
        // Display the full script contents in the detail text view.
        labelDetailsField.string = selectedItem.labelContents

        // Derive the label name without extension and determine its source type.
        let labelName = (selectedItem.label as NSString).deletingPathExtension
        let folderPath = AppConstants.intuneomatorManagedTitlesFolderURL.path
        let fileManager = FileManager.default

        do {
            // Search the managed titles folder for any existing directories matching this label name.
            let directoryContents = try fileManager.contentsOfDirectory(atPath: folderPath)

            // Check for any folder starting with “labelName_” indicating it was already added.
            let matchingFolders = directoryContents.filter { $0.hasPrefix("\(labelName)_") && $0.contains("_") }
            // If no existing folders, set button title to “Add Label”; otherwise, “Add Again”.
            if matchingFolders.isEmpty {
                buttonAddLabel.title = "Add Label"
            } else {
                buttonAddLabel.title = "Add Again"
            }

            // Enable the Add/“Add Again” button regardless of folder existence.
            buttonAddLabel.isEnabled = true

        } catch {
            // If reading the managed titles directory fails, disable the button and set title to “Error”.
            print("Error reading directory contents: \(error.localizedDescription)")
            buttonAddLabel.isEnabled = false
            buttonAddLabel.title = "Error"
        }

        // Look for the `appNewVersion` variable to determine if a warning is needed.
        let lines = selectedItem.labelContents.components(separatedBy: .newlines)
        // If the line exists but the value is empty, show warning; otherwise hide it.
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
            // If no `appNewVersion` line is found at all, show a warning indicating it’s missing.
            warningLabel.stringValue = "Warning: appNewVersion is missing."
            warningLabel.isHidden = false
            buttonShowHelpAppNewVersionMissing.isHidden = false
        }
    }

    /// Called whenever the search field’s text changes.
    /// Updates `filteredLabelData` to include only labels matching the query.
    func controlTextDidChange(_ obj: Notification) {
        // Get the new search query string.
        let query = labelSearchField.stringValue
        // If the query is empty, show all labels; otherwise filter case-insensitively.
        filteredLabelData = query.isEmpty
            ? labelData
            : labelData.filter { $0.label.localizedCaseInsensitiveContains(query) }
        // Refresh the table with the filtered results.
        labelTableView.reloadData()
        // Clear any displayed details when the search changes.
        labelDetailsField.string = ""
        // Update label count after filtering.
        setLabelCount()
    }
    
    /// Handles keyboard input to quickly select table rows by typing their names.
    override func keyDown(with event: NSEvent) {
        // Allow default handling for Escape and Return keys.
        if event.keyCode == 53 || event.keyCode == 36 { // 53 = Escape, 36 = Return
            super.keyDown(with: event)
            return
        }

        // Append only valid characters to the search buffer.
        guard let characters = event.characters else { return }
        searchBuffer += characters.lowercased()

        // Reset the buffer-clearing timer whenever a new character is typed.
        searchTimer?.invalidate()

        // Schedule clearing of `searchBuffer` after 1 second of inactivity.
        searchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.searchBuffer = ""
        }

        // Try to find a label whose name starts exactly with the buffer text.
        if let exactIndex = labelData.firstIndex(where: { $0.label.lowercased().hasPrefix(searchBuffer) }) {
            labelTableView.selectRowIndexes(IndexSet(integer: exactIndex), byExtendingSelection: false)
            labelTableView.scrollRowToVisible(exactIndex)
        } else {
            // If no exact match, find the next higher label alphabetically.
            let sortedLabels = labelData.sorted { $0.label.lowercased() < $1.label.lowercased() }
            if let nearestIndex = sortedLabels.firstIndex(where: { $0.label.lowercased() > searchBuffer }) {
                // Select the nearest higher row
                let originalIndex = labelData.firstIndex(where: { $0.label == sortedLabels[nearestIndex].label })
                if let originalIndex = originalIndex {
                    labelTableView.selectRowIndexes(IndexSet(integer: originalIndex), byExtendingSelection: false)
                    labelTableView.scrollRowToVisible(originalIndex)
                }
            } else {
                // If buffer is past the last label, select the last row.
                labelTableView.selectRowIndexes(IndexSet(integer: labelData.count - 1), byExtendingSelection: false)
                labelTableView.scrollRowToVisible(labelData.count - 1)
            }
        }
    }
}

