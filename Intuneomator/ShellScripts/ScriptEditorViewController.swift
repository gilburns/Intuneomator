//
//  ScriptEditorViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/22/25.
//

import Cocoa

class ScriptEditorViewController: NSViewController, TabbedSheetChildProtocol, NSTextViewDelegate {
    @IBOutlet weak var displayNameTextField: NSTextField!
    @IBOutlet weak var descriptionTextView: NSTextView!
    
    @IBOutlet weak var dateCreated: NSTextField!
    @IBOutlet weak var dateLastModified: NSTextField!

    @IBOutlet weak var scriptContentTextView: NSTextView!
    @IBOutlet weak var blockExecutionNotificationsPopup: NSPopUpButton!
    @IBOutlet weak var executionFrequencyPopup: NSPopUpButton!
    @IBOutlet weak var retryCountPopup: NSPopUpButton!
    @IBOutlet weak var runAsAccountPopup: NSPopUpButton!
    
    @IBOutlet weak var scriptID: NSTextField!
    
    @IBOutlet weak var pendingImportLabel: NSTextField!

    @IBOutlet weak var saveToFileButton: NSButton!

    var scriptData: [String: Any]?
    var isNewScript = false
    var saveHandler: (([String: Any]) -> Void)?
    var scriptId: String?
    
    // MARK: - Change Tracking Properties
    var hasUnsavedChanges = false
    var originalData: [String: Any] = [:]
    
