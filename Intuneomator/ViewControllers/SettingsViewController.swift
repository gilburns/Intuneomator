//
//  SettingsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/1/25.
//

import Foundation
import Cocoa

private let logType = "Settings"

class SettingsViewController: NSViewController {
    
    @IBOutlet weak var fieldTenantID: NSTextField!
    @IBOutlet weak var fieldClientID: NSTextField!
    @IBOutlet weak var fieldClientSecret: NSTextField!
    @IBOutlet weak var fieldCertificateThumbprint: NSTextField!
    
    @IBOutlet weak var fieldCertificateExpiration: NSTextField! // view only
    @IBOutlet weak var fieldSecretExpiration: NSTextField! // view only

    @IBOutlet weak var fieldAppsToKeep: NSTextField!
    
    @IBOutlet weak var radioButtonCertificate: NSButton!
    @IBOutlet weak var radioButtonSecret: NSButton!
    
    @IBOutlet weak var buttonSendTeamsNotifications: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForCleanup: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForCVEs: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForGroups: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForLabelUpdates: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForUpdates: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsStyle: NSPopUpButton!

    @IBOutlet weak var fieldTeamsWebhookURL: NSTextField!
    
    @IBOutlet weak var fieldLogsMaxAge: NSTextField!
    @IBOutlet weak var fieldLogsMaxSize: NSTextField!

    @IBOutlet weak var buttonTestConnection: NSButton!
    
    @IBOutlet weak var buttonSave: NSButton!
    @IBOutlet weak var buttonCancel: NSButton!
    
    
    var settings: Settings!
    
    // track changes for the settings
    var hasUnsavedChanges = false
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = self.view.frame.size
        
        settings = Settings.init()
        
