//
//  ValidationViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

/// Entra ID configuration validation view controller for the setup wizard
/// Provides interface for configuring tenant ID and application ID, then validating credentials
/// Performs Microsoft Graph API authentication test to ensure proper permissions and setup
/// Implements WizardStepProtocol for integration with the multi-step wizard flow
class ValidationViewController: NSViewController, WizardStepProtocol {
    
    // MARK: - WizardStepProtocol Properties
    
    /// Callback closure for notifying wizard of completion status changes
    var onCompletionStatusChanged: ((Bool) -> Void)?
    
    /// Indicates if this step has been completed (always true as validation is optional)
    var isStepCompleted: Bool { return true }

    /// Log type identifier for logging operations
    private let logType = "Settings"

    // MARK: - Interface Builder Outlets
    
    /// Text field for entering the Microsoft Entra ID (Azure AD) tenant identifier
    @IBOutlet weak var tenantIDTextField: NSTextField!
    
    /// Text field for entering the Microsoft Entra ID application (client) identifier
    @IBOutlet weak var applicationIDTextField: NSTextField!
    
    /// Button to initiate credential validation against Microsoft Graph API
    @IBOutlet weak var validateEntraCredentialsButton: NSButton!
    
    // MARK: - View Lifecycle Methods
    
    /// Called after the view controller's view is loaded into memory
    /// Performs any additional setup required for the validation view
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Factory Method
    
    /// Factory method for creating an instance from the Wizard storyboard
    /// Provides type-safe instantiation from storyboard with proper identifier
    /// - Returns: Configured ValidationViewController instance
    static func create() -> ValidationViewController {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "ValidationViewController") as! ValidationViewController
    }
    
    /// Called when the view controller's view appears on screen
    /// Loads current tenant ID and application ID settings from XPC service and updates UI
    override func viewDidAppear() {
        super.viewDidAppear()

        if tenantIDTextField.stringValue.isEmpty {
            // Load and display current tenant ID
            XPCManager.shared.getTenantID { url in
                DispatchQueue.main.async {
                    self.tenantIDTextField.stringValue = url ?? ""
                    self.updateValidationButtonStatus()
                }
            }
        }
        
        if applicationIDTextField.stringValue.isEmpty {
            // Load and display current application ID
            XPCManager.shared.getApplicationID { url in
                DispatchQueue.main.async {
                    self.applicationIDTextField.stringValue = url ?? ""
                    self.updateValidationButtonStatus()
                }
            }
        }
    }

    
    // MARK: - User Action Methods
    
    /// Initiates credential validation against Microsoft Graph API
    /// Tests authentication and required permissions (DeviceManagementApps.ReadWrite.All)
    /// Displays detailed feedback on validation success or failure
    /// - Parameter sender: The validate credentials button that triggered the action
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
    
    /// Handles tenant ID text field changes
    /// Updates stored tenant ID and validation button state when user modifies the field
    /// - Parameter sender: The tenant ID text field that triggered the change
    @IBAction func fieldTenentIDValueChanged(_ sender: NSTextField) {
        setTenantID()
        updateValidationButtonStatus()
    }

    /// Handles application ID text field changes
    /// Updates stored application ID and validation button state when user modifies the field
    /// - Parameter sender: The application ID text field that triggered the change
    @IBAction func fieldApplicationIDValueChanged(_ sender: NSTextField) {
        setApplicationID()
        updateValidationButtonStatus()
    }

    
    // MARK: - Input Validation Methods
    
    /// Validates that both tenant ID and application ID fields contain values
    /// Used for enabling/disabling validation button and ensuring complete configuration
    /// - Returns: Boolean indicating if both required fields have values
    private func validateInputs() -> Bool {
        return !tenantIDTextField.stringValue.isEmpty && !applicationIDTextField.stringValue.isEmpty
    }
    
    /// Clears both tenant ID and application ID text fields
    /// Used for resetting the form when needed
    private func clearInputs() {
        tenantIDTextField.stringValue = ""
        applicationIDTextField.stringValue = ""
    }
    
    /// Updates validation button enabled state based on required field completion
    /// Button is only enabled when both tenant ID and application ID are provided
    private func updateValidationButtonStatus() {
        if tenantIDTextField.stringValue.isEmpty || applicationIDTextField.stringValue.isEmpty {
            validateEntraCredentialsButton.isEnabled = false
        } else {
            validateEntraCredentialsButton.isEnabled = true
        }
    }

    
    // MARK: - Alert Helper Methods
    
    /// Displays detailed permission requirements alert for failed validation
    /// Provides specific guidance on required Microsoft Graph API permissions
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

    
    // MARK: - Configuration Update Methods
    
    /// Updates the stored application ID via XPC service
    /// Trims whitespace and persists the application ID for authentication
    private func setApplicationID() {
        let appIDString = applicationIDTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setApplicationID(appIDString) { [self] success in
            Logger.logApp("Application ID updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }
    
    /// Updates the stored tenant ID via XPC service
    /// Trims whitespace and persists the tenant ID for authentication
    private func setTenantID() {
        let tenantIDString = tenantIDTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setTenantID(tenantIDString) { [self] success in
            Logger.logApp("Tenant ID updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    
    // MARK: - WizardStepProtocol Implementation
    
    /// Determines if the user can proceed from this wizard step
    /// Validation step is optional, so always returns true regardless of validation status
    /// - Returns: Always true as validation is not required to proceed
    func canProceed() -> Bool {
        return true
    }
    
    /// Validates the current wizard step before proceeding
    /// Validation step has no mandatory requirements, so always returns true
    /// - Returns: Always true as validation is optional
    func validateStep() -> Bool {
        return true
    }
    
    /// Provides the title for this wizard step for UI display
    /// Used by the wizard controller for step navigation and progress indication
    /// - Returns: Localized title string for the Entra ID validation step
    func getStepTitle() -> String {
        return "Entra ID Settings"
    }
    
    /// Provides a description of this wizard step for UI display
    /// Used by the wizard controller for step information and progress indication
    /// - Returns: Localized description string explaining the validation step purpose
    func getStepDescription() -> String {
        return "Configure and validate settings"
    }

}
