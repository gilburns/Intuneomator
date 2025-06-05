//
//  SettingsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/1/25.
//

import Foundation
import Cocoa

/// Log type identifier for Settings operations
private let logType = "Settings"

/// View controller for managing Intuneomator application settings and configuration
/// Provides comprehensive interface for configuring authentication, Teams notifications,
/// logging preferences, and various operational parameters
/// 
/// **Key Features:**
/// - Microsoft Entra ID authentication configuration (certificate or client secret)
/// - Teams webhook notifications settings with granular control options
/// - Cache management settings (app version retention)
/// - Logging configuration (file age and size limits)
/// - Automatic update preferences
/// - Real-time validation and credential testing
/// - Visual feedback for unsaved changes with field highlighting
/// - Secure credential import workflows for certificates and secrets
class SettingsViewController: NSViewController {
    
    /// Text field for entering or displaying the Entra ID Tenant ID.
    @IBOutlet weak var fieldTenantID: NSTextField!
    /// Text field for entering or displaying the Entra ID Client (Application) ID.
    @IBOutlet weak var fieldClientID: NSTextField!
    /// Secure text field for entering or displaying the Entra ID Client Secret.
    @IBOutlet weak var fieldClientSecret: NSTextField!
    /// Text field for displaying the certificate thumbprint when using certificate-based authentication.
    @IBOutlet weak var fieldCertificateThumbprint: NSTextField!
    
    /// Read-only text field showing the expiration date of the imported certificate.
    @IBOutlet weak var fieldCertificateExpiration: NSTextField! // view only
    /// Read-only text field showing the expiration date of the imported Entra ID client secret.
    @IBOutlet weak var fieldSecretExpiration: NSTextField! // view only

    /// Text field specifying how many previous versions of apps to retain in cache.
    @IBOutlet weak var fieldAppsToKeep: NSTextField!
    
    /// Radio button to select certificate-based authentication.
    @IBOutlet weak var radioButtonCertificate: NSButton!
    /// Radio button to select client secret-based authentication.
    @IBOutlet weak var radioButtonSecret: NSButton!
    
    /// Controls for enabling/disabling Teams webhook notifications and selecting notification categories and style.
    @IBOutlet weak var buttonSendTeamsNotifications: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForCleanup: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForCVEs: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForGroups: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForLabelUpdates: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForUpdates: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsStyle: NSPopUpButton!

    /// Text field for entering the Teams webhook URL to send notifications.
    @IBOutlet weak var fieldTeamsWebhookURL: NSTextField!
    
    /// Text fields for specifying maximum log file age and size for log rotation.
    @IBOutlet weak var fieldLogsMaxAge: NSTextField!
    @IBOutlet weak var fieldLogsMaxSize: NSTextField!

    /// Pop-up button to select the Intuneomator update mode (e.g., auto-update or notify-only).
    @IBOutlet weak var buttonIntuneomatorUpdateMode: NSPopUpButton!
    
    /// Buttons to test Entra ID credential connectivity, save settings, or cancel changes.
    @IBOutlet weak var buttonTestConnection: NSButton!
    
    @IBOutlet weak var buttonSave: NSButton!
    @IBOutlet weak var buttonCancel: NSButton!
    
    
    /// Model object holding the current settings loaded from the daemon or persisted storage.
    var settings: Settings!
    
    /// Tracks whether any field has been modified and not yet saved.
    var hasUnsavedChanges = false
    
    
    // MARK: - Lifecycle
    /// Called after the view is loaded. Initializes the settings model and populates all fields.
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = self.view.frame.size
        
        settings = Settings.init()
        
