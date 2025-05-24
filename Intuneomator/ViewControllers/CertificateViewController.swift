//
//  CertificateViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/5/25.
//


import Cocoa
import Foundation

class CertificateViewController: NSViewController {
    @IBOutlet weak var certNameField: NSTextField!
    @IBOutlet weak var outputPathField: NSTextField!
    @IBOutlet weak var commonNameField: NSTextField!
    @IBOutlet weak var organizationField: NSTextField!
    @IBOutlet weak var countryField: NSTextField!
    @IBOutlet weak var passwordField: NSTextField! // New password field
    @IBOutlet weak var thumbprintLabel: NSTextField! // Outputs the certificate thumbprint
    @IBOutlet weak var statusLabel: NSTextField! // New status field
    @IBOutlet weak var generateButton: NSButton! // Generate button

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
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Ensure the window is fixed and non-resizable
        if let window = self.view.window {
            window.styleMask.remove(.resizable) // Remove the resizable property
            window.minSize = window.frame.size  // Set minimum size
            window.maxSize = window.frame.size  // Set maximum size
        }

    }

    @objc private func textFieldDidChange(_ sender: NSTextField) {
        updateGenerateButtonState()
    }

    private func updateGenerateButtonState() {
        let isFormValid = !certNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                          !outputPathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                          !commonNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                          !organizationField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                          !countryField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                          !passwordField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        generateButton.isEnabled = isFormValid
    }


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
