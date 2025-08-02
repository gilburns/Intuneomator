//
//  CertificateGenerator.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/2/25.
//

import Foundation

/// Utility class for generating X.509 certificates and certificate signing requests
/// Provides OpenSSL-based certificate generation for Microsoft Entra ID authentication
/// Creates self-signed certificates with private keys and exports to PFX format for import
class CertificateGenerator {
    
    // MARK: - Command Execution Methods
    
    /// Executes OpenSSL command line operations with error handling
    /// Runs specified command with arguments and captures output for debugging
    /// Throws errors if command execution fails or returns non-zero exit status
    /// - Parameters:
    ///   - command: Full path to the executable command (typically /usr/bin/openssl)
    ///   - arguments: Array of command line arguments to pass to the executable
    /// - Throws: NSError with CommandError domain if command execution fails
    static func runCommand(_ command: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            Logger.debug("\(output)", category: .debug)
        }

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "CommandError",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Command failed: \(command) \(arguments.joined(separator: " "))"]
            )
        }
    }


    // MARK: - Certificate Generation Methods
    
    /// Generates complete certificate chain including private key, CSR, certificate, and PFX export
    /// Creates all necessary files for Microsoft Entra ID certificate-based authentication
    /// Uses 2048-bit RSA encryption and 365-day validity period for self-signed certificates
    /// - Parameters:
    ///   - certName: Base name for generated certificate files (used as filename prefix)
    ///   - outputPath: Directory path where certificate files will be created
    ///   - commonName: Certificate common name (CN) field, typically application or service name
    ///   - organization: Certificate organization (O) field for certificate subject
    ///   - country: Certificate country (C) field, typically 2-letter country code
    ///   - password: Password for protecting the exported PFX/P12 certificate file
    /// - Throws: NSError if any step of certificate generation fails
    static func generateCertificates(certName: String, outputPath: String, commonName: String, organization: String, country: String, password: String) throws {
        let privateKeyPath = "\(outputPath)/\(certName)_private.key"
        let csrPath = "\(outputPath)/\(certName)_request.csr"
        let crtPath = "\(outputPath)/\(certName)_certificate.crt"
        let pfxPath = "\(outputPath)/\(certName)_certificate.pfx"

        // Generate 2048-bit RSA private key
        try runCommand("/usr/bin/openssl", arguments: [
            "genpkey", "-algorithm", "RSA", "-out", privateKeyPath, "-pkeyopt", "rsa_keygen_bits:2048"
        ])

        // Create certificate signing request (CSR) with subject information
        try runCommand("/usr/bin/openssl", arguments: [
            "req", "-new", "-key", privateKeyPath, "-out", csrPath, "-subj", "/CN=\(commonName)/O=\(organization)/C=\(country)"
        ])

        // Generate self-signed X.509 certificate valid for 365 days
        try runCommand("/usr/bin/openssl", arguments: [
            "x509", "-req", "-days", "365", "-in", csrPath, "-signkey", privateKeyPath, "-out", crtPath
        ])

        // Export certificate and private key to password-protected PFX format
        try runCommand("/usr/bin/openssl", arguments: [
            "pkcs12", "-export", "-out", pfxPath, "-inkey", privateKeyPath, "-in", crtPath, "-passout", "pass:\(password)"
        ])

        Logger.info("Certificates generated successfully at \(outputPath)", category: .core)
    }

    // MARK: - Certificate Analysis Methods
    
    /// Calculates SHA-1 thumbprint (fingerprint) of an X.509 certificate file
    /// Required for Microsoft Entra ID certificate authentication configuration
    /// Processes PEM format certificate files and returns formatted thumbprint string
    /// - Parameter certificatePath: File system path to the PEM format certificate file
    /// - Returns: SHA-1 thumbprint as uppercase hexadecimal string without colons
    /// - Throws: NSError with ThumbprintError domain if calculation or parsing fails
    static func calculateThumbprint(for certificatePath: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = ["x509", "-noout", "-fingerprint", "-sha1", "-inform", "pem", "-in", certificatePath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8), process.terminationStatus == 0 else {
            throw NSError(
                domain: "ThumbprintError",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Failed to calculate thumbprint."]
            )
        }

        // Extract the fingerprint value from OpenSSL output and format for Entra ID
        // OpenSSL output format: "SHA1 Fingerprint=XX:XX:XX:XX..."
        // Entra ID requires format: "XXXXXXXX..." (no colons, uppercase)
        if let fingerprint = output.split(separator: "=").last?.replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespacesAndNewlines) {
            return fingerprint
        } else {
            throw NSError(
                domain: "ThumbprintError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not parse thumbprint."]
            )
        }
    }
    
}
