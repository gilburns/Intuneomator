//
//  ScriptLibraryViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/20/25.
//

import Cocoa

protocol ScriptLibraryDelegate: AnyObject {
    func scriptLibrary(_ controller: ScriptLibraryViewController, didSelectScript content: String)
}

enum ScriptType {
    case preInstall
    case postInstall
    
    var folderName: String {
        switch self {
        case .preInstall: return "Pre"
        case .postInstall: return "Post"
        }
    }
}

class ScriptLibraryViewController: NSViewController {
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var folderNameLabel: NSTableColumn!
    @IBOutlet weak var scriptTableView: NSTableView!
    @IBOutlet weak var previewTextView: NSTextView!
    @IBOutlet weak var selectButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    
    /// Text field displaying the current version of the Intuneomator Script Library.
    @IBOutlet weak var versionTextField: NSTextField!
    /// Text field displaying the SHA of the current Intuneomator Script Library.
    @IBOutlet weak var shaTextField: NSTextField!
    /// Text field indicating whether the Script Library is up to date, with status color.
    @IBOutlet weak var versionUpdateField: NSTextField!
    /// Text field indicating whether the sha Script Library is up to date, with status color.
    @IBOutlet weak var shaUpdateField: NSTextField!
    
    /// Button to fetch and update Scripts Library from GitHub when an older version is detected locally.
    @IBOutlet weak var updateScriptLibraryButton: NSButton!

    
    weak var delegate: ScriptLibraryDelegate?
    var scriptType: ScriptType = .preInstall
    private var scriptFiles: [ScriptFile] = []
    private var selectedScript: ScriptFile?
    
    /// Application info passed from the script view controller to use for substitutions in script
    var name: String?
    var bundleId: String?
    
    /// Available tokens for script substitution
    private var availableTokens: [String: String] {
        var tokens: [String: String] = [:]
        
        if let name = name {
            tokens["APP_NAME"] = name
        }
        
        if let bundleId = bundleId {
            tokens["BUNDLE_ID"] = bundleId
        }
        
        return tokens
    }

    struct ScriptFile {
        let name: String
        let url: URL
        let content: String
        let modificationDate: Date
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadScripts()
        
        
        // Check if the local Installomator labels folder is up to date, then update UI accordingly.
        ScriptLibraryManager.compareIntuneomatorScriptVersion { isUpToDate, statusMessage, sha in
            DispatchQueue.main.async {
                self.versionUpdateField.stringValue = statusMessage
                self.versionUpdateField.textColor = isUpToDate ? .systemGreen : .systemRed
                self.shaUpdateField.stringValue = String(sha.prefix(8)) // Show first 8 characters of SHA
                self.shaUpdateField.toolTip = sha
                self.shaUpdateField.textColor = isUpToDate ? .systemGreen : .systemRed
                self.updateScriptLibraryButton.isHidden = isUpToDate // Hide the button if up-to-date
            }
        }

