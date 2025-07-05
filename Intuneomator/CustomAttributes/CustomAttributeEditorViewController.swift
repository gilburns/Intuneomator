//
//  CustomAttributeEditorViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/23/25.
//

import Cocoa

class CustomAttributeEditorViewController: NSViewController, TabbedSheetChildProtocol, NSTextViewDelegate {
    @IBOutlet weak var displayNameTextField: NSTextField!
    @IBOutlet weak var descriptionTextView: NSTextView!
    @IBOutlet weak var scriptContentTextView: NSTextView!
    
    
    @IBOutlet weak var runAsAccountPopup: NSPopUpButton!
    @IBOutlet weak var customAttributeTypePopup: NSPopUpButton!
    
    @IBOutlet weak var scriptID: NSTextField!
    
    @IBOutlet weak var pendingImportLabel: NSTextField!
    @IBOutlet weak var importScript: NSButton!
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
    
    override func viewWillAppear() {
        super.viewWillAppear()

        populateFields()

        // Lock immutable fields if editing an existing attribute
        let editingExisting = !isNewScript
        displayNameTextField.isEnabled = !editingExisting
        customAttributeTypePopup.isEnabled = !editingExisting
        runAsAccountPopup.isEnabled = !editingExisting

        
        let effectView = NSVisualEffectView(frame: view.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.blendingMode = .withinWindow
        effectView.material = .windowBackground
        effectView.state = .active

        self.view.addSubview(effectView, positioned: .below, relativeTo: nil)

        if let sheetWindow = view.window {
            sheetWindow.minSize = NSSize(width: 700, height: 650) // Set minimum size
        }
    }

    func setupPopups() {
        runAsAccountPopup.removeAllItems()
        runAsAccountPopup.addItems(withTitles: ["System", "User"])
        
        customAttributeTypePopup.removeAllItems()
        customAttributeTypePopup.addItems(withTitles: ["String", "Integer", "Date"])
        customAttributeTypePopup.selectItem(withTitle: "String") // Default
    }
    
    func populateFields() {
        guard let script = scriptData else { return }
        
        scriptId = script["id"] as? String
        scriptID.stringValue = scriptId ?? ""
        
        isNewScript = script["isNewScript"] as? Bool ?? false

        displayNameTextField.stringValue = script["displayName"] as? String ?? ""
        descriptionTextView.string = script["description"] as? String ?? ""
        
        //        if let tagIds = script["roleScopeTagIds"] as? [String] {
        //            roleScopeTagIdsTextField.stringValue = tagIds.joined(separator: ",")
        //        } else {
        //            roleScopeTagIdsTextField.stringValue = ""
        //        }

        if isNewScript, let content = script["scriptContent"] as? String {
            scriptContentTextView.string = content
            scriptContentTextView.textColor = NSColor.systemOrange
            pendingImportLabel.isHidden = false
            importScript.isHidden = true
        } else if let content = script["scriptContent"] as? String {
            if let decodedData = Data(base64Encoded: content),
               let decodedString = String(data: decodedData, encoding: .utf8) {
                scriptContentTextView.string = decodedString
            } else {
                scriptContentTextView.string = content
            }
            scriptContentTextView.textColor = NSColor.labelColor
            pendingImportLabel.isHidden = true
            importScript.isHidden = false
        } else {
            scriptContentTextView.string = "Failed to load script"
            scriptContentTextView.textColor = NSColor.systemRed
            pendingImportLabel.isHidden = true
            importScript.isHidden = false
        }
        
        let runAsAccountValue = script["runAsAccount"] as? String ?? "system"
        runAsAccountPopup.selectItem(withTitle: runAsAccountValue.capitalized)
        
        if let customAttrType = script["customAttributeType"] as? String {
            switch customAttrType {
            case "string":
                customAttributeTypePopup.selectItem(withTitle: "String")
            case "integer":
                customAttributeTypePopup.selectItem(withTitle: "Integer")
            case "dateTime":
                customAttributeTypePopup.selectItem(withTitle: "Date")
            default:
                customAttributeTypePopup.selectItem(withTitle: "String")
            }
        } else {
            customAttributeTypePopup.selectItem(withTitle: "String") // Default
        }
        
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
            "runAsAccount": runAsAccountPopup.indexOfSelectedItem,
            "customAttributeType": customAttributeTypePopup.indexOfSelectedItem
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
        runAsAccountPopup.target = self
        runAsAccountPopup.action = #selector(popupDidChange(_:))
        customAttributeTypePopup.target = self
        customAttributeTypePopup.action = #selector(popupDidChange(_:))
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
        checkFieldChange(customAttributeTypePopup.indexOfSelectedItem,
                        originalValue: originalData["customAttributeType"] as? Int ?? 0,
                        control: customAttributeTypePopup)

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
        // For existing scripts, hasUnsavedChanges is already set by trackChanges()
        
        // Notify parent tabbed view controller
        if let parent = parentTabViewController {
            Logger.debug("Parent tabbed view controller exists, hasUnsavedChanges: \(hasUnsavedChanges)", category: .core, toUserDirectory: true)
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
            "customAttributeType": selectedCustomAttributeType(),
            "runAsAccount": runAsAccountPopup.titleOfSelectedItem?.lowercased() ?? "system",
            "roleScopeTagIds": []
        ]

        // Revisit this line later when implementing roleScopeTagIds support
        // updatedScript["roleScopeTagIds"] = roleScopeTagIdsTextField.stringValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        if let scriptId = scriptId {
            updatedScript["id"] = scriptId
        }

        handler(updatedScript)
        dismiss(self)
    }
        
    @IBAction func saveScriptToFile(_ sender: Any) {

        let scriptName = displayNameTextField.stringValue
        let scriptContent = scriptContentTextView.string
        
        let savePanel = NSSavePanel()
        savePanel.message = "Save Script"
        savePanel.nameFieldStringValue = scriptName + ".sh"
        savePanel.allowedContentTypes = [.text, .shellScript, .sourceCode]

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
            "runAsAccount": runAsAccountPopup.titleOfSelectedItem?.lowercased() ?? "system",
            "customAttributeType": selectedCustomAttributeType(),
            "roleScopeTagIds": []
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

    // MARK: - Actions
    
    @IBAction func importScriptClicked(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.message = "Select a script file to import."
        openPanel.allowedFileTypes = ["sh", "bash", "zsh", "txt"]
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { [weak self] response in
            guard response == .OK, let fileURL = openPanel.url, let self = self else { return }
            
            do {
                // Load script contents
                let scriptContent = try String(contentsOf: fileURL, encoding: .utf8)
                self.scriptContentTextView.string = scriptContent
                self.scriptContentTextView.textColor = NSColor.systemOrange
                
                // Set filename
//                self.fileNameTextField.stringValue = fileURL.lastPathComponent
            } catch {
                self.showErrorAlert("Failed to import script", info: error.localizedDescription)
            }
        }
    }
            
    // MARK: - Helper
    
    func selectedCustomAttributeType() -> String {
        switch customAttributeTypePopup.titleOfSelectedItem {
        case "Integer":
            return "integer"
        case "Date":
            return "dateTime"
        default:
            return "string"
        }
    }
    
    // MARK: - Error Handling
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
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}


// MARK: - NSTextViewDelegate

extension CustomAttributeEditorViewController {
    func textDidChange(_ notification: Notification) {
        // Track changes when text views are modified
        trackChanges()
    }
}


