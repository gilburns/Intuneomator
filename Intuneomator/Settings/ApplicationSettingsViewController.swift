//
//  ApplicationSettingsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/23/25.
//

import Cocoa

/// View controller for managing application-specific settings
/// Handles cache management, logging configuration, and update preferences
class ApplicationSettingsViewController: NSViewController {
    
    // MARK: - UI Outlets
    
    @IBOutlet weak var fieldAppsToKeep: NSTextField!
    @IBOutlet weak var fieldLogsMaxAge: NSTextField!
    @IBOutlet weak var fieldLogsMaxSize: NSTextField!
    @IBOutlet weak var buttonIntuneomatorUpdateMode: NSPopUpButton!
    
    // MARK: - Properties
    
    /// Parent tabbed sheet view controller for coordination
    weak var parentTabbedSheetViewController: TabbedSheetViewController?
    
    /// Tracks whether any settings have been modified
    var hasUnsavedChanges = false
    
    /// Initial settings data
    private var initialData: [String: Any] = [:]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUpdateModePopup()
        setupTextFieldObservers()
        populateFields()
    }
    
    // MARK: - Setup Methods
    
    private func setupUpdateModePopup() {
        buttonIntuneomatorUpdateMode.removeAllItems()
        buttonIntuneomatorUpdateMode.addItems(withTitles: [
            "Automatically keep Intuneomator up-to-date",
            "Send Teams Notification when an update is available"
        ])
    }
    
    private func setupTextFieldObservers() {
        fieldAppsToKeep.delegate = self
        fieldLogsMaxAge.delegate = self
        fieldLogsMaxSize.delegate = self
    }
    
    // MARK: - Actions
    
    @IBAction func updateModeChanged(_ sender: NSPopUpButton) {
        markAsChanged()
    }
    
    // MARK: - Helper Methods
    
    private func markAsChanged() {
        hasUnsavedChanges = true
        parentTabbedSheetViewController?.updateSaveButtonState()
    }
    
    private func populateFields() {
        // Extract application settings from initial data
        if let appsToKeep = initialData["appsToKeep"] as? Int {
            fieldAppsToKeep.integerValue = appsToKeep
        }
        
        if let logsMaxAge = initialData["logsMaxAge"] as? Int {
            fieldLogsMaxAge.integerValue = logsMaxAge
        }
        
        if let logsMaxSize = initialData["logsMaxSize"] as? Int {
            fieldLogsMaxSize.integerValue = logsMaxSize
        }
        
        if let updateMode = initialData["updateMode"] as? Int {
            // Ensure the index is valid for our popup
            if updateMode >= 0 && updateMode < buttonIntuneomatorUpdateMode.numberOfItems {
                buttonIntuneomatorUpdateMode.selectItem(at: updateMode)
            }
        }
    }
}

// MARK: - TabbedSheetChildProtocol

extension ApplicationSettingsViewController: TabbedSheetChildProtocol {
    
    func getDataForSave() -> [String: Any]? {
        var data: [String: Any] = [:]
        
        data["appsToKeep"] = fieldAppsToKeep.integerValue
        data["logsMaxAge"] = fieldLogsMaxAge.integerValue
        data["logsMaxSize"] = fieldLogsMaxSize.integerValue
        
        data["updateMode"] = buttonIntuneomatorUpdateMode.indexOfSelectedItem
        
        return data
    }
    
    func setInitialData(_ data: [String: Any]) {
        self.initialData = data
        if isViewLoaded {
            populateFields()
        }
    }
    
    func updateFromOtherTabs(_ combinedData: [String: Any]) {
        // Application settings typically don't depend on other tabs
    }
    
    func validateData() -> String? {
        // Validate apps to keep
        let appsToKeep = fieldAppsToKeep.integerValue
        if appsToKeep < 1 || appsToKeep > 99 {
            return "Apps to keep must be between 1 and 99"
        }
        
        // Validate logs max age
        let logsMaxAge = fieldLogsMaxAge.integerValue
        if logsMaxAge < 1 || logsMaxAge > 365 {
            return "Logs max age must be between 1 and 365 days"
        }
        
        // Validate logs max size
        let logsMaxSize = fieldLogsMaxSize.integerValue
        if logsMaxSize < 1 || logsMaxSize > 1000 {
            return "Logs max size must be between 1 and 1000 MB"
        }
        
        return nil
    }
}

// MARK: - NSTextFieldDelegate

extension ApplicationSettingsViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        markAsChanged()
    }
}