        buttonSave.isEnabled = false
        populateFields()
        
    }
    
    
    // MARK: - Actions
    /// Saves all modified settings and dismisses the settings sheet.
    @IBAction func buttonSaveSettingsClicked(_ sender: Any) {
        saveSettingsFromFields()
        self.dismiss(nil)
    }
    
    /// Cancels any unsaved changes and dismisses the settings sheet without saving.
    @IBAction func buttonCancelSettingsClicked(_ sender: Any) {
        self.dismiss(nil)
    }
    
    /// Handles switching between certificate and client secret authentication methods.
    /// Enables/disables the corresponding input fields and marks changes.
    @IBAction func radioButtonClicked(_ sender: NSButton) {
        switch sender.tag {
        case 1: // Certificate
            fieldCertificateThumbprint.isEnabled = true
            fieldClientSecret.isEnabled = false
        case 2: // Secret
            fieldCertificateThumbprint.isEnabled = false
            fieldClientSecret.isEnabled = true
        default:
            break
        }
        
        trackChanges()
    }
    
    
    /// Toggles enabling of Teams notification detail options and webhook URL field.
    /// Invoked when the main "Send Teams Notifications" checkbox is clicked.
    @IBAction func buttonSendTeamsMessageClicked (_ sender: NSButton) {
        fieldTeamsWebhookURL.isEnabled = sender.state == .on
        buttonSendTeamsNotificationsForCleanup.isEnabled = sender.state == .on
        buttonSendTeamsNotificationsForCVEs.isEnabled = sender.state == .on
        buttonSendTeamsNotificationsForGroups.isEnabled = sender.state == .on
        buttonSendTeamsNotificationsForLabelUpdates.isEnabled = sender.state == .on
        buttonSendTeamsNotificationsForUpdates.isEnabled = sender.state == .on
        buttonSendTeamsNotificationsStyle.isEnabled = sender.state == .on
        trackChanges()
    }

    /// Called when the corresponding Teams notification category checkbox is toggled. Marks settings as changed.
    @IBAction func buttonSendTeamsMessageForCleanupClicked (_ sender: NSButton) {
        trackChanges()
    }

    /// Called when the corresponding Teams notification category checkbox is toggled. Marks settings as changed.
    @IBAction func buttonSendTeamsMessageForCVEsClicked (_ sender: NSButton) {
        trackChanges()
    }

    /// Called when the corresponding Teams notification category checkbox is toggled. Marks settings as changed.
    @IBAction func buttonSendTeamsMessageForGroupsClicked (_ sender: NSButton) {
        trackChanges()
    }

    /// Called when the corresponding Teams notification category checkbox is toggled. Marks settings as changed.
    @IBAction func buttonSendTeamsMessageForLabelUpdatesClicked (_ sender: NSButton) {
        trackChanges()
    }

    /// Called when the corresponding Teams notification category checkbox is toggled. Marks settings as changed.
    @IBAction func buttonSendTeamsMessageForUpdatesClicked (_ sender: NSButton) {
        trackChanges()
    }

    /// Handles selection of Teams notification style (e.g., combined vs. separate).
    /// Enables or disables individual category checkboxes accordingly and tracks changes.
    @IBAction func buttonSendTeamsMessageStyleClicked (_ sender: NSButton) {
        
        if sender.selectedTag() == 0 {
            self.buttonSendTeamsNotificationsForCVEs.isEnabled = true
            self.buttonSendTeamsNotificationsForGroups.isEnabled = true
        } else {
            self.buttonSendTeamsNotificationsForCVEs.isEnabled = false
            self.buttonSendTeamsNotificationsForGroups.isEnabled = false
            self.buttonSendTeamsNotificationsForCVEs.state = .off
            self.buttonSendTeamsNotificationsForGroups.state = .off
        }

        trackChanges()
    }

    /// Called when the Intuneomator update mode is changed. Tracks unsaved changes.
    @IBAction func buttonIntuneomatorUpdateModeClicked (_ sender: NSButton) {
        trackChanges()
    }

    /// Validates the current tenant, application ID, and secret/certificate with the daemon.
    /// Disables the test button while validating and shows success or error alert.
    @IBAction func buttonValidateEntraCredentialsButtonClicked(_ sender: NSButton) {
        buttonTestConnection.isEnabled = false

        XPCManager.shared.validateCredentials { success in
            DispatchQueue.main.async {
                self.buttonTestConnection.isEnabled = true

                let alert = NSAlert()
                if success == true {
                    alert.messageText = "Validation Successful"
                    alert.informativeText = "The credentials are valid and have the required permissions."
                    alert.alertStyle = .informational
                } else {
                    alert.messageText = "Validation Failed"
                    alert.informativeText = "The credentials are either invalid or missing the required permissions.\n\nMake sure the enterprise app includes the DeviceManagementApps.ReadWrite.All permission and admin consent has been granted."
                    alert.alertStyle = .critical
                }
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    // MARK: - Certificate and Secret handling
    
    /// Opens a file picker to select a .p12 certificate file for import.
    @IBAction func selectP12File(_ sender: Any) {
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
    
    /// Reads the .p12 data and calls the daemon to import the certificate with the provided passphrase.
    /// Logs success or failure and shows a user alert.
    private func processP12File(fileURL: URL, passphrase: String) {
        // Implement your logic for handling the p12 file and passphrase
        Logger.logUser("Selected file: \(fileURL.path)", logType: logType)
        Logger.logUser("Entered passphrase: \(passphrase)", logType: logType) // Remove this in production for security reasons
        
        do {
            let p12Data = try Data(contentsOf: fileURL)
            XPCManager.shared.importP12Certificate(p12Data: p12Data, passphrase: passphrase) { success in
                DispatchQueue.main.async {
                    if success ?? false {
                        Logger.logUser("Successfully imported .p12 into the daemon.", logType: logType)
                        DispatchQueue.main.async {
                            self.showAlert(title: "Success", message: "Import was successful.")
                        }
//                        self.onCompletionStatusChanged?(true)
                    } else {
                        Logger.logUser("Failed to import .p12.", logType: logType)
                        DispatchQueue.main.async {
                            self.showAlert(title: "Success", message: "Import failed.")
                        }

                    }
                }
            }
        } catch {
            Logger.logUser("Failed to read .p12 file: \(error)", logType: logType)
        }
        
    }
    
    /// Prompts the user to enter their Entra ID client secret and validates non-empty input.
    @IBAction func requestEntraIDSecretKey(_ sender: Any) {
        var secretKey: String?
        
        while secretKey == nil || secretKey!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let alert = NSAlert()
            alert.messageText = "Enter Entra ID Secret Key"
            alert.informativeText = "Please enter your Entra ID Secret Key."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            
            // Secure text field for secret key input
            let secureTextField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
            alert.accessoryView = secureTextField
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn { // Cancel button
                return
            }
            
            let enteredKey = secureTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if enteredKey.isEmpty {
                // Show an error alert if the input is blank
                let errorAlert = NSAlert()
                errorAlert.messageText = "Invalid Input"
                errorAlert.informativeText = "The Entra ID Secret Key cannot be empty. Please enter a valid key."
                errorAlert.alertStyle = .critical
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
            } else {
                secretKey = enteredKey
            }
        }
        
        // Process the validated secret key
        handleEntraIDSecretKey(secretKey!)
    }
    
    /// Sends the provided Entra ID secret key to the daemon for import.
    /// On success, optionally schedules an expiration notification.
    private func handleEntraIDSecretKey(_ secretKey: String) {
        // Implement logic to store, validate, or use the secret key
        Logger.logUser("Entered Entra ID Secret Key: \(secretKey)", logType: logType) // Do NOT log in production

        Logger.logUser("Saving secret key...", logType: logType)
        XPCManager.shared.importEntraIDSecretKey(secretKey: secretKey) { success in
            if success ?? false {
                Logger.logUser("Successfully imported Entra ID secret key.", logType: logType)
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Success"
                    alert.informativeText = "Import was successful. Would you like to set an expiration notification for the secret?"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Yes")
                    alert.addButton(withTitle: "No")

                    // Date picker accessory view for expiration date
                    let datePicker = NSDatePicker(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                    datePicker.datePickerStyle = .textFieldAndStepper
                    datePicker.datePickerElements = .yearMonthDay
                    datePicker.dateValue = Date()
                    datePicker.minDate = Date()
                    alert.accessoryView = datePicker

                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        let expirationDate = datePicker.dateValue
                        XPCManager.shared.setSecretExpirationDate(expirationDate) { success in
                            DispatchQueue.main.async {
                                if success ?? false {
                                    self.showAlert(title: "Notification Scheduled", message: "We'll notify you before the secret expires on \(expirationDate).")
                                } else {
                                    self.showAlert(title: "Failed", message: "Could not save expiration notification.")
                                }
                            }
                        }
                    }
                }
            } else {
                Logger.logUser("Failed to import Entra ID secret key.", logType: logType)
                DispatchQueue.main.async {
                    self.showAlert(title: "Failed", message: "Import failed.")
                }
            }
        }
    }

    
    
    // MARK: - Track Changes
    /// Compares each UI field against the loaded settings and highlights any fields that changed.
    /// Enables the Save button if there are unsaved modifications.
    func trackChanges() {
        hasUnsavedChanges = false // reset and re-evaluate all fields
        
        checkFieldChange(fieldTenantID.stringValue, originalValue: settings.tenantid, control: fieldTenantID)
        checkFieldChange(fieldClientID.stringValue, originalValue: settings.appid, control: fieldClientID)

        checkFieldChange(fieldTeamsWebhookURL.stringValue, originalValue: settings.teamsWebhookURL, control: fieldTeamsWebhookURL)
        checkFieldChange(buttonSendTeamsNotifications.state == .on, originalValue: settings.sendTeamsNotifications, control: buttonSendTeamsNotifications)

        checkFieldChange(buttonSendTeamsNotificationsForCleanup.state == .on, originalValue: settings.sendTeamsNotificationsForCleanup, control: buttonSendTeamsNotificationsForCleanup)
        checkFieldChange(buttonSendTeamsNotificationsForCVEs.state == .on, originalValue: settings.sendTeamsNotificationsForCVEs, control: buttonSendTeamsNotificationsForCVEs)
        checkFieldChange(buttonSendTeamsNotificationsForGroups.state == .on, originalValue: settings.sendTeamsNotificationsForGroups, control: buttonSendTeamsNotificationsForGroups)
        checkFieldChange(buttonSendTeamsNotificationsForLabelUpdates.state == .on, originalValue: settings.sendTeamsNotificationsForLabelUpdates, control: buttonSendTeamsNotificationsForLabelUpdates)
        checkFieldChange(buttonSendTeamsNotificationsForUpdates.state == .on, originalValue: settings.sendTeamsNotificationsForUpdates, control: buttonSendTeamsNotificationsForUpdates)
        checkFieldChange(buttonSendTeamsNotificationsStyle.selectedTag(), originalValue: settings.sendTeamsNotificationsStyle, control: buttonSendTeamsNotificationsStyle)


        checkFieldChange(fieldAppsToKeep.stringValue, originalValue: settings.appsToKeep, control: fieldAppsToKeep)

        checkFieldChange(fieldLogsMaxAge.stringValue, originalValue: settings.logAgeMax, control: fieldLogsMaxAge)
        checkFieldChange(fieldLogsMaxSize.stringValue, originalValue: settings.logSizeMax, control: fieldLogsMaxSize)

        checkFieldChange(buttonIntuneomatorUpdateMode.selectedTag(), originalValue: settings.intuneomatorUpdateMode, control: buttonIntuneomatorUpdateMode)

        var authType: String? = "unknown"
        if radioButtonSecret.state == .on {
            authType = "secret"
        } else if radioButtonCertificate.state == .on {
            authType = "certificate"
        }
        
        if settings.connectMethod != authType {
            hasUnsavedChanges = true
            highlightField(radioButtonSecret)
            highlightField(radioButtonCertificate)
        } else {
            clearHighlight(radioButtonSecret)
            clearHighlight(radioButtonCertificate)
        }
        
        buttonSave.isEnabled = hasUnsavedChanges
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
    
    
    // Highlight a field
    /// Highlights the given control (text field or button) with a yellow background to indicate change.
    private func highlightField(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = NSColor.systemYellow
        } else if let button = field as? NSButton {
            button.layer?.backgroundColor = NSColor.systemYellow.cgColor
        }
    }
    
    
    // Clear field highlight
    /// Removes highlight from the given control (restores default background).
    func clearHighlight(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = NSColor.clear
        } else if let button = field as? NSButton {
            button.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    
    /// Called when the corresponding text field value changes. Updates the test connection button state and marks settings as changed.
    @IBAction func fieldTenantIdDidChange(_ sender: NSTextField) {
        setTestConnectionButtonState()
        trackChanges()
    }
    
    /// Called when the corresponding text field value changes. Updates the test connection button state and marks settings as changed.
    @IBAction func fieldAppIdDidChange(_ sender: NSTextField) {
        setTestConnectionButtonState()
        trackChanges()
    }

    /// Called when the corresponding text field value changes. Updates the test connection button state and marks settings as changed.
    @IBAction func fieldClientSecretDidChange(_ sender: NSTextField) {
        setTestConnectionButtonState()
        trackChanges()
    }
    
    /// Called when the corresponding text field value changes. Updates the test connection button state and marks settings as changed.
    @IBAction func fieldCertificateThumbprintDidChange(_ sender: NSTextField) {
        setTestConnectionButtonState()
        trackChanges()
    }
    
    /// Called when the corresponding text field value changes. Updates the test connection button state and marks settings as changed.
    @IBAction func fieldAppsTeamsWebhookURLDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    /// Called when the corresponding text field value changes. Updates the test connection button state and marks settings as changed.
    @IBAction func fieldAppsToKeepDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    /// Called when the corresponding text field value changes. Updates the test connection button state and marks settings as changed.
    @IBAction func fieldLogAgeMaxDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    /// Called when the corresponding text field value changes. Updates the test connection button state and marks settings as changed.
    @IBAction func fieldLogSizeMaxDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    
    
    // MARK: - Helpers
    
    /// Enables or disables the "Test Connection" button based on whether required credential fields are populated.
    private func setTestConnectionButtonState() {
        if !fieldClientID.stringValue.isEmpty && !fieldTenantID.stringValue.isEmpty && (!fieldClientSecret.stringValue.isEmpty || !fieldCertificateThumbprint.stringValue.isEmpty)
        {
            buttonTestConnection.isEnabled = true
        } else {
            buttonTestConnection.isEnabled = false
        }
    }
    
    /// Displays a modal alert with the given title and message. Intended for credential import or validation feedback.
    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        
        DispatchQueue.main.async {
            self.showAlert(title: "Success", message: "Import succeeded.")
        }
        
    }
    
    /// Convenience method to show an informational alert with a single "OK" button.
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    
    // MARK: - Get Helpers
    
    /// Retrieves the current "apps to keep" setting from the daemon and updates the UI and settings model.
    func getAppsToKeep() {
        XPCManager.shared.getAppsToKeep { appsToKeep in
            DispatchQueue.main.async {
                let appsToKeep = appsToKeep ?? 2
                self.fieldAppsToKeep.stringValue = String(appsToKeep)
                self.settings.appsToKeep = String(appsToKeep)
            }
        }
    }
    
    /// Retrieves the current authentication method (secret or certificate) from the daemon and updates the UI.
    func getAuthMethod() {
        XPCManager.shared.getAuthMethod { authMethod in
            DispatchQueue.main.async {
                let authMethod = authMethod ?? "Unknown"
                self.settings.connectMethod = authMethod
                
                if authMethod == "secret" {
                    self.radioButtonCertificate.state = .off
                    self.radioButtonSecret.state = .on
                    self.fieldCertificateThumbprint.isEnabled = false
                    self.fieldClientSecret.isEnabled = true
                } else if authMethod == "certificate" {
                    self.radioButtonCertificate.state = .on
                    self.radioButtonSecret.state = .off
                    self.fieldCertificateThumbprint.isEnabled = true
                    self.fieldClientSecret.isEnabled = false
                } else {
                    self.radioButtonCertificate.state = .off
                    self.radioButtonSecret.state = .off
                    self.fieldCertificateThumbprint.isEnabled = false
                    self.fieldClientSecret.isEnabled = false
                }
                
            }
        }
    }
    
    /// Retrieves the certificate expiration date from the daemon and displays it in the UI.
    func getCertExpiration() {
        XPCManager.shared.getCertExpiration { certExpiration in
            DispatchQueue.main.async {
                if let certExpiration = certExpiration {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    formatter.timeZone = TimeZone.current
                    self.fieldCertificateExpiration.stringValue = "Expiration: \(formatter.string(from: certExpiration))"
                } else {
                    self.fieldCertificateExpiration.stringValue = "Not Available"
                }
            }
        }
    }

    /// Retrieves the secret key expiration date from the daemon and displays it in the UI.
    func getSecretExpiration() {
        XPCManager.shared.getSecretExpirationDate { secretExpiration in
            DispatchQueue.main.async {
                if let secretExpiration = secretExpiration {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    formatter.timeZone = TimeZone.current
                    self.fieldSecretExpiration.stringValue = "Expiration: \(formatter.string(from: secretExpiration))"
                } else {
                    self.fieldCertificateExpiration.stringValue = "Not Available"
                }
            }
        }
    }

    
    /// Retrieves the certificate thumbprint from the daemon and updates the UI and settings model.
    func getCertThumbprint() {
        XPCManager.shared.getCertThumbprint { certThumbprint in
            DispatchQueue.main.async {
                let certThumbprint = certThumbprint ?? "Unknown"
                self.fieldCertificateThumbprint.stringValue = certThumbprint
                self.settings.certThumbprint = certThumbprint
                
                self.setTestConnectionButtonState()
            }
        }
    }
    
    /// Retrieves the client secret (masked) from the daemon and updates the UI and settings model.
    func getClientSecret() {
        XPCManager.shared.getClientSecret { clientSecret in
            DispatchQueue.main.async {
                let clientSecret = clientSecret ?? "Unknown"
                self.fieldClientSecret.stringValue = clientSecret
                self.settings.secret = clientSecret
                
                self.setTestConnectionButtonState()
            }
        }
    }
    
    
    /// Retrieves the Entra ID tenant ID from the daemon and updates the UI and settings model.
    func getTenantID() {
        XPCManager.shared.getTenantID { tenantID in
            DispatchQueue.main.async {
                let tenantID = tenantID ?? "Unknown"
                self.fieldTenantID.stringValue = tenantID
                self.settings.tenantid = tenantID
                
                self.setTestConnectionButtonState()

            }
        }
    }
    
    
    /// Retrieves the Entra ID application (client) ID from the daemon and updates the UI and settings model.
    func getApplicationID() {
        XPCManager.shared.getApplicationID { applicationID in
            DispatchQueue.main.async {
                let applicationID = applicationID ?? "Unknown"
                self.fieldClientID.stringValue = applicationID
                self.settings.appid = applicationID
                
                self.setTestConnectionButtonState()
            }
        }
    }
    
    /// Retrieves the Teams webhook URL from the daemon and updates the UI and settings model.
    func getTeamsWebhookURL() {
        XPCManager.shared.getTeamsWebhookURL { teamsWebhookURL in
            DispatchQueue.main.async {
                let teamsWebhookURL = teamsWebhookURL ?? "Unknown"
                self.fieldTeamsWebhookURL.stringValue = teamsWebhookURL
                self.settings.teamsWebhookURL = teamsWebhookURL
            }
        }
    }
    
    /// Retrieves the specified Teams notification preference from the daemon and updates the UI and settings model.
    func getTeamsNotificationsEnabled() {
        // Get First Run Status
        XPCManager.shared.getTeamsNotificationsEnabled { teamsNotificationsEnabled in
            DispatchQueue.main.async {
                let teamsNotificationsEnabled = teamsNotificationsEnabled ?? false
                self.buttonSendTeamsNotifications.state = teamsNotificationsEnabled ? .on : .off
                self.fieldTeamsWebhookURL.isEnabled = teamsNotificationsEnabled
                
                self.buttonSendTeamsNotificationsForCleanup.isEnabled = teamsNotificationsEnabled
                self.buttonSendTeamsNotificationsForCVEs.isEnabled = teamsNotificationsEnabled
                self.buttonSendTeamsNotificationsForGroups.isEnabled = teamsNotificationsEnabled
                self.buttonSendTeamsNotificationsForLabelUpdates.isEnabled = teamsNotificationsEnabled
                self.buttonSendTeamsNotificationsForUpdates.isEnabled = teamsNotificationsEnabled
                self.buttonSendTeamsNotificationsStyle.isEnabled = teamsNotificationsEnabled

                self.settings.sendTeamsNotifications = teamsNotificationsEnabled
            }
        }
    }

    /// Retrieves the specified Teams notification preference from the daemon and updates the UI and settings model.
    func getTeamsNotificationsForCleanup() {
        // Get First Run Status
        XPCManager.shared.getTeamsNotificationsForCleanup { teamsNotificationsForCleanup in
            DispatchQueue.main.async {
                let teamsNotificationsForCleanup = teamsNotificationsForCleanup ?? false
                self.buttonSendTeamsNotificationsForCleanup.state = teamsNotificationsForCleanup ? .on : .off
                self.settings.sendTeamsNotificationsForCleanup = teamsNotificationsForCleanup
            }
        }
    }

    /// Retrieves the specified Teams notification preference from the daemon and updates the UI and settings model.
    func getTeamsNotificationsForCVEs() {
        // Get First Run Status
        XPCManager.shared.getTeamsNotificationsForCVEs { teamsNotificationsForCVEs in
            DispatchQueue.main.async {
                let teamsNotificationsForCVEs = teamsNotificationsForCVEs ?? false
                self.buttonSendTeamsNotificationsForCVEs.state = teamsNotificationsForCVEs ? .on : .off
                self.settings.sendTeamsNotificationsForCVEs = teamsNotificationsForCVEs
            }
        }
    }

    /// Retrieves the specified Teams notification preference from the daemon and updates the UI and settings model.
    func getTeamsNotificationsForGroups() {
        // Get First Run Status
        XPCManager.shared.getTeamsNotificationsForGroups { teamsNotificationsForGroups in
            DispatchQueue.main.async {
                let teamsNotificationsForGroups = teamsNotificationsForGroups ?? false
                self.buttonSendTeamsNotificationsForGroups.state = teamsNotificationsForGroups ? .on : .off
                self.settings.sendTeamsNotificationsForGroups = teamsNotificationsForGroups
            }
        }
    }

    /// Retrieves the specified Teams notification preference from the daemon and updates the UI and settings model.
    func getTeamsNotificationsForLabelUpdates() {
        // Get First Run Status
        XPCManager.shared.getTeamsNotificationsForLabelUpdates { teamsNotificationsForLabelUpdates in
            DispatchQueue.main.async {
                let teamsNotificationsForLabelUpdates = teamsNotificationsForLabelUpdates ?? false
                self.buttonSendTeamsNotificationsForLabelUpdates.state = teamsNotificationsForLabelUpdates ? .on : .off
                self.settings.sendTeamsNotificationsForLabelUpdates = teamsNotificationsForLabelUpdates
            }
        }
    }

    /// Retrieves the specified Teams notification preference from the daemon and updates the UI and settings model.
    func getTeamsNotificationsForUpdates() {
        // Get First Run Status
        XPCManager.shared.getTeamsNotificationsForUpdates { teamsNotificationsForUpdates in
            DispatchQueue.main.async {
                let teamsNotificationsForUpdates = teamsNotificationsForUpdates ?? false
                self.buttonSendTeamsNotificationsForUpdates.state = teamsNotificationsForUpdates ? .on : .off
                self.settings.sendTeamsNotificationsForUpdates = teamsNotificationsForUpdates
            }
        }
    }

    /// Retrieves the specified Teams notification preference from the daemon and updates the UI and settings model.
    func getTeamsNotificationsStyle() {
        // Get First Run Status
        XPCManager.shared.getTeamsNotificationsStyle { teamsNotificationsStyle in
            DispatchQueue.main.async {
                let teamsNotificationsStyle = teamsNotificationsStyle ?? 0
                self.buttonSendTeamsNotificationsStyle.selectItem(withTag: teamsNotificationsStyle)
                self.settings.sendTeamsNotificationsStyle = teamsNotificationsStyle
                if teamsNotificationsStyle == 0 {
                    self.buttonSendTeamsNotificationsForCVEs.isEnabled = true
                    self.buttonSendTeamsNotificationsForGroups.isEnabled = true
                } else {
                    self.buttonSendTeamsNotificationsForCVEs.isEnabled = false
                    self.buttonSendTeamsNotificationsForGroups.isEnabled = false
                }
            }
        }
    }

    /// Retrieves the maximum log file age setting from the daemon and updates the UI and settings model.
    func getLogAgeMax() {
        XPCManager.shared.getLogAgeMax { logAgeMax in
            DispatchQueue.main.async {
                let logAgeMax = logAgeMax ?? 0
                self.fieldLogsMaxAge.stringValue = String(logAgeMax)
                self.settings.logAgeMax = String(logAgeMax)
            }
        }
    }

    /// Retrieves the maximum log file size setting from the daemon and updates the UI and settings model.
    func getLogSizeMax() {
        XPCManager.shared.getLogSizeMax { logSizeMax in
            DispatchQueue.main.async {
                let logSizeMax = logSizeMax ?? 0
                self.fieldLogsMaxSize.stringValue = String(logSizeMax)
                self.settings.logSizeMax = String(logSizeMax)
            }
        }
    }

    /// Retrieves the current Intuneomator update mode from the daemon and updates the UI and settings model.
    func getIntuneomatorUpdateMode() {
        XPCManager.shared.getIntuneomatorUpdateMode { updateMode in
            DispatchQueue.main.async {
                let updateMode = updateMode ?? 0
                self.buttonIntuneomatorUpdateMode.selectItem(withTag: updateMode)
                self.settings.intuneomatorUpdateMode = updateMode
            }
        }
    }

    
    // MARK: - Set Helpers
    
    /// Sends the "enable Teams notifications" flag to the daemon.
    private func setTeamsWebHookEnabled() {
        let isEnabled = (buttonSendTeamsNotifications.state == .on)
        XPCManager.shared.setTeamsNotificationsEnabled(isEnabled) { success in
            Logger.logUser("Teams notifications updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    /// Sends the specified Teams notification setting to the daemon.
    private func setTeamsWebHookURL() {
        let urlString = fieldTeamsWebhookURL.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setTeamsWebhookURL(urlString) { success in
            Logger.logUser("Webhook URL updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    /// Sends the specified Teams notification setting to the daemon.
    private func setTeamsWebHookEnabledForCleanup() {
        let isEnabled = (buttonSendTeamsNotificationsForCleanup.state == .on)
        XPCManager.shared.setTeamsNotificationsForCleanup(isEnabled) { success in
            Logger.logUser("Teams notifications for cleanup: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    /// Sends the specified Teams notification setting to the daemon.
    private func setTeamsWebHookEnabledForCVEs() {
        let isEnabled = (buttonSendTeamsNotificationsForCVEs.state == .on)
        XPCManager.shared.setTeamsNotificationsForCVEs(isEnabled) { success in
            Logger.logUser("Teams notifications for CVEs: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    /// Sends the specified Teams notification setting to the daemon.
    private func setTeamsWebHookEnabledForGroups() {
        let isEnabled = (buttonSendTeamsNotificationsForGroups.state == .on)
        XPCManager.shared.setTeamsNotificationsForGroups(isEnabled) { success in
            Logger.logUser("Teams notifications for Groups: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    /// Sends the specified Teams notification setting to the daemon.
    private func setTeamsWebHookEnabledForLabelUpdates() {
        let isEnabled = (buttonSendTeamsNotificationsForLabelUpdates.state == .on)
        XPCManager.shared.setTeamsNotificationsForLabelUpdates(isEnabled) { success in
            Logger.logUser("Teams notifications for Label Updates: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    /// Sends the specified Teams notification setting to the daemon.
    private func setTeamsWebHookEnabledForUpdates() {
        let isEnabled = (buttonSendTeamsNotificationsForUpdates.state == .on)
        XPCManager.shared.setTeamsNotificationsForUpdates(isEnabled) { success in
            Logger.logUser("Teams notifications for Updates: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    /// Sends the specified Teams notification setting to the daemon.
    private func setTeamsWebHookStyle() {
        let selectedTag = (buttonSendTeamsNotificationsStyle.selectedTag())
        XPCManager.shared.setTeamsNotificationsStyle(selectedTag) { success in
            Logger.logUser("Teams notifications Style: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    /// Sends the certificate thumbprint to the daemon for authentication updates.
    private func setCertificateThumbprint() {
        let thumbprint = fieldCertificateThumbprint.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setApplicationID(thumbprint) { success in
            Logger.logUser("Certificate Thumbprint updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    /// Sends the client secret to the daemon for authentication updates.
    private func setClientSecret() {
        let secret = fieldClientSecret.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setApplicationID(secret) { success in
            Logger.logUser("Client Secret updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    /// Sends the selected authentication method (secret or certificate) to the daemon.
    private func setAuthMethod() {
        
        var authMethod: String = "Unknown"
        if radioButtonSecret.state == .on {
            authMethod = "secret"
        } else if radioButtonCertificate.state == .on {
            authMethod = "certificate"
        }
        
        XPCManager.shared.setAuthMethod(authMethod) { success in
            Logger.logUser("Auth Method updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    /// Sends the "apps to keep" count to the daemon.
    private func setAppsToKeep() {
        let appsToKeepString = Int(fieldAppsToKeep.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        XPCManager.shared.setAppsToKeep(appsToKeepString ?? 2) { success in
            Logger.logUser("Apps to keep updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    /// Sends the application (client) ID to the daemon.
    private func setApplicationID() {
        let appIDString = fieldClientID.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setApplicationID(appIDString) { success in
            Logger.logUser("Application ID updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    /// Sends the tenant ID to the daemon.
    private func setTenantID() {
        let tenantIDString = fieldTenantID.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setTenantID(tenantIDString) { success in
            Logger.logUser("Tenant ID updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    /// Sends the maximum log age setting to the daemon.
    private func setLogAgeMax() {
        let logAgeMaxString = Int(fieldLogsMaxAge.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        XPCManager.shared.setLogAgeMax(logAgeMaxString ?? 0) { success in
            Logger.logUser("Log max age updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    /// Sends the maximum log size setting to the daemon.
    private func setLogSizeMax() {
        let logSizeMaxString = Int(fieldLogsMaxSize.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        XPCManager.shared.setLogSizeMax(logSizeMaxString ?? 0) { success in
            Logger.logUser("Log max size updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    /// Sends the Intuneomator update mode to the daemon.
    private func setIntuneomatorUpdateMode() {
        let selectedTag = (buttonIntuneomatorUpdateMode.selectedTag())
        XPCManager.shared.setIntuneomatorUpdateMode(selectedTag) { success in
            Logger.logUser("Intuneomator Update Mode updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }


    // MARK: - Settings File Read and Write Functions
    /// Populates all UI fields by retrieving each setting from the daemon.
    private func populateFields() {
        getTenantID()
        getApplicationID()
        getAppsToKeep()
        getAuthMethod()
        getTeamsWebhookURL()
        getTeamsNotificationsEnabled()
        getTeamsNotificationsForCleanup()
        getTeamsNotificationsForCVEs()
        getTeamsNotificationsForGroups()
        getTeamsNotificationsForLabelUpdates()
        getTeamsNotificationsForUpdates()
        getTeamsNotificationsStyle()
        getCertExpiration()
        getSecretExpiration()
        getClientSecret()
        getCertThumbprint()
        getLogAgeMax()
        getLogSizeMax()
        getIntuneomatorUpdateMode()
    }
    
    /// Compares each UI field to the settings model and calls the corresponding setter methods for any changed values.
    private func saveSettingsFromFields() {

        // Good
        if settings.tenantid != fieldTenantID.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) {
            
            setTenantID()
        }

        // Good
        if settings.appid != fieldClientID.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) {
            
            setApplicationID()
        }

        // Good
        if settings.appsToKeep != fieldAppsToKeep.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) {
            
            setAppsToKeep()
        }

        
        var authType: String? = "unknown"
        if radioButtonSecret.state == .on {
            authType = "secret"
        } else if radioButtonCertificate.state == .on {
            authType = "certificate"
        }

        if settings.connectMethod != authType {

            setAuthMethod()
        }

        // Good
        if settings.teamsWebhookURL != fieldTeamsWebhookURL.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) {
            
            setTeamsWebHookURL()
        }

        // Good
        if settings.sendTeamsNotifications != (buttonSendTeamsNotifications.state == .on) {
            
            setTeamsWebHookEnabled()
        }

        if settings.sendTeamsNotificationsForCleanup != (buttonSendTeamsNotificationsForCleanup.state == .on) {
            
            setTeamsWebHookEnabledForCleanup()
        }

        if settings.sendTeamsNotificationsForCVEs != (buttonSendTeamsNotificationsForCVEs.state == .on) {
            
            setTeamsWebHookEnabledForCVEs()
        }

        if settings.sendTeamsNotificationsForGroups != (buttonSendTeamsNotificationsForGroups.state == .on) {
            
            setTeamsWebHookEnabledForGroups()
        }

        if settings.sendTeamsNotificationsForLabelUpdates != (buttonSendTeamsNotificationsForLabelUpdates.state == .on) {
            
            setTeamsWebHookEnabledForLabelUpdates()
        }

        if settings.sendTeamsNotificationsForUpdates != (buttonSendTeamsNotificationsForUpdates.state == .on) {
            
            setTeamsWebHookEnabledForUpdates()
        }

        if settings.sendTeamsNotificationsStyle != (buttonSendTeamsNotificationsStyle.selectedTag()) {
            
            setTeamsWebHookStyle()
        }


        if settings.secret != fieldClientSecret.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) {
            
            setClientSecret()
        }
        
        
        if settings.logAgeMax != fieldLogsMaxAge.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) {
            
            setLogAgeMax()
        }

        if settings.logSizeMax != fieldLogsMaxSize.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) {
            
            setLogSizeMax()
        }

        if settings.intuneomatorUpdateMode != buttonIntuneomatorUpdateMode.selectedTag() {
            
            setIntuneomatorUpdateMode()
        }

    }
    
    
    
}