    /// Reference to the parent TabbedSheetViewController to notify about save button state
    weak var parentTabViewController: TabbedSheetViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPopups()
    }

    // Track if view has been configured to avoid repeating setup
    private var viewConfigured = false
    
    override func viewWillAppear() {
        super.viewWillAppear()

        // Only do one-time setup, not on every tab switch
        if !viewConfigured {
            populateFields()
            
            let effectView = NSVisualEffectView(frame: view.bounds)
            effectView.autoresizingMask = [.width, .height]
            effectView.blendingMode = .withinWindow
            effectView.material = .windowBackground
            effectView.state = .active
            
            self.view.addSubview(effectView, positioned: .below, relativeTo: nil)
            
            if let sheetWindow = view.window {
                sheetWindow.minSize = NSSize(width: 700, height: 650) // Set minimum size
            }
            
            viewConfigured = true
        }
    }

    func setupPopups() {
        executionFrequencyPopup.removeAllItems()
        executionFrequencyPopup.addItems(withTitles: ["Not Configured",
            "Every 15 minutes", "Every 30 minutes", "Every 1 hour",
            "Every 2 hours", "Every 3 hours", "Every 6 hours",
            "Every 12 hours", "Every 1 day", "Every 1 week"
        ])
        retryCountPopup.removeAllItems()
        retryCountPopup.addItems(withTitles: ["Not Configured", "1", "2", "3"])
        runAsAccountPopup.removeAllItems()
        runAsAccountPopup.addItems(withTitles: ["System", "User"])
        blockExecutionNotificationsPopup.removeAllItems()
        blockExecutionNotificationsPopup.addItems(withTitles: ["Not Configured", "Yes"])
    }

    func populateFields() {
        guard let script = scriptData else { return }
        
        scriptId = script["id"] as? String
        scriptID.stringValue = scriptId ?? ""
        
        displayNameTextField.stringValue = script["displayName"] as? String ?? ""
        descriptionTextView.string = script["description"] as? String ?? ""

        dateCreated.stringValue = (script["createdDateTime"] as? String ?? "").formatIntuneDate()
        dateLastModified.stringValue = (script["lastModifiedDateTime"] as? String ?? "").formatIntuneDate()

        if isNewScript, let content = script["scriptContent"] as? String {
            scriptContentTextView.string = content
            scriptContentTextView.textColor = NSColor.systemOrange
            pendingImportLabel.isHidden = false
        } else if let content = script["scriptContent"] as? String {
            if let decodedData = Data(base64Encoded: content),
               let decodedString = String(data: decodedData, encoding: .utf8) {
                scriptContentTextView.string = decodedString
            } else {
                scriptContentTextView.string = content
            }
            scriptContentTextView.textColor = NSColor.labelColor
            pendingImportLabel.isHidden = true
        } else {
            scriptContentTextView.string = "Failed to load script"
            scriptContentTextView.textColor = NSColor.systemRed
            pendingImportLabel.isHidden = true
        }

        blockExecutionNotificationsPopup.selectItem(at: (script["blockExecutionNotifications"] as? Bool) == true ? 1 : 0)
        executionFrequencyPopup.selectItem(at: ScriptUtilities.executionFrequencyIndex(for: script["executionFrequency"] as? String ?? "PT0M"))
        retryCountPopup.selectItem(at: script["retryCount"] as? Int ?? 0)

        let runAsAccountValue = script["runAsAccount"] as? String ?? "system"
        runAsAccountPopup.selectItem(withTitle: runAsAccountValue.capitalized)
        
        // Store original data for change tracking
        storeOriginalData()
        
        // Set up change tracking for all controls
        setupChangeTracking()
        
        // Initial state: no unsaved changes
        hasUnsavedChanges = false
        updateSaveButtonState()
    }
    
    // MARK: - Change Tracking Implementation
    
    /// Stores the original data for change comparison
    private func storeOriginalData() {
        originalData = [
            "displayName": displayNameTextField.stringValue,
            "description": descriptionTextView.string,
            "scriptContent": scriptContentTextView.string,
            "blockExecutionNotifications": blockExecutionNotificationsPopup.indexOfSelectedItem == 1,
            "executionFrequency": executionFrequencyPopup.indexOfSelectedItem,
            "retryCount": retryCountPopup.indexOfSelectedItem,
            "runAsAccount": runAsAccountPopup.indexOfSelectedItem
        ]
    }
    
    /// Sets up change tracking for all UI controls
    private func setupChangeTracking() {
        // Text field change tracking
        displayNameTextField.target = self
        displayNameTextField.action = #selector(fieldDidChange(_:))
        
        // Text view change tracking (delegate method will handle this)
        descriptionTextView.delegate = self
        scriptContentTextView.delegate = self
        
        // Popup button change tracking
        blockExecutionNotificationsPopup.target = self
        blockExecutionNotificationsPopup.action = #selector(popupDidChange(_:))
        
        executionFrequencyPopup.target = self
        executionFrequencyPopup.action = #selector(popupDidChange(_:))
        
        retryCountPopup.target = self
        retryCountPopup.action = #selector(popupDidChange(_:))
        
        runAsAccountPopup.target = self
        runAsAccountPopup.action = #selector(popupDidChange(_:))
    }
    
    /// Compares current values with original data and updates UI accordingly
    private func trackChanges() {
        hasUnsavedChanges = false // Reset and re-evaluate
        
        // Check text fields
        checkFieldChange(displayNameTextField.stringValue, 
                        originalValue: originalData["displayName"] as? String ?? "", 
                        control: displayNameTextField)
        
        checkTextViewChange(descriptionTextView.string, 
                           originalValue: originalData["description"] as? String ?? "", 
                           textView: descriptionTextView)
        
        checkTextViewChange(scriptContentTextView.string, 
                           originalValue: originalData["scriptContent"] as? String ?? "", 
                           textView: scriptContentTextView)
        
        // Check popup buttons
        checkFieldChange(blockExecutionNotificationsPopup.indexOfSelectedItem == 1, 
                        originalValue: originalData["blockExecutionNotifications"] as? Bool ?? false, 
                        control: blockExecutionNotificationsPopup)
        
        checkFieldChange(executionFrequencyPopup.indexOfSelectedItem, 
                        originalValue: originalData["executionFrequency"] as? Int ?? 0, 
                        control: executionFrequencyPopup)
        
        checkFieldChange(retryCountPopup.indexOfSelectedItem, 
                        originalValue: originalData["retryCount"] as? Int ?? 0, 
                        control: retryCountPopup)
        
        checkFieldChange(runAsAccountPopup.indexOfSelectedItem, 
                        originalValue: originalData["runAsAccount"] as? Int ?? 0, 
                        control: runAsAccountPopup)
        
        updateSaveButtonState()
    }
    
    /// Utility to compare a field's current and original values. Highlights control if changed.
    private func checkFieldChange<T: Equatable>(_ currentValue: T, originalValue: T, control: NSControl) {
        if currentValue != originalValue {
            hasUnsavedChanges = true
            highlightField(control)
        } else {
            clearHighlight(control)
        }
    }
    
    /// Utility to compare a text view's current and original values. Highlights text view if changed.
    private func checkTextViewChange<T: Equatable>(_ currentValue: T, originalValue: T, textView: NSTextView) {
        if currentValue != originalValue {
            hasUnsavedChanges = true
            highlightTextView(textView)
        } else {
            clearHighlightTextView(textView)
        }
    }
    
    /// Highlights the given control with a yellow background to indicate change
    private func highlightField(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = NSColor.systemYellow
        } else if let popupButton = field as? NSPopUpButton {
            popupButton.layer?.backgroundColor = NSColor.systemYellow.cgColor
        }
    }
    
    /// Removes highlight from the given control (restores default background)
    private func clearHighlight(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = NSColor.controlBackgroundColor
        } else if let popupButton = field as? NSPopUpButton {
            popupButton.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    /// Highlights the given text view with a yellow border to indicate change
    private func highlightTextView(_ textView: NSTextView) {
        // Ensure the text view has a layer
        textView.wantsLayer = true
        
        // Set yellow border
        textView.layer?.borderColor = NSColor.systemYellow.cgColor
        textView.layer?.borderWidth = 2.0
        textView.layer?.cornerRadius = 4.0
    }
    
    /// Removes highlight from the given text view (restores default border)
    private func clearHighlightTextView(_ textView: NSTextView) {
        // Clear the border
        textView.layer?.borderColor = NSColor.clear.cgColor
        textView.layer?.borderWidth = 0.0
        textView.layer?.cornerRadius = 0.0
    }
    
    /// Updates the save button state based on unsaved changes
    private func updateSaveButtonState() {
        // For new scripts, always allow saving if there's content
        if isNewScript {
            let hasContent = !displayNameTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            hasUnsavedChanges = hasContent  // Set unsaved changes for new scripts with content
        }
//        } else {
//            saveButton?.isEnabled = hasUnsavedChanges
//        }
        
        // Notify parent tabbed view controller
        if let parent = parentTabViewController {
            parent.updateSaveButtonState()
        }
    }
    
    // MARK: - Change Tracking Actions
    
    @objc private func fieldDidChange(_ sender: NSTextField) {
        trackChanges()
    }
    
    @objc private func popupDidChange(_ sender: NSPopUpButton) {
        trackChanges()
    }
    
    
    @IBAction func saveChanges(_ sender: Any) {
        guard let handler = saveHandler else { return }
        var updatedScript: [String: Any] = [
            "displayName": displayNameTextField.stringValue,
            "description": descriptionTextView.string,
            "scriptContent": scriptContentTextView.string,
            "blockExecutionNotifications": blockExecutionNotificationsPopup.indexOfSelectedItem == 1,
            "executionFrequency": ScriptUtilities.executionFrequencyValue(for: executionFrequencyPopup.indexOfSelectedItem),
            "retryCount": retryCountPopup.indexOfSelectedItem > 0 ? retryCountPopup.indexOfSelectedItem : 0,
            "runAsAccount": runAsAccountPopup.titleOfSelectedItem?.lowercased() ?? "system"
        ]

        if let scriptId = scriptId {
            updatedScript["id"] = scriptId
        }

        handler(updatedScript)
        dismiss(self)
    }
    
    @IBAction func cancelChanges(_ sender: Any) {
        let parentViewController = self.parent
        parentViewController?.dismiss(self)
    }
    
    
    @IBAction func saveScriptToFile(_ sender: Any) {

        let scriptName = displayNameTextField.stringValue
        let scriptContent = scriptContentTextView.string
        
        let savePanel = NSSavePanel()
        savePanel.message = "Save Script"
        savePanel.nameFieldStringValue = scriptName + ".sh" // Default file name
        savePanel.allowedFileTypes = ["sh"] // Only allow shell script files
        
        savePanel.begin { response in
            if response == .OK, let fileURL = savePanel.url {
                do {
                    try scriptContent.write(to: fileURL, atomically: true, encoding: .utf8)
                } catch {
                    self.showError(message: "Failed to save script: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - TabbedSheetChildProtocol
    
    func getDataForSave() -> [String: Any]? {
        var scriptData: [String: Any] = [
            "displayName": displayNameTextField.stringValue,
            "description": descriptionTextView.string,
            "scriptContent": scriptContentTextView.string,
            "blockExecutionNotifications": blockExecutionNotificationsPopup.indexOfSelectedItem == 1,
            "executionFrequency": ScriptUtilities.executionFrequencyValue(for: executionFrequencyPopup.indexOfSelectedItem),
            "retryCount": retryCountPopup.indexOfSelectedItem > 0 ? retryCountPopup.indexOfSelectedItem : 0,
            "runAsAccount": runAsAccountPopup.titleOfSelectedItem?.lowercased() ?? "system"
        ]
        
        // Include script ID if this is an existing script
        if let scriptId = scriptId {
            scriptData["id"] = scriptId
        }
        
        return scriptData
    }
    
    func setInitialData(_ data: [String: Any]) {
        self.scriptData = data
        self.isNewScript = data["isNewScript"] as? Bool ?? false
        self.scriptId = data["id"] as? String

        // Initialize change tracking state
        hasUnsavedChanges = false
    }
    
    func updateFromOtherTabs(_ combinedData: [String: Any]) {
        // Script editor doesn't need to update based on other tabs currently
        // This could be used in the future if group assignments affect script properties
    }
    
    func validateData() -> String? {
        // Validate required fields
        if displayNameTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Display name is required"
        }
        
        if scriptContentTextView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Script content is required"
        }
        
        // Validate script content has a shebang for shell scripts
        let scriptContent = scriptContentTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !scriptContent.hasPrefix("#!") {
            return "Script should start with a shebang line (e.g., #!/bin/bash)"
        }
        
        return nil
    }
    
    // MARK: - Error Handling
    
    func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - NSTextViewDelegate

extension ScriptEditorViewController {
    func textDidChange(_ notification: Notification) {
        // Track changes when text views are modified
        trackChanges()
    }
}
