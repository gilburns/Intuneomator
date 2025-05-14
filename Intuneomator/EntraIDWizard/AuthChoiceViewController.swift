//
//  AuthChoiceViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa
import Security

// This class is responsible for the configuration choice view in the wizard.
class AuthChoiceViewController: NSViewController, WizardStepProtocol {
    var onCompletionStatusChanged: ((Bool) -> Void)?
//    var isStepCompleted: Bool { return false } // ✅ Read-only, so always complete
    
    var hasPrivateKey: Bool?
    var hasSecretKey: Bool?
    
    @IBOutlet weak var radioButtonCertificate: NSButton!
    @IBOutlet weak var radioButtonSecret: NSButton!
    
    @IBOutlet weak var buttonImportCert: NSButton!
    @IBOutlet weak var buttonSaveSecretKey: NSButton!
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        getAuthMethod()
        checkAuthSetupStatus(completion: self.inputChanged)
    }
    
    
    override func viewDidAppear() {
        super.viewDidAppear()
        checkAuthSetupStatus(completion: self.inputChanged)
    }
    
    
    static func create() -> AuthChoiceViewController {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "AuthChoiceViewController") as! AuthChoiceViewController
    }
    
    
    
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

    
    func checkAuthSetupStatus(completion: @escaping () -> Void) {
        let group = DispatchGroup()

        group.enter()
        XPCManager.shared.privateKeyExists { exists in
            self.hasPrivateKey = exists ?? false
            #if DEBUG
            Logger.logUser("privateKeyExists returned: \(self.hasPrivateKey!)", logType: "SetupWizard")
            #endif
            group.leave()
        }

        group.enter()
        XPCManager.shared.entraIDSecretKeyExists { exists in
            self.hasSecretKey = exists ?? false
            #if DEBUG
            Logger.logUser("entraIDSecretKeyExists returned: \(self.hasSecretKey!)", logType: "SetupWizard")
            #endif
            group.leave()
        }

        group.notify(queue: .main) {
            #if DEBUG
            Logger.logUser("Auth setup check completed. hasPrivateKey: \(self.hasPrivateKey!), hasSecretKey: \(self.hasSecretKey!)", logType: "SetupWizard")
            #endif
            completion()
        }
    }
    
    
    func isPrivateKeyReady(completion: @escaping (Bool) -> Void) {
        XPCManager.shared.privateKeyExists { exists in
            completion(exists ?? false)
        }
    }
    
    func isSecretKeyReady(completion: @escaping (Bool) -> Void) {
        XPCManager.shared.entraIDSecretKeyExists { exists in
            completion(exists ?? false)
        }
    }

    
    var isStepCompleted: Bool {
        return (hasPrivateKey ?? false) || (hasSecretKey ?? false)
    }
    
    // MARK: Select Auth Method - If Configured
    func getAuthMethod() {
        #if DEBUG
        Logger.logUser("getAuthMethod", logType: "SetupWizard")
        #endif
        XPCManager.shared.getAuthMethod { authMethod in
            DispatchQueue.main.async {
                
                #if DEBUG
                if let method = authMethod {
                    Logger.logUser(method.capitalized, logType: "SetupWizard")
                } else {
                    Logger.logUser("authMethod is nil", logType: "SetupWizard")
                }
                #endif
                
                switch authMethod?.capitalized ?? "Certificate" {
                case "Certificate": // Certificate
                    #if DEBUG
                    Logger.logUser("Certificate", logType: "SetupWizard")
                    #endif
                    self.buttonImportCert.isEnabled = true
                    self.buttonSaveSecretKey.isEnabled = false
                    self.radioButtonCertificate.performClick(self)
                    //            settings.connectMethod = "Cert"
                case "Secret": // Secret
                    #if DEBUG
                    Logger.logUser("Secret", logType: "SetupWizard")
                    #endif
                    self.buttonImportCert.isEnabled = false
                    self.buttonSaveSecretKey.isEnabled = true
                    self.radioButtonSecret.performClick(self)
                    
                    //            settings.connectMethod = "Secret"
                default:
                    break
                }
            }
        }
    }
    
    @objc func inputChanged() {
        var selectedMethod: String
        if radioButtonSecret.state == .on {
            selectedMethod = "secret"
        } else {
            selectedMethod = "certificate"
        }
        
        XPCManager.shared.setAuthMethod(selectedMethod) { success in
            #if DEBUG
            if success ?? false {
                Logger.logUser("Successfully updated auth method to: \(selectedMethod)", logType: "SetupWizard")
            } else {
                Logger.logUser("Failed to update auth method.", logType: "SetupWizard")
            }
            #endif
        }
        
        let completed = isStepCompleted
        #if DEBUG
        Logger.logUser("inputChanged -> isStepCompleted: \(completed)", logType: "SetupWizard")
        #endif
        onCompletionStatusChanged?(completed) // ✅ Notify `WelcomeWizardViewController`
    }

    
    @IBAction func radioButtonClicked(_ sender: NSButton) {
        switch sender.tag {
        case 1: // Certificate
            buttonImportCert.isEnabled = true
            buttonSaveSecretKey.isEnabled = false
            inputChanged()
            //            settings.connectMethod = "Cert"
        case 2: // Secret
            buttonImportCert.isEnabled = false
            buttonSaveSecretKey.isEnabled = true
            inputChanged()
            //            settings.connectMethod = "Secret"
        default:
            break
        }
    }
    
    
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
        Logger.logUser("Selected file: \(fileURL.path)", logType: "SetupWizard")
        Logger.logUser("Entered passphrase: \(passphrase)", logType: "SetupWizard") // Remove this in production for security reasons
        
        do {
            let p12Data = try Data(contentsOf: fileURL)
            XPCManager.shared.importP12Certificate(p12Data: p12Data, passphrase: passphrase) { success in
                DispatchQueue.main.async {
                    if success ?? false {
                        Logger.logUser("Successfully imported .p12 into the daemon.", logType: "SetupWizard")
                        DispatchQueue.main.async {
                            self.showAlert(title: "Success", message: "Import was successful.")
                        }
                        self.onCompletionStatusChanged?(true)
                    } else {
                        Logger.logUser("Failed to import .p12.", logType: "SetupWizard")
                        DispatchQueue.main.async {
                            self.showAlert(title: "Success", message: "Import failed.")
                        }

                    }
                }
            }
        } catch {
            Logger.logUser("Failed to read .p12 file: \(error)", logType: "SetupWizard")
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
        Logger.logUser("Entered Entra ID Secret Key: \(secretKey)", logType: "SetupWizard") // Do NOT log in production
        
        Logger.logUser("Saving secret key...", logType: "SetupWizard")
        XPCManager.shared.importEntraIDSecretKey(secretKey: secretKey) { success in
            if success ?? false {
                Logger.logUser("Successfully imported Entra ID secret key.", logType: "SetupWizard")
                DispatchQueue.main.async {
                    self.showAlert(title: "Success", message: "Import was successful.")
                    self.onCompletionStatusChanged?(true)
                }
            } else {
                Logger.logUser("Failed to import Entra ID secret key.", logType: "SetupWizard")
                DispatchQueue.main.async {
                    self.showAlert(title: "Failed", message: "Import failed.")
                }

            }
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

}
