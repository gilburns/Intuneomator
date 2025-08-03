//
//  AzureStorageConfigurationEditorViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/23/25.
//

import Cocoa

/// View controller for editing individual Azure Storage configurations
/// Provides a form interface for configuring storage account details and authentication
class AzureStorageConfigurationEditorViewController: NSViewController {
    
    // MARK: - UI Outlets
    
    @IBOutlet weak var fieldName: NSTextField!
    @IBOutlet weak var fieldDescription: NSTextField!
    @IBOutlet weak var fieldAccountName: NSTextField!
    @IBOutlet weak var fieldContainerName: NSTextField!
    @IBOutlet weak var popupAuthMethod: NSPopUpButton!
    @IBOutlet weak var fieldAccountKey: NSSecureTextField!
    @IBOutlet weak var fieldSASToken: NSSecureTextField!
    @IBOutlet weak var saveButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var testButton: NSButton!
    
    // MARK: - Cleanup Configuration Outlets
    @IBOutlet weak var checkboxCleanupEnabled: NSButton!
    @IBOutlet weak var fieldMaxFileAgeInDays: NSTextField!
    @IBOutlet weak var labelCleanupSummary: NSTextField!
    
    // MARK: - Labels for conditional display
    @IBOutlet weak var labelAccountKey: NSTextField!
    @IBOutlet weak var labelSASToken: NSTextField!
    
    // MARK: - Properties
    
    /// Whether this is a new configuration or editing existing
    var isNewConfiguration = true
    
    /// Configuration data for editing
    var configurationData: [String: Any] = [:]
    
    /// Callback for when configuration is saved
    var saveHandler: (([String: Any]) -> Void)?
    
    /// List of existing configuration names for validation
    var existingConfigurationNames: [String] = []
    
    /// Original configuration name (for updates)
    private var originalConfigurationName: String?
    
