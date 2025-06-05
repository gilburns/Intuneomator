//
//  CertificateViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/5/25.
//


import Cocoa
import Foundation

/// View controller for generating self-signed certificates for Microsoft Entra authentication
/// Provides a user interface for creating certificate pairs (public/private key) that can be
/// used for certificate-based authentication with Microsoft Graph API
/// 
/// **Key Features:**
/// - Generates self-signed X.509 certificates with custom metadata
/// - Creates certificate files (.crt, .key, .p12) for authentication
/// - Calculates and displays certificate thumbprints
/// - Validates form inputs before certificate generation
/// - Maintains fixed window size for consistent UI experience
class CertificateViewController: NSViewController {

    /// Text field for entering the base name of the certificate files to generate.
    @IBOutlet weak var certNameField: NSTextField!

    /// Text field displaying the directory path where certificate files will be saved.
    @IBOutlet weak var outputPathField: NSTextField!

    /// Text field for entering the certificate’s Common Name (CN) attribute.
    @IBOutlet weak var commonNameField: NSTextField!

    /// Text field for entering the certificate’s Organization (O) attribute.
    @IBOutlet weak var organizationField: NSTextField!

    /// Text field for entering the certificate’s Country (C) attribute (two-letter code).
    @IBOutlet weak var countryField: NSTextField!

    /// Secure text field for entering a password to protect the generated .p12 file.
    @IBOutlet weak var passwordField: NSTextField! // New password field

    /// Label that displays the generated certificate’s thumbprint (SHA-1 hash).
    @IBOutlet weak var thumbprintLabel: NSTextField! // Outputs the certificate thumbprint

    /// Label for showing status messages (e.g., errors or success notifications) to the user.
    @IBOutlet weak var statusLabel: NSTextField! // New status field

    /// Button that initiates the certificate generation process when clicked.
    @IBOutlet weak var generateButton: NSButton! // Generate button

    
    // MARK: Lifecycle
    /// Called after the view controller’s view has been loaded into memory.
    /// Initializes UI state: clears the thumbprint field, sets a default status message,
    /// and attaches change observers to form fields to enable/disable the Generate button.
    override func viewDidLoad() {
        super.viewDidLoad()
        thumbprintLabel.stringValue = ""
        statusLabel.stringValue = "Waiting for certificate generation..."
        updateGenerateButtonState()

        // Add observers for text field changes
        [certNameField, outputPathField, commonNameField, organizationField, countryField, passwordField].forEach {
            $0?.target = self
            $0?.action = #selector(textFieldDidChange(_:))
        }

    }
    
    /// Called when the view has appeared on screen.
    /// Enforces a fixed window size by disabling resizing and setting min/max dimensions.
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Ensure the window is fixed and non-resizable
        if let window = self.view.window {
            window.styleMask.remove(.resizable) // Remove the resizable property
            window.minSize = window.frame.size  // Set minimum size
            window.maxSize = window.frame.size  // Set maximum size
        }

    }

    /// Text field change handler invoked whenever one of the monitored fields is edited.
    /// - Calls `updateGenerateButtonState()` to enable or disable the Generate button based on form completeness.
    /// - Parameter sender: The text field that changed.
    @objc private func textFieldDidChange(_ sender: NSTextField) {
        updateGenerateButtonState()
    }

    /// Validates all form fields (name, path, CN, O, C, and password) are non-empty.
    /// - Enables the Generate button if the form is complete; otherwise disables it.
    private func updateGenerateButtonState() {
        let isFormValid = !certNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                          !outputPathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                          !commonNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                          !organizationField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                          !countryField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                          !passwordField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        generateButton.isEnabled = isFormValid
    }


    // MARK: Actions
    /// Action handler for the Generate button.
    /// - Reads and trims values from all input fields.
    /// - Validates non-empty values, then calls `CertificateGenerator.generateCertificates(...)`.
    /// - On success, calculates and displays the certificate thumbprint, writes a thumbprint text file,
    ///   and updates the status label.
    /// - On failure, displays an error message and clears the thumbprint field.
    /// - Parameter sender: The Generate button that was clicked.
    @IBAction func generateCertificateButtonClicked(_ sender: NSButton) {
        let certName = certNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let outputPath = outputPathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let commonName = commonNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let organization = organizationField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = countryField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) // Get password from input

        guard !certName.isEmpty, !outputPath.isEmpty, !commonName.isEmpty, !organization.isEmpty, !country.isEmpty, !password.isEmpty else {
            statusLabel.stringValue = "Error: All fields are required."
            return
        }
        
        do {
            try CertificateGenerator.generateCertificates(
                certName: certName,
                outputPath: outputPath,
                commonName: commonName,
                organization: organization,
                country: country,
                password: password
            )
            thumbprintLabel.stringValue = try CertificateGenerator.calculateThumbprint(for: "\(outputPath)/\(certName)_certificate.crt")

            statusLabel.stringValue = "Certificate files generated successfully."
            
            let outputURL = URL(fileURLWithPath: outputPath)
            let thumbprintTextFileURL = outputURL.appendingPathComponent("\(certName)_thumbprint.txt")
            
            let outputData = "Thumbprint: \(thumbprintLabel.stringValue)".data(using: .utf8)!
            FileManager.default.createFile(atPath: thumbprintTextFileURL.path, contents: outputData)
            

        } catch {
            statusLabel.stringValue = "Error: \(error.localizedDescription)"
            thumbprintLabel.stringValue = ""
        }
    }


    /// Action handler for the “Select Output Path” button.
    /// - Presents an NSOpenPanel configured to choose a directory.
    /// - Updates `outputPathField` with the chosen directory path if the user confirms.
    /// - Parameter sender: The button that was clicked.
    @IBAction func selectOutputPathButtonClicked(_ sender: NSButton) {
        let dialog = NSOpenPanel()
        dialog.message = "Select Output Directory"
        dialog.canChooseDirectories = true
        dialog.canCreateDirectories = true
        dialog.canChooseFiles = false
        dialog.allowsMultipleSelection = false
        
        if dialog.runModal() == .OK, let selectedURL = dialog.url {
            outputPathField.stringValue = selectedURL.path
        }
    }
}
