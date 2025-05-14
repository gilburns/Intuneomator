//
//  SignatureInspector.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/23/25.
//

import Foundation

class SignatureInspector {
    enum InspectionError: Error {
        case invalidPath
        case spctlError(String)
        case parsingError(String)
    }

    
    /// Verifies the signature of a `.pkg` file
    /// - Parameter pkgPath: The path to the `.pkg` file to inspect.
    /// - Returns: A dictionary with keys `Accepted`, `DeveloperID`, and `DeveloperTeam`.
    static func inspectPackageSignature(pkgPath: String) throws -> [String: Any] {
        return try runSpctlCommand(for: pkgPath, type: "install")
    }

    
    /// Verifies the signature of an `.app` bundle
    /// - Parameter appPath: The path to the `.app` bundle to inspect.
    /// - Returns: A dictionary with keys `Accepted`, `DeveloperID`, and `DeveloperTeam`.
    static func inspectAppSignature(appPath: String) throws -> [String: Any] {
        return try runSpctlCommand(for: appPath, type: "execute")
    }

    
    /// Runs the `spctl` command and parses the output
    /// - Parameters:
    ///   - path: The path to the file to inspect.
    ///   - type: The spctl type (`install` for .pkg, `execute` for .app).
    /// - Returns: A dictionary with the parsed output.
    private static func runSpctlCommand(for path: String, type: String) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: path) else {
            throw InspectionError.invalidPath
        }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/spctl")
        process.arguments = ["-a", "-vv", "-t", type, path]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw InspectionError.spctlError("Failed to execute spctl command.")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw InspectionError.spctlError("Failed to read spctl output.")
        }

        return try parseSpctlOutput(output)
    }

    /// Parses the output of the `spctl` command
    /// - Parameter output: The raw output from `spctl`.
    /// - Returns: A dictionary with keys `Accepted`, `DeveloperID`, and `DeveloperTeam`.
    private static func parseSpctlOutput(_ output: String) throws -> [String: Any] {
        var result: [String: Any] = [:]

        // Check for acceptance or rejection
        if output.contains("accepted") {
            result["Accepted"] = true
        } else if output.contains("rejected") {
            result["Accepted"] = false
        } else {
            throw InspectionError.parsingError("Unknown response: \(output)")
        }

        // Extract `source` (if present)
        if let sourceLine = output.split(separator: "\n").first(where: { $0.contains("source=") }) {
            let sourceParts = sourceLine.split(separator: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            if sourceParts.count == 2 {
                result["Source"] = sourceParts[1]
            } else {
                result["Source"] = nil
            }
        } else {
            result["Source"] = nil
        }

        // Extract `origin` (Developer ID and Team)
        if let originLine = output.split(separator: "\n").first(where: { $0.contains("origin=") }) {
            let originParts = originLine.split(separator: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            if originParts.count == 2 {
                let originValue = originParts[1]

                if let openParenIndex = originValue.lastIndex(of: "("),
                   let closeParenIndex = originValue.lastIndex(of: ")") {
                    // Extract DeveloperTeam (value inside parentheses)
                    let developerTeam = String(originValue[originValue.index(after: openParenIndex)..<closeParenIndex])
                    result["DeveloperTeam"] = developerTeam

                    // Extract DeveloperID (trim prefix like "Developer ID Installer: " or "Developer ID Application: ")
                    let developerIDRaw = String(originValue[..<openParenIndex]).trimmingCharacters(in: .whitespaces)
                    if let colonIndex = developerIDRaw.firstIndex(of: ":") {
                        result["DeveloperID"] = String(developerIDRaw[developerIDRaw.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces))
                    } else {
                        result["DeveloperID"] = developerIDRaw // Fallback to raw value
                    }
                } else {
                    // No parentheses: Treat the entire origin value as the Team ID
                    result["DeveloperTeam"] = originValue
                    result["DeveloperID"] = originValue // For consistency
                }
            } else {
                result["DeveloperTeam"] = nil
                result["DeveloperID"] = nil
            }
        } else {
            result["DeveloperTeam"] = nil
            result["DeveloperID"] = nil
        }

        return result
    }
}


// Output example:
/*:
 
 {
"Accepted": true,
"DeveloperID": "Mozilla Corporation",
"DeveloperTeam": "43AQ936H96"
}
 
 */


// Inspect a pkg example:
/*
 
 do {
     let pkgPath = "/path/to/pkg/Firefox.pkg"
     let result = try SignatureInspector.inspectPackageSignature(pkgPath: pkgPath)
     print("Inspection Result: \(result)")
 } catch {
     print("Error inspecting package: \(error)")
 }
 
 */


// Inspect an app example:
/*
 
 do {
     let appPath = "/Applications/Firefox.app"
     let result = try SignatureInspector.inspectAppSignature(appPath: appPath)
     print("Inspection Result: \(result)")
 } catch {
     print("Error inspecting app: \(error)")
 }
 
 */
