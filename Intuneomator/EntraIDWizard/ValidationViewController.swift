//
//  ValidationViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

class ValidationViewController: NSViewController, WizardStepProtocol {
    var onCompletionStatusChanged: ((Bool) -> Void)?
    var isStepCompleted: Bool { return true }

    @IBOutlet weak var tenantIDTextField: NSTextField!
    @IBOutlet weak var applicationIDTextField: NSTextField!
    
    @IBOutlet weak var validateEntraCredentialsButton: NSButton!
    
// MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    static func create() -> ValidationViewController {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "ValidationViewController") as! ValidationViewController
    }
    
    
    
    override func viewDidAppear() {
        super.viewDidAppear()

        if tenantIDTextField.stringValue.isEmpty {
            // Set Tenant ID
            XPCManager.shared.getTenantID { url in
                DispatchQueue.main.async {
                    self.tenantIDTextField.stringValue = url ?? ""
                    self.updateValidationButtonStatus()
                }
            }
        }
        
        if applicationIDTextField.stringValue.isEmpty {
            // Set Application ID
            XPCManager.shared.getApplicationID { url in
                DispatchQueue.main.async {
                    self.applicationIDTextField.stringValue = url ?? ""
                    self.updateValidationButtonStatus()
                }
            }
        }

    }

    
    // MARK: - Actions
    @IBAction func validateEntraCredentialsButtonClicked(_ sender: NSButton) {
        validateEntraCredentialsButton.isEnabled = false

        XPCManager.shared.validateCredentials { success in
            DispatchQueue.main.async {
                self.validateEntraCredentialsButton.isEnabled = true

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
    
    @IBAction func fieldTenentIDValueChanged(_ sender: NSTextField) {
        
        setTenantID()
        updateValidationButtonStatus()
    }

    @IBAction func fieldApplicationIDValueChanged(_ sender: NSTextField) {
        
        setApplicationID()
        updateValidationButtonStatus()
    }

    

    
    private func validateInputs() -> Bool {
        return !tenantIDTextField.stringValue.isEmpty && !applicationIDTextField.stringValue.isEmpty
    }
    
    private func clearInputs() {
        tenantIDTextField.stringValue = ""
        applicationIDTextField.stringValue = ""
    }
    
    
    private func updateValidationButtonStatus() {
        if tenantIDTextField.stringValue.isEmpty || applicationIDTextField.stringValue.isEmpty {
            validateEntraCredentialsButton.isEnabled = false
        } else {
            validateEntraCredentialsButton.isEnabled = true
        }
    }

    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Permissions Missing"
        alert.informativeText = """
        This application does not have the required permissions to retrieve detected applications.
        
        Please ensure that the enterprise application has been assigned the following Microsoft Graph API permissions:

        - DeviceManagementApps.ReadWrite.All

        After granting permissions, an admin must consent to them in Entra ID.
        """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    
    // MARK: - XPC Methods
    private func setApplicationID() {
        let appIDString = applicationIDTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setApplicationID(appIDString) { success in
            Logger.logUser("Application ID updated: \(success == true ? "✅" : "❌")", logType: "Settings")
        }
    }
    
    private func setTenantID() {
        let tenantIDString = tenantIDTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setTenantID(tenantIDString) { success in
            Logger.logUser("Tenant ID updated: \(success == true ? "✅" : "❌")", logType: "Settings")
        }
    }

    
}
