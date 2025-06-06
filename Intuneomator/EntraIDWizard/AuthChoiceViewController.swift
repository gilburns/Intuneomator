//
//  AuthChoiceViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa
import Security

/// Authentication method selection view controller for the Entra ID setup wizard
/// Provides choice between certificate-based and secret-based authentication for Microsoft Graph API
/// Handles P12 certificate import and client secret configuration with validation
/// Implements WizardStepProtocol for integration with the multi-step wizard flow
class AuthChoiceViewController: NSViewController, WizardStepProtocol {
    
    // MARK: - WizardStepProtocol Properties
    
    /// Callback closure for notifying wizard of completion status changes
    var onCompletionStatusChanged: ((Bool) -> Void)?
    
    /// Authentication readiness status tracking
    var hasPrivateKey: Bool?
    var hasSecretKey: Bool?
    
    /// Log type identifier for logging operations
    private let logType = "Settings"

    // MARK: - Interface Builder Outlets
    
    /// Radio button for selecting certificate-based authentication method
    @IBOutlet weak var radioButtonCertificate: NSButton!
    
    /// Radio button for selecting client secret-based authentication method
    @IBOutlet weak var radioButtonSecret: NSButton!
    
    /// Button to initiate P12 certificate import process
    @IBOutlet weak var buttonImportCert: NSButton!
    
    /// Button to configure Entra ID client secret
    @IBOutlet weak var buttonSaveSecretKey: NSButton!
    
    
    // MARK: - View Lifecycle Methods
    
    /// Called after the view controller's view is loaded into memory
    /// Initializes authentication method selection and checks existing credential status
    override func viewDidLoad() {
        super.viewDidLoad()
        
        getAuthMethod()
        checkAuthSetupStatus(completion: self.inputChanged)
    }
    
    /// Called when the view controller's view appears on screen
    /// Refreshes authentication status to reflect any changes from other views
    override func viewDidAppear() {
        super.viewDidAppear()
        checkAuthSetupStatus(completion: self.inputChanged)
    }
    
    // MARK: - Factory Method
    