    /// Tracks validation state
    private var isValid = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAuthMethodPopup()
        setupValidation()
        populateFields()
        updateAuthMethodFields()
    }
    
    // MARK: - Setup Methods
    
    private func setupAuthMethodPopup() {
        popupAuthMethod.removeAllItems()
        popupAuthMethod.addItems(withTitles: [
            "Storage Key",
            "SAS Token"
        ])
        popupAuthMethod.target = self
        popupAuthMethod.action = #selector(authMethodChanged(_:))
    }
    
    private func setupValidation() {
        // Add observers for text field changes
        let textFields = [fieldName, fieldDescription, fieldAccountName, fieldContainerName, 
                         fieldAccountKey, fieldSASToken,
                         fieldMaxFileAgeInDays]
        
        for textField in textFields {
            textField?.delegate = self
        }
        
        // Setup cleanup configuration
        setupCleanupConfiguration()
    }
    
    private func setupCleanupConfiguration() {
        checkboxCleanupEnabled?.target = self
        checkboxCleanupEnabled?.action = #selector(cleanupEnabledChanged(_:))
        
        // Set default values
        checkboxCleanupEnabled?.state = .off
        fieldMaxFileAgeInDays?.isEnabled = false
        fieldMaxFileAgeInDays?.stringValue = "30"
        updateCleanupSummary()
    }
    
    @objc private func cleanupEnabledChanged(_ sender: NSButton) {
        let isEnabled = sender.state == .on
        fieldMaxFileAgeInDays?.isEnabled = isEnabled
        updateCleanupSummary()
        validateForm()
    }
    
    private func updateCleanupSummary() {
        let isEnabled = checkboxCleanupEnabled?.state == .on
        
        if isEnabled {
            if let ageText = fieldMaxFileAgeInDays?.stringValue,
               let age = Int(ageText), age > 0 {
                labelCleanupSummary?.stringValue = "Files older than \(age) day\(age == 1 ? "" : "s") will be automatically deleted"
                labelCleanupSummary?.textColor = .systemBlue
            } else {
                labelCleanupSummary?.stringValue = "Please specify a valid number of days"
                labelCleanupSummary?.textColor = .systemOrange
            }
        } else {
            labelCleanupSummary?.stringValue = "Files will be kept forever (no automatic cleanup)"
            labelCleanupSummary?.textColor = .secondaryLabelColor
        }
    }
    
    private func populateFields() {
        if !isNewConfiguration {
            let configName = configurationData["name"] as? String ?? ""
            fieldName.stringValue = configName
            originalConfigurationName = configName
            fieldDescription.stringValue = configurationData["description"] as? String ?? ""
            fieldAccountName.stringValue = configurationData["accountName"] as? String ?? ""
            fieldContainerName.stringValue = configurationData["containerName"] as? String ?? ""
            
            // Set authentication method
            if let authMethod = configurationData["authMethod"] as? String {
                switch authMethod.lowercased() {
                case "storage key":
                    popupAuthMethod.selectItem(at: 0)
                case "sas token":
                    popupAuthMethod.selectItem(at: 1)
                case "azure ad oauth":
                    popupAuthMethod.selectItem(at: 2)
                default:
                    popupAuthMethod.selectItem(at: 0)
                }
            }
            
            // Populate cleanup configuration
            let cleanupEnabled = configurationData["cleanupEnabled"] as? Bool ?? false
            checkboxCleanupEnabled?.state = cleanupEnabled ? .on : .off
            
            if let maxAge = configurationData["maxFileAgeInDays"] as? Int, maxAge > 0 {
                fieldMaxFileAgeInDays?.stringValue = "\(maxAge)"
            } else {
                fieldMaxFileAgeInDays?.stringValue = "30"
            }
            
            fieldMaxFileAgeInDays?.isEnabled = cleanupEnabled
            
            // Populate sensitive fields when editing existing configurations
            // This allows users to make other changes without re-entering credentials
            if let accountKey = configurationData["accountKey"] as? String, !accountKey.isEmpty {
                fieldAccountKey.stringValue = accountKey
            }
            
            if let sasToken = configurationData["sasToken"] as? String, !sasToken.isEmpty {
                fieldSASToken.stringValue = sasToken
            }
        }
        
        updateCleanupSummary()
        validateForm()
    }
    
    @objc private func authMethodChanged(_ sender: NSPopUpButton) {
        updateAuthMethodFields()
        validateForm()
    }
    
    private func updateAuthMethodFields() {
        let selectedIndex = popupAuthMethod.indexOfSelectedItem
        
        // Hide all auth-specific fields first
        hideAllAuthFields()
        
        // Show relevant fields based on selection
        switch selectedIndex {
        case 0: // Storage Key
            showStorageKeyFields()
        case 1: // SAS Token
            showSASTokenFields()
        default:
            break
        }
    }
    
    private func hideAllAuthFields() {
        let fields = [fieldAccountKey, fieldSASToken]
        let labels = [labelAccountKey, labelSASToken]
        
        for field in fields {
            field?.isHidden = true
        }
        for label in labels {
            label?.isHidden = true
        }
    }
    
    private func showStorageKeyFields() {
        fieldAccountKey.isHidden = false
        labelAccountKey.isHidden = false
    }
    
    private func showSASTokenFields() {
        fieldSASToken.isHidden = false
        labelSASToken.isHidden = false
    }
        
    // MARK: - Actions
    
    @IBAction func saveConfiguration(_ sender: NSButton) {
        guard validateForm() else {
            return
        }
        
        let configuration = buildConfigurationData()
        
        saveButton.isEnabled = false
        saveButton.title = "Saving..."
        
        // Save via XPC
        if isNewConfiguration {
            XPCManager.shared.createAzureStorageConfiguration(configuration) { [weak self] success in
                self?.handleSaveResult(success ?? false, configuration: configuration)
            }
        } else {
            XPCManager.shared.updateAzureStorageConfiguration(configuration) { [weak self] success in
                self?.handleSaveResult(success ?? false, configuration: configuration)
            }
        }
    }
    
    @IBAction func cancelConfiguration(_ sender: NSButton) {
        dismiss(self)
    }
    
    @IBAction func testConfiguration(_ sender: NSButton) {
        guard validateForm() else {
            return
        }
        
        let configuration = buildConfigurationData()
        
        testButton.isEnabled = false
        testButton.title = "Testing..."
        
        XPCManager.shared.testAzureStorageConfigurationDirect(configuration) { [weak self] success in
            DispatchQueue.main.async {
                self?.testButton.isEnabled = true
                self?.testButton.title = "Test"
                
                let alert = NSAlert()
                if let success = success, success {
                    alert.messageText = "Connection Successful"
                    alert.informativeText = "Successfully connected to Azure Storage with the provided configuration."
                    alert.alertStyle = .informational
                } else {
                    alert.messageText = "Connection Failed"
                    alert.informativeText = "Unable to connect to Azure Storage. Please check your configuration and try again."
                    alert.alertStyle = .warning
                }
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func buildConfigurationData() -> [String: Any] {
        var data: [String: Any] = [:]
        
        data["name"] = fieldName.stringValue
        data["description"] = fieldDescription.stringValue
        data["accountName"] = fieldAccountName.stringValue
        data["containerName"] = fieldContainerName.stringValue
        
        let authMethodIndex = popupAuthMethod.indexOfSelectedItem
        switch authMethodIndex {
        case 0: // Storage Key
            data["authMethod"] = "storageKey"
            data["accountKey"] = fieldAccountKey.stringValue
        case 1: // SAS Token
            data["authMethod"] = "sasToken"
            data["sasToken"] = fieldSASToken.stringValue
        default:
            break
        }
        
        // Add cleanup configuration
        let cleanupEnabled = checkboxCleanupEnabled?.state == .on
        data["cleanupEnabled"] = cleanupEnabled
        
        if cleanupEnabled, let ageText = fieldMaxFileAgeInDays?.stringValue, let age = Int(ageText), age > 0 {
            data["maxFileAgeInDays"] = age
        }
        
        return data
    }
    
    private func handleSaveResult(_ success: Bool, configuration: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.saveButton.isEnabled = true
            self?.saveButton.title = "Save"
            
            if success {
                self?.saveHandler?(configuration)
                self?.dismiss(self)
            } else {
                let alert = NSAlert()
                alert.messageText = "Save Failed"
                alert.informativeText = "Unable to save the Azure Storage configuration. Please try again."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    @discardableResult
    private func validateForm() -> Bool {
        var isValid = true
        var errorMessage = ""
        
        // Validate required fields
        let configName = fieldName.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if configName.isEmpty {
            isValid = false
            errorMessage = "Configuration name is required"
        } else {
            // Check for duplicate names (case-insensitive)
            let lowercasedName = configName.lowercased()
            
            if isNewConfiguration {
                // For new configurations, check against all existing names
                if let conflictingName = existingConfigurationNames.first(where: { $0.lowercased() == lowercasedName }) {
                    isValid = false
                    errorMessage = "Name conflicts with existing configuration '\(conflictingName)'. Please choose a unique name."
                }
            } else {
                // For updates, check against all existing names except the original
                let otherNames = existingConfigurationNames.filter { $0 != originalConfigurationName }
                if let conflictingName = otherNames.first(where: { $0.lowercased() == lowercasedName }) {
                    isValid = false
                    errorMessage = "Name conflicts with existing configuration '\(conflictingName)'. Please choose a unique name."
                }
            }
        }
        
        if fieldAccountName.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            isValid = false
            errorMessage = "Storage account name is required"
        }
        
        if fieldContainerName.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            isValid = false
            errorMessage = "Container name is required"
        }
        
        // Validate auth-specific fields
        let authMethodIndex = popupAuthMethod.indexOfSelectedItem
        switch authMethodIndex {
        case 0: // Storage Key
            if fieldAccountKey.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isValid = false
                errorMessage = "Storage account key is required"
            }
        case 1: // SAS Token
            if fieldSASToken.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isValid = false
                errorMessage = "SAS token is required"
            }
        case 2: // Azure AD OAuth
            // Note: Azure AD authentication is not yet implemented
            isValid = false
            errorMessage = "Azure AD authentication is not yet implemented. Please use Storage Key or SAS Token authentication."
        default:
            break
        }
        
        // Validate cleanup configuration if enabled
        if checkboxCleanupEnabled?.state == .on {
            let ageText = fieldMaxFileAgeInDays?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if ageText.isEmpty {
                isValid = false
                errorMessage = "Please specify the maximum file age in days for cleanup"
            } else if let age = Int(ageText) {
                if age <= 0 {
                    isValid = false
                    errorMessage = "Maximum file age must be greater than 0"
                } else if age > 3650 { // ~10 years
                    isValid = false
                    errorMessage = "Maximum file age cannot exceed 3650 days (10 years)"
                }
            } else {
                isValid = false
                errorMessage = "Maximum file age must be a valid number"
            }
        }
        
        self.isValid = isValid
        saveButton.isEnabled = isValid
        testButton.isEnabled = isValid
        
        // Display validation error if there is one
        if !isValid && !errorMessage.isEmpty {
            // Use cleanup summary label to show validation errors prominently
            labelCleanupSummary?.stringValue = errorMessage
            labelCleanupSummary?.textColor = .systemRed
        } else if isValid {
            // Update cleanup summary if validation passes
            updateCleanupSummary()
        }
        
        return isValid
    }
}

// MARK: - NSTextFieldDelegate

extension AzureStorageConfigurationEditorViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        // Update cleanup summary if the age field changed
        if let textField = obj.object as? NSTextField, textField == fieldMaxFileAgeInDays {
            updateCleanupSummary()
        }
        validateForm()
    }
}