        // Load the stored version string from disk into the UI.
        loadVersionFile()

    }
    
    
    /// Called just before the view appears on screen.
    /// - Restores the saved sheet size from UserDefaults or applies a default size.
    /// - Enforces a minimum window size to prevent overly small sheet dimensions.
    override func viewWillAppear() {
        super.viewWillAppear()

        // Load the saved size or use the default size
        let defaultSize = NSSize(width: 900, height: 500)
        let savedSize = loadSavedSheetSize() ?? defaultSize

        if let sheetWindow = view.window {
            sheetWindow.setContentSize(savedSize) // Apply the saved or default size
            sheetWindow.minSize = NSSize(width: 900, height: 500) // Set minimum size
        }
        
        
        let effectView = NSVisualEffectView(frame: view.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.blendingMode = .withinWindow
        effectView.material = .underWindowBackground
        effectView.state = .active

        self.view.addSubview(effectView, positioned: .below, relativeTo: nil)
    }

    /// Loads the previously saved sheet size from user defaults.
    /// - Returns: An `NSSize` representing the saved dimensions, or `nil` if none exist.
    private func loadSavedSheetSize() -> NSSize? {
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "ScriptLibraryDelegate") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
            return NSSize(width: width, height: height)
        }
        return nil
    }


    private func setupUI() {
        titleLabel.stringValue = "Select a Script for: \(name ?? "Application")"
        
        title = "Script Library - \(scriptType == .preInstall ? "Pre-Install" : "Post-Install") Scripts"
        folderNameLabel.title = title ?? "Script Library"
        let boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        let attrTitle = NSAttributedString(
            string: folderNameLabel.title,
            attributes: [
                .font: boldFont,
                .foregroundColor: NSColor.systemBlue
            ]
        )
        folderNameLabel.headerCell.attributedStringValue = attrTitle

        
        scriptTableView.delegate = self
        scriptTableView.dataSource = self
        
        previewTextView.isEditable = false
        previewTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        
        selectButton.isEnabled = false
        
        if let scrollView = previewTextView.enclosingScrollView {
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            scrollView.autohidesScrollers = false
        }
    }
    
    private func loadScripts() {
        let scriptsURL = AppConstants.intuneomatorScriptsURL.appendingPathComponent(scriptType.folderName)
        
        do {
            let fileManager = FileManager.default
            
            if !fileManager.fileExists(atPath: scriptsURL.path) {
                try fileManager.createDirectory(at: scriptsURL, withIntermediateDirectories: true)
            }
            
            let fileURLs = try fileManager.contentsOfDirectory(at: scriptsURL, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
            
            let shellFiles = fileURLs.filter { $0.pathExtension == "sh" }
            
            scriptFiles = shellFiles.compactMap { url in
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey])
                    let modificationDate = resourceValues.contentModificationDate ?? Date()
                    
                    return ScriptFile(
                        name: url.deletingPathExtension().lastPathComponent,
                        url: url,
                        content: content,
                        modificationDate: modificationDate
                    )
                } catch {
                    Logger.log("Failed to load script file \(url.lastPathComponent): \(error.localizedDescription)")
                    return nil
                }
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                self.scriptTableView.reloadData()
                if !self.scriptFiles.isEmpty {
                    self.scriptTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                    self.tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification, object: self.scriptTableView))
                }
            }
            
        } catch {
            Logger.log("Failed to load scripts from \(scriptsURL.path): \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.showAlert(title: "Error Loading Scripts", message: "Failed to load scripts from the library: \(error.localizedDescription)")
            }
        }
    }
    
    private func updatePreview() {
        guard let selectedScript = selectedScript else {
            previewTextView.string = "Select a script to preview its contents."
            selectButton.isEnabled = false
            return
        }
        
        let processedContent = processTokensForDisplay(selectedScript.content)
        displayProcessedContent(processedContent)
        selectButton.isEnabled = true
    }
    
    /// Substitutes tokens in script content and returns the processed string
    private func substituteTokens(in content: String) -> String {
        var processedContent = content
        
        for (token, value) in availableTokens {
            let tokenPattern = "{{\(token)}}"
            processedContent = processedContent.replacingOccurrences(of: tokenPattern, with: value)
        }
        
        return processedContent
    }
    
    /// Processes tokens for display purposes, showing both original and substituted values
    private func processTokensForDisplay(_ content: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: content)
        
        // Base font
        let baseFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        attributedString.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: attributedString.length))
        
        // Find and highlight tokens
        for (token, value) in availableTokens {
            let tokenPattern = "{{\(token)}}"
            let regex = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: tokenPattern))
            
            if let regex = regex {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))
                
                // Process matches in reverse order to maintain correct indices
                for match in matches.reversed() {
                    let matchRange = match.range
                    
                    // Create replacement text showing both token and value
                    let replacementText = "\(tokenPattern) → \(value)"
                    let replacementAttr = NSMutableAttributedString(string: replacementText)
                    
                    // Style the token part
                    let tokenRange = NSRange(location: 0, length: tokenPattern.count)
                    replacementAttr.addAttribute(.backgroundColor, value: NSColor.systemBlue.withAlphaComponent(0.2), range: tokenRange)
                    replacementAttr.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: tokenRange)
                    replacementAttr.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold), range: tokenRange)
                    
                    // Style the arrow
                    let arrowRange = NSRange(location: tokenPattern.count, length: 3)
                    replacementAttr.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: arrowRange)
                    
                    // Style the value part
                    let valueRange = NSRange(location: tokenPattern.count + 3, length: value.count)
                    replacementAttr.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: valueRange)
                    replacementAttr.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium), range: valueRange)
                    
                    // Replace in the main attributed string
                    attributedString.replaceCharacters(in: matchRange, with: replacementAttr)
                }
            }
        }
        
        return attributedString
    }
    
    /// Displays the processed content in the preview text view
    private func displayProcessedContent(_ attributedContent: NSAttributedString) {
        previewTextView.textStorage?.setAttributedString(attributedContent)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @IBAction func selectButtonClicked(_ sender: NSButton) {
        guard let selectedScript = selectedScript else { return }
        let processedScript = substituteTokens(in: selectedScript.content)
        delegate?.scriptLibrary(self, didSelectScript: processedScript)
        dismiss(self)
    }
    
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        dismiss(self)
    }
    
    
    @IBAction func updateScriptLibraryButtonClicked(_ sender: Any) {
        /// Action to update Script Library from the GitHub repository.
        /// Triggers an XPC call; updates UI on completion.
        // Invoke XPC service to pull the latest Script Library from GitHub.
        XPCManager.shared.updateScriptLibraryFromGitHub { success in
            DispatchQueue.main.async {
                // On success, update UI to reflect the new version and reload table.
                if success! {
                    self.versionUpdateField.stringValue = "Scripts updated successfully."
                    self.versionUpdateField.textColor = .systemGreen
                    self.updateScriptLibraryButton.isHidden = true
                    self.shaUpdateField.stringValue = "Success"
                    self.shaUpdateField.textColor = .systemGreen
                    self.loadVersionFile()
                    self.loadScripts() // Reload the table data after updating
                    
                    // Wait 5 seconds, then refresh the version fields with actual data
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.loadVersionFile() // Refresh with new SHA and date
                        
                        // Also refresh the version comparison status
                        ScriptLibraryManager.compareIntuneomatorScriptVersion { isUpToDate, statusMessage, sha in
                            DispatchQueue.main.async {
                                self.versionUpdateField.stringValue = statusMessage
                                self.versionUpdateField.textColor = isUpToDate ? .systemGreen : .systemRed
                                self.shaUpdateField.stringValue = String(sha.prefix(8))
                                self.shaUpdateField.toolTip = sha
                                self.shaUpdateField.textColor = isUpToDate ? .systemGreen : .systemRed
                                self.updateScriptLibraryButton.isHidden = isUpToDate
                            }
                        }
                    }
                } else {
                    // On failure, display an error message in red.
                    self.versionUpdateField.stringValue = "Failed to update script library."
                    self.versionUpdateField.textColor = .systemRed
                }
            }
        }
    }

    private func loadVersionFile() {
        do {
            // Attempt to read the version JSON from the file.
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: AppConstants.intuneomatorScriptsVersionFileURL.path))
            
            if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String],
               let date = json["date"],
               let sha = json["sha"] {
                
                // Format the date for display (extract YYYY-MM-DD from ISO 8601)
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                let displayDate: String
                if let parsedDate = dateFormatter.date(from: date) {
                    let outputFormatter = DateFormatter()
                    outputFormatter.dateFormat = "yyyy-MM-dd"
                    displayDate = outputFormatter.string(from: parsedDate)
                } else {
                    displayDate = date.components(separatedBy: "T").first ?? date
                }
                                
                // Update UI fields
                versionTextField.stringValue = displayDate
                shaTextField.stringValue = String(sha.prefix(8)) // Show first 8 characters of SHA
                shaTextField.toolTip = sha
            } else {
                // If JSON parsing fails, show fallback values
                versionTextField.stringValue = "Unable to parse version data"
                shaTextField.stringValue = "N/A"
            }
        } catch {
            // On failure, show an error message in both fields and log the error.
            versionTextField.stringValue = "Failed to load version file"
            shaTextField.stringValue = "Error"
            Logger.error("Error loading Version.json: \(error)", category: .core, toUserDirectory: true)
        }
    }

}

extension ScriptLibraryViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return scriptFiles.count
    }
}

extension ScriptLibraryViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < scriptFiles.count else { return nil }
        
        let scriptFile = scriptFiles[row]
        let identifier = NSUserInterfaceItemIdentifier("ScriptCell")
        
        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = identifier
            
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            cellView?.addSubview(textField)
            cellView?.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }
        
        cellView?.textField?.stringValue = scriptFile.name
        cellView?.toolTip = "Modified: \(DateFormatter.localizedString(from: scriptFile.modificationDate, dateStyle: .short, timeStyle: .short))"
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = scriptTableView.selectedRow
        
        if selectedRow >= 0 && selectedRow < scriptFiles.count {
            selectedScript = scriptFiles[selectedRow]
        } else {
            selectedScript = nil
        }
        
        updatePreview()
    }
}