    /// Factory method for creating an instance from the Wizard storyboard
    /// Provides type-safe instantiation from storyboard with proper identifier
    /// - Returns: Configured AuthChoiceViewController instance
    static func create() -> AuthChoiceViewController {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "AuthChoiceViewController") as! AuthChoiceViewController
    }
    
    
    // MARK: - XPC Service Status Methods
    
    /// Synchronously checks if the XPC service is running and responsive
    /// Uses semaphore to block until service responds or timeout occurs
    /// - Returns: Boolean indicating XPC service availability
    func checkXPCServiceRunning() -> Bool {
        var isRunning = false
        let semaphore = DispatchSemaphore(value: 0)
        
        XPCManager.shared.checkXPCServiceRunning { success in
            isRunning = success ?? false
            semaphore.signal()
        }
        
        // Wait with timeout for a response
        _ = semaphore.wait(timeout: .now() + 2.0)
        
        return isRunning
    }

    // MARK: - Authentication Status Methods
    
    /// Asynchronously checks the availability of authentication credentials
    /// Uses dispatch group to coordinate multiple XPC calls and update UI state
    /// - Parameter completion: Callback executed after all authentication checks complete
    func checkAuthSetupStatus(completion: @escaping () -> Void) {
        let group = DispatchGroup()

        group.enter()
        XPCManager.shared.privateKeyExists { [self] exists in
            self.hasPrivateKey = exists ?? false
            #if DEBUG
            Logger.logApp("privateKeyExists returned: \(self.hasPrivateKey!)", logType: logType)
            #endif
            group.leave()
        }

        group.enter()
        XPCManager.shared.entraIDSecretKeyExists { [self] exists in
            self.hasSecretKey = exists ?? false
            #if DEBUG
            Logger.logApp("entraIDSecretKeyExists returned: \(self.hasSecretKey!)", logType: logType)
            #endif
            group.leave()
        }

        group.notify(queue: .main) { [self] in
            #if DEBUG
            Logger.logApp("Auth setup check completed. hasPrivateKey: \(self.hasPrivateKey!), hasSecretKey: \(self.hasSecretKey!)", logType: logType)
            #endif
            completion()
        }
    }
    
    /// Checks if certificate-based authentication is configured and ready
    /// - Parameter completion: Callback with boolean indicating private key availability
    func isPrivateKeyReady(completion: @escaping (Bool) -> Void) {
        XPCManager.shared.privateKeyExists { exists in
            completion(exists ?? false)
        }
    }
    
    /// Checks if secret-based authentication is configured and ready
    /// - Parameter completion: Callback with boolean indicating client secret availability
    func isSecretKeyReady(completion: @escaping (Bool) -> Void) {
        XPCManager.shared.entraIDSecretKeyExists { exists in
            completion(exists ?? false)
        }
    }

    /// Computed property indicating if the wizard step has been completed
    /// Step is complete when either certificate or secret authentication is configured
    var isStepCompleted: Bool {
        return (hasPrivateKey ?? false) || (hasSecretKey ?? false)
    }
    
    // MARK: - Authentication Method Configuration
    
    /// Retrieves and applies the currently configured authentication method
    /// Updates UI controls and radio button selection based on stored preference
    func getAuthMethod() {
        #if DEBUG
        Logger.logApp("getAuthMethod", logType: logType)
        #endif
        XPCManager.shared.getAuthMethod { authMethod in
            DispatchQueue.main.async { [self] in
                
                #if DEBUG
                if let method = authMethod {
                    Logger.logApp(method.capitalized, logType: logType)
                } else {
                    Logger.logApp("authMethod is nil", logType: logType)
                }
                #endif
                
                switch authMethod?.capitalized ?? "Certificate" {
                case "Certificate": // Certificate-based authentication
                    #if DEBUG
                    Logger.logApp("Certificate", logType: logType)
                    #endif
                    self.buttonImportCert.isEnabled = true
                    self.buttonSaveSecretKey.isEnabled = false
                    self.radioButtonCertificate.performClick(self)
                case "Secret": // Client secret-based authentication
                    #if DEBUG
                    Logger.logApp("Secret", logType: logType)
                    #endif
                    self.buttonImportCert.isEnabled = false
                    self.buttonSaveSecretKey.isEnabled = true
                    self.radioButtonSecret.performClick(self)
                default:
                    break
                }
            }
        }
    }
    /// Handles authentication method selection changes and updates configuration
    /// Persists the selected method via XPC and notifies wizard of completion status
    @objc func inputChanged() {
        var selectedMethod: String
        if radioButtonSecret.state == .on {
            selectedMethod = "secret"
        } else {
            selectedMethod = "certificate"
        }
        
        XPCManager.shared.setAuthMethod(selectedMethod) { [self] success in
            #if DEBUG
            if success ?? false {
                Logger.logApp("Successfully updated auth method to: \(selectedMethod)", logType: logType)
            } else {
                Logger.logApp("Failed to update auth method.", logType: logType)
            }
            #endif
        }
        
        let completed = isStepCompleted
        #if DEBUG
        Logger.logApp("inputChanged -> isStepCompleted: \(completed)", logType: logType)
        #endif
        onCompletionStatusChanged?(completed) // Notify wizard of completion status change
    }

    
    // MARK: - User Action Methods
    
    /// Opens the certificate generation utility as a modal sheet
    /// Provides access to the certificate creation workflow for users without existing certificates
    /// - Parameter sender: The certificate generation button that triggered the action
    @IBAction func openCertificateGeneration(_ sender: Any) {
        // Show Certificate Generator
        let storyboard = NSStoryboard(name: "CertificateGenerator", bundle: nil)
        guard let controller = storyboard.instantiateController(withIdentifier: "CertificateViewController") as? CertificateViewController else { return }

        presentAsSheet(controller)
    }

    /// Handles radio button selection for authentication method choice
    /// Updates UI button states and persists the selected authentication method
    /// - Parameter sender: The radio button that triggered the selection change
    @IBAction func radioButtonClicked(_ sender: NSButton) {
        switch sender.tag {
        case 1: // Certificate-based authentication selected
            buttonImportCert.isEnabled = true
            buttonSaveSecretKey.isEnabled = false
            inputChanged()
        case 2: // Client secret-based authentication selected
            buttonImportCert.isEnabled = false
            buttonSaveSecretKey.isEnabled = true
            inputChanged()
        default:
            break
        }
    }
    
    // MARK: - Certificate Import Methods
    
    /// Initiates P12 certificate file selection and import process
    /// Displays file picker for P12/PFX certificate files and handles selection
    /// - Parameter sender: The import certificate button that triggered the action
    @IBAction func selectP12File(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [ .p12 ]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.title = "Select a .p12 or .pfx File"
        openPanel.message = "Select a .p12 or .pfx File"
        
        openPanel.begin { result in
            if result == .OK, let selectedFileURL = openPanel.url {
                self.requestPassphrase(for: selectedFileURL)
            }
        }
    }
    
    /// Prompts user for P12 certificate file passphrase using secure input
    /// Displays modal alert with secure text field for passphrase entry
    /// - Parameter fileURL: URL of the selected P12 certificate file
    private func requestPassphrase(for fileURL: URL) {
        let fileExtension = fileURL.pathExtension
        
        let alert = NSAlert()
        alert.messageText = "Enter Passphrase"
        alert.informativeText = "Enter the passphrase for the selected .\(fileExtension) file."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        // Secure text field for passphrase input
        let secureTextField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        alert.accessoryView = secureTextField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let passphrase = secureTextField.stringValue
            processP12File(fileURL: fileURL, passphrase: passphrase)
        }
    }
    
    /// Processes P12 certificate file import with provided passphrase
    /// Reads certificate data and imports it via XPC service with user feedback
    /// - Parameters:
    ///   - fileURL: URL of the P12 certificate file to import
    ///   - passphrase: Passphrase for decrypting the P12 certificate
    private func processP12File(fileURL: URL, passphrase: String) {
        Logger.logApp("Selected file: \(fileURL.path)", logType: logType)
        Logger.logApp("Entered passphrase: \(passphrase)", logType: logType) // Remove this in production for security reasons
        
        do {
            let p12Data = try Data(contentsOf: fileURL)
            XPCManager.shared.importP12Certificate(p12Data: p12Data, passphrase: passphrase) { success in
                DispatchQueue.main.async { [self] in
                    if success ?? false {
                        Logger.logApp("Successfully imported .p12 into the daemon.", logType: logType)
                        DispatchQueue.main.async {
                            self.showAlert(title: "Success", message: "Import was successful.")
                        }
                        self.onCompletionStatusChanged?(true)
                    } else {
                        Logger.logApp("Failed to import .p12.", logType: logType)
                        DispatchQueue.main.async {
                            self.showAlert(title: "Failed", message: "Import failed.")
                        }
                    }
                }
            }
        } catch {
            Logger.logApp("Failed to read .p12 file: \(error)", logType: logType)
        }
    }
    
    // MARK: - Client Secret Configuration Methods
    
    /// Initiates Entra ID client secret key input and validation process
    /// Displays secure input dialog with validation and retry logic for empty input
    /// - Parameter sender: The save secret key button that triggered the action
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
                // Show error alert for empty input and retry
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
    
    /// Processes and stores the validated Entra ID client secret with optional expiration notification
    /// Imports secret via XPC service and offers expiration date configuration
    /// - Parameter secretKey: The validated client secret string to import
    private func handleEntraIDSecretKey(_ secretKey: String) {
        Logger.logApp("Entered Entra ID Secret Key: \(secretKey)", logType: logType) // Do NOT log in production

        Logger.logApp("Saving secret key...", logType: logType)
        XPCManager.shared.importEntraIDSecretKey(secretKey: secretKey) { [self] success in
            if success ?? false {
                Logger.logApp("Successfully imported Entra ID secret key.", logType: logType)
                DispatchQueue.main.async {
                    self.onCompletionStatusChanged?(true)

                    let alert = NSAlert()
                    alert.messageText = "Success"
                    alert.informativeText = "Import was successful. Would you like to set an expiration notification for the secret?"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Yes")
                    alert.addButton(withTitle: "No")

                    // Date picker for setting secret expiration notification
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
                Logger.logApp("Failed to import Entra ID secret key.", logType: logType)
                DispatchQueue.main.async {
                    self.showAlert(title: "Failed", message: "Import failed.")
                }
            }
        }
    }


    // MARK: - Alert Helper Methods
    
    /// Displays styled alert dialog with custom title, message, and alert style
    /// Currently contains placeholder implementation that needs completion
    /// - Parameters:
    ///   - title: Alert dialog title text
    ///   - message: Alert dialog message text
    ///   - style: NSAlert.Style for visual presentation
    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        DispatchQueue.main.async {
            self.showAlert(title: "Success", message: "Import succeeded.")
        }
    }
    
    /// Displays simple informational alert dialog with title and message
    /// Used for user feedback on import success/failure and configuration updates
    /// - Parameters:
    ///   - title: Alert dialog title text
    ///   - message: Alert dialog message text
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    
    // MARK: - WizardStepProtocol Implementation
    
    /// Determines if the user can proceed from this wizard step
    /// Step is complete when either certificate or secret authentication is configured
    /// - Returns: Boolean indicating if authentication credentials are available
    func canProceed() -> Bool {
        return isStepCompleted
    }
    
    /// Validates the current wizard step before proceeding
    /// Ensures at least one authentication method has been properly configured
    /// - Returns: Boolean indicating if step validation passed
    func validateStep() -> Bool {
        return isStepCompleted
    }
    
    /// Provides the title for this wizard step for UI display
    /// Used by the wizard controller for step navigation and progress indication
    /// - Returns: Localized title string for the authentication choice step
    func getStepTitle() -> String {
        return "Authentication"
    }
    
    /// Provides a description of this wizard step for UI display
    /// Used by the wizard controller for step information and progress indication
    /// - Returns: Localized description string explaining the authentication choice purpose
    func getStepDescription() -> String {
        return "Choose authentication method"
    }

}
