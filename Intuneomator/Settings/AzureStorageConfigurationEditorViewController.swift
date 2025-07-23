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
    @IBOutlet weak var fieldSASToken: NSTextField!
    @IBOutlet weak var fieldTenantID: NSTextField!
    @IBOutlet weak var fieldClientID: NSTextField!
    @IBOutlet weak var fieldClientSecret: NSSecureTextField!
    @IBOutlet weak var saveButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var testButton: NSButton!
    
    // MARK: - Labels for conditional display
    @IBOutlet weak var labelAccountKey: NSTextField!
    @IBOutlet weak var labelSASToken: NSTextField!
    @IBOutlet weak var labelTenantID: NSTextField!
    @IBOutlet weak var labelClientID: NSTextField!
    @IBOutlet weak var labelClientSecret: NSTextField!
    
    // MARK: - Properties
    
    /// Whether this is a new configuration or editing existing
    var isNewConfiguration = true
    
    /// Configuration data for editing
    var configurationData: [String: Any] = [:]
    
    /// Callback for when configuration is saved
    var saveHandler: (([String: Any]) -> Void)?
    
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
            "SAS Token",
            "Azure AD OAuth"
        ])
        popupAuthMethod.target = self
        popupAuthMethod.action = #selector(authMethodChanged(_:))
    }
    
    private func setupValidation() {
        // Add observers for text field changes
        let textFields = [fieldName, fieldDescription, fieldAccountName, fieldContainerName, 
                         fieldAccountKey, fieldSASToken, fieldTenantID, fieldClientID, fieldClientSecret]
        
        for textField in textFields {
            textField?.delegate = self
        }
    }
    
    private func populateFields() {
        if !isNewConfiguration {
            fieldName.stringValue = configurationData["name"] as? String ?? ""
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
            
            // Note: We don't populate sensitive fields like keys/tokens for security
            // They would need to be re-entered when editing
        }
        
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
        case 2: // Azure AD OAuth
            showAzureADFields()
        default:
            break
        }
    }
    
    private func hideAllAuthFields() {
        let fields = [fieldAccountKey, fieldSASToken, fieldTenantID, fieldClientID, fieldClientSecret]
        let labels = [labelAccountKey, labelSASToken, labelTenantID, labelClientID, labelClientSecret]
        
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
    
    private func showAzureADFields() {
        fieldTenantID.isHidden = false
        fieldClientID.isHidden = false
        fieldClientSecret.isHidden = false
        labelTenantID.isHidden = false
        labelClientID.isHidden = false
        labelClientSecret.isHidden = false
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
        case 2: // Azure AD OAuth
            data["authMethod"] = "azureAD"
            data["tenantId"] = fieldTenantID.stringValue
            data["clientId"] = fieldClientID.stringValue
            data["clientSecret"] = fieldClientSecret.stringValue
        default:
            break
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
        if fieldName.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            isValid = false
            errorMessage = "Configuration name is required"
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
        
        self.isValid = isValid
        saveButton.isEnabled = isValid
        testButton.isEnabled = isValid
        
        return isValid
    }
}

// MARK: - NSTextFieldDelegate

extension AzureStorageConfigurationEditorViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        validateForm()
    }
}