        buttonSave.isEnabled = false
        populateFields()
        
    }
    
    
    // MARK: - Actions
    @IBAction func buttonSaveSettingsClicked(_ sender: Any) {
        saveSettingsFromFields()
        self.dismiss(nil)
    }
    
    @IBAction func buttonCancelSettingsClicked(_ sender: Any) {
        self.dismiss(nil)
    }
    
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

    @IBAction func buttonSendTeamsMessageForCleanupClicked (_ sender: NSButton) {
        trackChanges()
    }

    @IBAction func buttonSendTeamsMessageForCVEsClicked (_ sender: NSButton) {
        trackChanges()
    }

    @IBAction func buttonSendTeamsMessageForGroupsClicked (_ sender: NSButton) {
        trackChanges()
    }

    @IBAction func buttonSendTeamsMessageForLabelUpdatesClicked (_ sender: NSButton) {
        trackChanges()
    }

    @IBAction func buttonSendTeamsMessageForUpdatesClicked (_ sender: NSButton) {
        trackChanges()
    }

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
    
    private func checkFieldChange<T: Equatable>(_ currentValue: T, originalValue: T, control: NSControl) {
        if currentValue != originalValue {
            hasUnsavedChanges = true
            highlightField(control)
        } else {
            clearHighlight(control)
        }
    }
    
    
    // Highlight a field
    private func highlightField(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = NSColor.systemYellow
        } else if let button = field as? NSButton {
            button.layer?.backgroundColor = NSColor.systemYellow.cgColor
        }
    }
    
    
    // Clear field highlight
    func clearHighlight(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = NSColor.clear
        } else if let button = field as? NSButton {
            button.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    
    @IBAction func fieldTenantIdDidChange(_ sender: NSTextField) {
        setTestConnectionButtonState()
        trackChanges()
    }
    
    @IBAction func fieldAppIdDidChange(_ sender: NSTextField) {
        setTestConnectionButtonState()
        trackChanges()
    }

    @IBAction func fieldClientSecretDidChange(_ sender: NSTextField) {
        setTestConnectionButtonState()
        trackChanges()
    }
    
    @IBAction func fieldCertificateThumbprintDidChange(_ sender: NSTextField) {
        setTestConnectionButtonState()
        trackChanges()
    }
    
    @IBAction func fieldAppsTeamsWebhookURLDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    @IBAction func fieldAppsToKeepDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    @IBAction func fieldLogAgeMaxDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    @IBAction func fieldLogSizeMaxDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    
    
    // MARK: - Helpers
    
    private func setTestConnectionButtonState() {
        if !fieldClientID.stringValue.isEmpty && !fieldTenantID.stringValue.isEmpty && (!fieldClientSecret.stringValue.isEmpty || !fieldCertificateThumbprint.stringValue.isEmpty)
        {
            buttonTestConnection.isEnabled = true
        } else {
            buttonTestConnection.isEnabled = false
        }
    }
    
    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        
        DispatchQueue.main.async {
            self.showAlert(title: "Success", message: "Import succeeded.")
        }
        
    }
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    
    // MARK: - Get Helpers
    
    func getAppsToKeep() {
        XPCManager.shared.getAppsToKeep { appsToKeep in
            DispatchQueue.main.async {
                let appsToKeep = appsToKeep ?? 2
                self.fieldAppsToKeep.stringValue = String(appsToKeep)
                self.settings.appsToKeep = String(appsToKeep)
            }
        }
    }
    
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
    
    func getTeamsWebhookURL() {
        XPCManager.shared.getTeamsWebhookURL { teamsWebhookURL in
            DispatchQueue.main.async {
                let teamsWebhookURL = teamsWebhookURL ?? "Unknown"
                self.fieldTeamsWebhookURL.stringValue = teamsWebhookURL
                self.settings.teamsWebhookURL = teamsWebhookURL
            }
        }
    }
    
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

    func getLogAgeMax() {
        XPCManager.shared.getLogAgeMax { logAgeMax in
            DispatchQueue.main.async {
                let logAgeMax = logAgeMax ?? 0
                self.fieldLogsMaxAge.stringValue = String(logAgeMax)
                self.settings.logAgeMax = String(logAgeMax)
            }
        }
    }

    func getLogSizeMax() {
        XPCManager.shared.getLogSizeMax { logSizeMax in
            DispatchQueue.main.async {
                let logSizeMax = logSizeMax ?? 0
                self.fieldLogsMaxSize.stringValue = String(logSizeMax)
                self.settings.logSizeMax = String(logSizeMax)
            }
        }
    }

    
    // MARK: - Set Helpers
    
    private func setTeamsWebHookEnabled() {
        let isEnabled = (buttonSendTeamsNotifications.state == .on)
        XPCManager.shared.setTeamsNotificationsEnabled(isEnabled) { success in
            Logger.logUser("Teams notifications updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    private func setTeamsWebHookURL() {
        let urlString = fieldTeamsWebhookURL.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setTeamsWebhookURL(urlString) { success in
            Logger.logUser("Webhook URL updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    private func setTeamsWebHookEnabledForCleanup() {
        let isEnabled = (buttonSendTeamsNotificationsForCleanup.state == .on)
        XPCManager.shared.setTeamsNotificationsForCleanup(isEnabled) { success in
            Logger.logUser("Teams notifications for cleanup: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    private func setTeamsWebHookEnabledForCVEs() {
        let isEnabled = (buttonSendTeamsNotificationsForCVEs.state == .on)
        XPCManager.shared.setTeamsNotificationsForCVEs(isEnabled) { success in
            Logger.logUser("Teams notifications for CVEs: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    private func setTeamsWebHookEnabledForGroups() {
        let isEnabled = (buttonSendTeamsNotificationsForGroups.state == .on)
        XPCManager.shared.setTeamsNotificationsForGroups(isEnabled) { success in
            Logger.logUser("Teams notifications for Groups: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    private func setTeamsWebHookEnabledForLabelUpdates() {
        let isEnabled = (buttonSendTeamsNotificationsForLabelUpdates.state == .on)
        XPCManager.shared.setTeamsNotificationsForLabelUpdates(isEnabled) { success in
            Logger.logUser("Teams notifications for Label Updates: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    private func setTeamsWebHookEnabledForUpdates() {
        let isEnabled = (buttonSendTeamsNotificationsForUpdates.state == .on)
        XPCManager.shared.setTeamsNotificationsForUpdates(isEnabled) { success in
            Logger.logUser("Teams notifications for Updates: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    private func setTeamsWebHookStyle() {
        let selectedTag = (buttonSendTeamsNotificationsStyle.selectedTag())
        XPCManager.shared.setTeamsNotificationsStyle(selectedTag) { success in
            Logger.logUser("Teams notifications Style: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    private func setCertificateThumbprint() {
        let thumbprint = fieldCertificateThumbprint.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setApplicationID(thumbprint) { success in
            Logger.logUser("Certificate Thumbprint updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    private func setClientSecret() {
        let secret = fieldClientSecret.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setApplicationID(secret) { success in
            Logger.logUser("Client Secret updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
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
    
    private func setAppsToKeep() {
        let appsToKeepString = Int(fieldAppsToKeep.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        XPCManager.shared.setAppsToKeep(appsToKeepString ?? 2) { success in
            Logger.logUser("Apps to keep updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    private func setApplicationID() {
        let appIDString = fieldClientID.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setApplicationID(appIDString) { success in
            Logger.logUser("Application ID updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    private func setTenantID() {
        let tenantIDString = fieldTenantID.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setTenantID(tenantIDString) { success in
            Logger.logUser("Tenant ID updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    private func setLogAgeMax() {
        let logAgeMaxString = Int(fieldLogsMaxAge.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        XPCManager.shared.setLogAgeMax(logAgeMaxString ?? 0) { success in
            Logger.logUser("Log max age updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    private func setLogSizeMax() {
        let logSizeMaxString = Int(fieldLogsMaxSize.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        XPCManager.shared.setLogSizeMax(logSizeMaxString ?? 0) { success in
            Logger.logUser("Log max size updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    // MARK: - Settings File Read and Write Functions
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
    }
    
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

        if settings.sendTeamsNotificationsStyle != (buttonSendTeamsNotificationsStyle.tag) {
            
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

    }
    
    
    
}

