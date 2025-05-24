//
//  CertificateGenerator.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/2/25.
//

import Foundation

class CertificateGenerator {
    
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
            print(output)
        }

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "CommandError",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Command failed: \(command) \(arguments.joined(separator: " "))"]
            )
        }
    }

    static func generateCertificates(certName: String, outputPath: String, commonName: String, organization: String, country: String, password: String) throws {
        let privateKeyPath = "\(outputPath)/\(certName)_private.key"
        let csrPath = "\(outputPath)/\(certName)_request.csr"
        let crtPath = "\(outputPath)/\(certName)_certificate.crt"
        let pfxPath = "\(outputPath)/\(certName)_certificate.pfx"

        // Generate Private Key
        try runCommand("/usr/bin/openssl", arguments: [
            "genpkey", "-algorithm", "RSA", "-out", privateKeyPath, "-pkeyopt", "rsa_keygen_bits:2048"
        ])

        // Create CSR
        try runCommand("/usr/bin/openssl", arguments: [
            "req", "-new", "-key", privateKeyPath, "-out", csrPath, "-subj", "/CN=\(commonName)/O=\(organization)/C=\(country)"
        ])

        // Generate Self-Signed Certificate
        try runCommand("/usr/bin/openssl", arguments: [
            "x509", "-req", "-days", "365", "-in", csrPath, "-signkey", privateKeyPath, "-out", crtPath
        ])

        // Convert to PFX
        try runCommand("/usr/bin/openssl", arguments: [
            "pkcs12", "-export", "-out", pfxPath, "-inkey", privateKeyPath, "-in", crtPath, "-passout", "pass:\(password)"
        ])

        print("Certificates generated successfully at \(outputPath)")
    }

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

        // Extract the fingerprint value and remove colons
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
