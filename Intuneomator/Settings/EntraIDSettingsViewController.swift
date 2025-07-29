//
//  EntraIDSettingsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/23/25.
//

import Cocoa

/// View controller for managing Microsoft Entra ID authentication settings
/// Handles tenant configuration, authentication methods, and certificate management
class EntraIDSettingsViewController: NSViewController {
    
    // MARK: - UI Outlets
    
    @IBOutlet weak var fieldTenantID: NSTextField!
    @IBOutlet weak var fieldClientID: NSTextField!
    @IBOutlet weak var fieldClientSecret: NSTextField!
    @IBOutlet weak var fieldCertificateThumbprint: NSTextField!
    @IBOutlet weak var fieldCertificateExpiration: NSTextField!
    @IBOutlet weak var fieldSecretExpiration: NSTextField!
    @IBOutlet weak var radioButtonCertificate: NSButton!
    @IBOutlet weak var radioButtonSecret: NSButton!
    @IBOutlet weak var buttonTestConnection: NSButton!
    @IBOutlet weak var buttonImportCertificate: NSButton!
    @IBOutlet weak var buttonImportSecret: NSButton!
    
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
        setupAuthenticationMethodRadios()
        setupObservers()
        populateFields()
    }
    
    // MARK: - Setup Methods
    
    private func setupAuthenticationMethodRadios() {
        // Set up radio button behavior
        radioButtonCertificate.target = self
        radioButtonCertificate.action = #selector(authenticationMethodChanged(_:))
        radioButtonSecret.target = self
        radioButtonSecret.action = #selector(authenticationMethodChanged(_:))
    }
    
    private func setupObservers() {
        fieldTenantID.delegate = self
        fieldClientID.delegate = self
        fieldClientSecret.delegate = self
        fieldCertificateThumbprint.delegate = self
    }
    
    // MARK: - Actions
    
    @objc private func authenticationMethodChanged(_ sender: NSButton) {
        // Handle radio button mutual exclusion
        if sender == radioButtonCertificate {
            radioButtonSecret.state = .off
        } else if sender == radioButtonSecret {
            radioButtonCertificate.state = .off
        }
        
        updateAuthenticationControlsState()
        markAsChanged()
    }
    
    @IBAction func testConnectionClicked(_ sender: NSButton) {
        performConnectionTest()
    }
    
    @IBAction func importCertificateClicked(_ sender: NSButton) {
        selectP12File()
    }
    
    @IBAction func importSecretClicked(_ sender: NSButton) {
        presentSecretImportDialog()
    }
    
    // MARK: - Certificate and Secret Import Methods
    
    /// Opens a file picker to select a .p12 certificate file for import.
    private func selectP12File() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [ .p12 ]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.title = "Select a .p12 File"
        openPanel.message = "Select a .p12 File"
        
        openPanel.begin { result in
            if result == .OK, let selectedFileURL = openPanel.url {
                self.requestPassphrase(for: selectedFileURL)
            }
        }
    }
    
    /// Prompts the user to enter the passphrase for a selected .p12 file.
    private func requestPassphrase(for fileURL: URL) {
        let alert = NSAlert()
        alert.messageText = "Enter Passphrase"
        alert.informativeText = "Enter the passphrase for the selected .p12 file."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        // Secure text field for passphrase
        let secureTextField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        alert.accessoryView = secureTextField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let passphrase = secureTextField.stringValue
            processP12File(fileURL: fileURL, passphrase: passphrase)
        }
    }
    
    
    /// Processes and imports the selected .p12 certificate file.
    private func processP12File(fileURL: URL, passphrase: String) {
        do {
            let p12Data = try Data(contentsOf: fileURL)
            XPCManager.shared.importP12Certificate(p12Data: p12Data, passphrase: passphrase) { [weak self] success in
                DispatchQueue.main.async {
                    if let success = success, success {
                        Logger.info("Successfully imported .p12 certificate", category: .core, toUserDirectory: true)
                        
                        // Refresh certificate details from daemon
                        self?.refreshCertificateDetails()
                        
                        // Switch to certificate authentication
                        self?.radioButtonCertificate.state = .on
                        self?.radioButtonSecret.state = .off
                        self?.updateAuthenticationControlsState()
                        self?.markAsChanged()
                        
                        let alert = NSAlert()
                        alert.messageText = "Certificate Imported Successfully"
                        alert.informativeText = "The certificate has been imported and is ready for use."
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    } else {
                        Logger.error("Failed to import .p12 certificate", category: .core, toUserDirectory: true)
                        
                        let alert = NSAlert()
                        alert.messageText = "Certificate Import Failed"
                        alert.informativeText = "Failed to import the certificate. Please check the file and passphrase."
                        alert.alertStyle = .critical
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        } catch {
            Logger.error("Failed to read .p12 file: \(error)", category: .core, toUserDirectory: true)
            
            let alert = NSAlert()
            alert.messageText = "File Read Error"
            alert.informativeText = "Failed to read the selected .p12 file: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    /// Presents a dialog for entering client secret details
    private func presentSecretImportDialog() {
        let alert = NSAlert()
        alert.messageText = "Import Client Secret"
        alert.informativeText = "Enter the client secret and its expiration date."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")
        
        // Create a view for secret input
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
        
        // Secret text field
        let secretLabel = NSTextField(labelWithString: "Client Secret:")
        secretLabel.frame = NSRect(x: 0, y: 50, width: 100, height: 20)
        containerView.addSubview(secretLabel)
        
        let secretField = NSSecureTextField(frame: NSRect(x: 105, y: 50, width: 195, height: 20))
        containerView.addSubview(secretField)
        
        // Expiration date field
        let expirationLabel = NSTextField(labelWithString: "Expires:")
        expirationLabel.frame = NSRect(x: 0, y: 20, width: 100, height: 20)
        containerView.addSubview(expirationLabel)
        
        let expirationField = NSTextField(frame: NSRect(x: 105, y: 20, width: 195, height: 20))
        expirationField.placeholderString = "YYYY-MM-DD (optional)"
        containerView.addSubview(expirationField)
        
        alert.accessoryView = containerView
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let clientSecret = secretField.stringValue
            let expirationString = expirationField.stringValue
            
            guard !clientSecret.isEmpty else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Invalid Input"
                errorAlert.informativeText = "Client secret cannot be empty."
                errorAlert.alertStyle = .warning
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
                return
            }
            
            processClientSecret(secret: clientSecret, expirationString: expirationString)
        }
    }
    
    /// Processes and imports the client secret
    private func processClientSecret(secret: String, expirationString: String) {
        // Parse expiration date if provided
        var expirationDate: Date?
        if !expirationString.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            expirationDate = formatter.date(from: expirationString)
        }
        
        XPCManager.shared.importEntraIDSecretKey(secretKey: secret) { [weak self] success in
            DispatchQueue.main.async {
                if let success = success, success {
                    Logger.info("Successfully imported Entra ID secret key", category: .core, toUserDirectory: true)
                    
                    // Update UI with secret details
                    self?.fieldClientSecret.stringValue = secret
                    if let expDate = expirationDate {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        self?.fieldSecretExpiration.stringValue = formatter.string(from: expDate)
                        
                        // Store expiration date via XPC if provided
                        XPCManager.shared.setSecretExpirationDate(expDate) { _ in }
                    }
                    
                    // Switch to secret authentication
                    self?.radioButtonSecret.state = .on
                    self?.radioButtonCertificate.state = .off
                    self?.updateAuthenticationControlsState()
                    self?.markAsChanged()
                    
                    let alert = NSAlert()
                    alert.messageText = "Client Secret Imported Successfully"
                    alert.informativeText = "The client secret has been imported and is ready for use."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                } else {
                    Logger.error("Failed to import Entra ID secret key", category: .core, toUserDirectory: true)
                    
                    let alert = NSAlert()
                    alert.messageText = "Secret Import Failed"
                    alert.informativeText = "Failed to import the client secret. Please try again."
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    /// Refreshes certificate details from the daemon after import
    private func refreshCertificateDetails() {
        // Get certificate thumbprint
        XPCManager.shared.getCertThumbprint { [weak self] thumbprint in
            DispatchQueue.main.async {
                self?.fieldCertificateThumbprint.stringValue = thumbprint ?? ""
            }
        }
        
        // Get certificate expiration
        XPCManager.shared.getCertExpiration { [weak self] expirationDate in
            DispatchQueue.main.async {
                if let expDate = expirationDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    self?.fieldCertificateExpiration.stringValue = formatter.string(from: expDate)
                } else {
                    self?.fieldCertificateExpiration.stringValue = ""
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateAuthenticationControlsState() {
        let isCertificateAuth = radioButtonCertificate.state == .on
        
        // Enable/disable fields based on authentication method
        fieldClientSecret.isEnabled = !isCertificateAuth
        fieldSecretExpiration.isEnabled = !isCertificateAuth
        fieldCertificateThumbprint.isEnabled = isCertificateAuth
        fieldCertificateExpiration.isEnabled = isCertificateAuth
        
        // Enable/disable import buttons based on authentication method
        buttonImportCertificate?.isEnabled = isCertificateAuth
        buttonImportSecret?.isEnabled = !isCertificateAuth
        
        // Update visual appearance
        fieldClientSecret.textColor = isCertificateAuth ? .disabledControlTextColor : .controlTextColor
        fieldCertificateThumbprint.textColor = isCertificateAuth ? .controlTextColor : .disabledControlTextColor
        
        // Update test connection button state
        updateTestConnectionButtonState()
    }
    
    private func markAsChanged() {
        hasUnsavedChanges = true
        parentTabbedSheetViewController?.updateSaveButtonState()
    }
    
    /// Enables or disables the "Test Connection" button based on whether required credential fields are populated.
    private func updateTestConnectionButtonState() {
        guard let tenantIDField = fieldTenantID,
              let clientIDField = fieldClientID,
              let secretField = fieldClientSecret,
              let thumbprintField = fieldCertificateThumbprint,
              let certRadio = radioButtonCertificate,
              let testButton = buttonTestConnection else {
            return
        }
        
        let tenantID = tenantIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientID = clientIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if required basic fields are filled
        guard !tenantID.isEmpty && !clientID.isEmpty else {
            testButton.isEnabled = false
            return
        }
        
        // Check authentication method specific requirements
        if certRadio.state == .on {
            // Certificate authentication - need thumbprint
            let thumbprint = thumbprintField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            testButton.isEnabled = !thumbprint.isEmpty
        } else {
            // Secret authentication - need client secret
            let clientSecret = secretField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            testButton.isEnabled = !clientSecret.isEmpty
        }
    }
    
    private func populateFields() {
        // Extract Entra ID settings from initial data
        if let tenantID = initialData["tenantID"] as? String {
            fieldTenantID.stringValue = tenantID
        }
        
        if let clientID = initialData["clientID"] as? String {
            fieldClientID.stringValue = clientID
        }
        
        if let clientSecret = initialData["clientSecret"] as? String {
            fieldClientSecret.stringValue = clientSecret
        }
        
        if let certificateThumbprint = initialData["certificateThumbprint"] as? String {
            fieldCertificateThumbprint.stringValue = certificateThumbprint
        }
        
        if let certificateExpiration = initialData["certificateExpiration"] as? String {
            fieldCertificateExpiration.stringValue = certificateExpiration
        }
        
        if let secretExpiration = initialData["secretExpiration"] as? String {
            fieldSecretExpiration.stringValue = secretExpiration
        }
        
        if let authMethod = initialData["authenticationMethod"] as? String {
            if authMethod == "certificate" {
                radioButtonCertificate.state = .on
                radioButtonSecret.state = .off
            } else {
                radioButtonCertificate.state = .off
                radioButtonSecret.state = .on
            }
        }
        
        updateAuthenticationControlsState()
        updateTestConnectionButtonState()
    }
    
    private func performConnectionTest() {
        buttonTestConnection.isEnabled = false
        buttonTestConnection.title = "Testing..."
        
        // Collect current settings for testing
        let testData = getDataForSave() ?? [:]
        
        // Test connection via XPC
        XPCManager.shared.testEntraIDConnection(with: testData) { [weak self] success in
            DispatchQueue.main.async {
                self?.buttonTestConnection.isEnabled = true
                self?.buttonTestConnection.title = "Test Connection"
                
                let alert = NSAlert()
                if let success = success, success {
                    alert.messageText = "Connection Successful"
                    alert.informativeText = "Successfully connected to Microsoft Entra ID with the provided credentials."
                    alert.alertStyle = .informational
                } else {
                    alert.messageText = "Connection Failed"
                    alert.informativeText = "Unable to connect to Microsoft Entra ID. Please check your credentials and try again."
                    alert.alertStyle = .warning
                }
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}

// MARK: - TabbedSheetChildProtocol

extension EntraIDSettingsViewController: TabbedSheetChildProtocol {
    
    func getDataForSave() -> [String: Any]? {
        // Ensure view is loaded before accessing outlets
        guard isViewLoaded,
              let tenantIDField = fieldTenantID,
              let clientIDField = fieldClientID,
              let secretField = fieldClientSecret,
              let thumbprintField = fieldCertificateThumbprint,
              let certExpirationField = fieldCertificateExpiration,
              let secretExpirationField = fieldSecretExpiration,
              let certRadio = radioButtonCertificate else {
            // Return nil if view isn't loaded yet - don't contribute to save data
            return nil
        }
        
        var data: [String: Any] = [:]
        
        data["tenantID"] = tenantIDField.stringValue
        data["clientID"] = clientIDField.stringValue
        data["clientSecret"] = secretField.stringValue
        data["certificateThumbprint"] = thumbprintField.stringValue
        data["certificateExpiration"] = certExpirationField.stringValue
        data["secretExpiration"] = secretExpirationField.stringValue
        
        // Determine authentication method
        if certRadio.state == .on {
            data["authenticationMethod"] = "certificate"
        } else {
            data["authenticationMethod"] = "secret"
        }
        
        return data
    }
    
    func setInitialData(_ data: [String: Any]) {
        self.initialData = data
        if isViewLoaded {
            populateFields()
        }
    }
    
    func updateFromOtherTabs(_ combinedData: [String: Any]) {
        // Entra ID settings typically don't depend on other tabs
    }
    
    func validateData() -> String? {
        // Ensure view is loaded before accessing outlets
        guard isViewLoaded,
              let tenantIDField = fieldTenantID,
              let clientIDField = fieldClientID,
              let certRadio = radioButtonCertificate,
              let thumbprintField = fieldCertificateThumbprint,
              let secretField = fieldClientSecret else {
            return nil // Skip validation if view isn't loaded yet
        }
        
        // Validate required fields
        let tenantID = tenantIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientID = clientIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if tenantID.isEmpty {
            return "Tenant ID is required"
        }
        
        if clientID.isEmpty {
            return "Client ID is required"
        }
        
        // Validate based on authentication method
        if certRadio.state == .on {
            let thumbprint = thumbprintField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if thumbprint.isEmpty {
                return "Certificate thumbprint is required for certificate authentication"
            }
            
            // Basic thumbprint format validation (should be hex string, typically 40 characters)
            if thumbprint.count != 40 || !thumbprint.allSatisfy({ $0.isHexDigit }) {
                return "Certificate thumbprint must be a 40-character hexadecimal string"
            }
        } else {
            let clientSecret = secretField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if clientSecret.isEmpty {
                return "Client secret is required for secret authentication"
            }
        }
        
        // Validate Tenant ID format (should be a GUID)
        let tenantUUID = UUID(uuidString: tenantID)
        if tenantUUID == nil {
            return "Tenant ID must be a valid GUID"
        }
        
        // Validate Client ID format (should be a GUID)
        let clientUUID = UUID(uuidString: clientID)
        if clientUUID == nil {
            return "Client ID must be a valid GUID"
        }
        
        return nil
    }
}

// MARK: - NSTextFieldDelegate

extension EntraIDSettingsViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        markAsChanged()
        updateTestConnectionButtonState()
    }
}

// MARK: - Character Extensions

private extension Character {
    var isHexDigit: Bool {
        return isNumber || ("A"..."F").contains(self) || ("a"..."f").contains(self)
    }
}
