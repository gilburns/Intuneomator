//
//  LabelAutomation+DownloadInspect.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/23/25.
//

import Foundation

// MARK: - Download Inspection Extension

/// Extension for signature verification and security validation of downloaded software
/// Provides cryptographic signature inspection for PKG and APP files to ensure authenticity and integrity
extension LabelAutomation {
    
    // MARK: - Code Signature Verification
    
    /// Inspects the digital signature of downloaded software to verify authenticity and developer identity
    /// Validates code signatures and team IDs to prevent installation of unsigned or malicious software
    /// - Parameters:
    ///   - downloadURL: The file system location of the downloaded software
    ///   - expectedTeamID: The Apple Developer Team ID that should match the software signature
    ///   - inspectionType: The type of file being inspected ("pkg" for packages, "app" for applications)
    /// - Returns: True if signature validation passes and team ID matches, false if any verification fails
    static func inspectSignatureOfDownloadedSoftware(for downloadURL: URL, expectedTeamID: String, inspectionType: String) -> Bool {
        
        Logger.log("Inspecting \(inspectionType) signature...", logType: logType)
        
        // Route to appropriate signature inspection method based on file type
        switch inspectionType {
        case "pkg":
            
            // PKG Package Signature Verification
            var inspectionResult = [String: Any]()
            
            do {
                let pkgPath = downloadURL.path
                
                // Execute cryptographic signature inspection using SignatureInspector utility
                inspectionResult = try SignatureInspector.inspectPackageSignature(pkgPath: pkgPath)
                Logger.log("Package Signature Inspection Result: \(inspectionResult)", logType: logType)
                
                // Verify that the package signature is accepted by the system
                if let accepted = inspectionResult["Accepted"] as? Bool, accepted {
                    Logger.log("  Inspection Passed", logType: logType)
                } else {
                    Logger.log("  Inspection Failed", logType: logType)
                    throw NSError(domain: "LabelAutomation", code: 1001, userInfo: [NSLocalizedDescriptionKey : "Package signature inspection failed"])
                }
                
                // Validate Developer Team ID matches expected value for security
                if let teamID = inspectionResult["DeveloperTeam"] as? String {
                    Logger.log("  Download Team ID: \(teamID)", logType: logType)
                    Logger.log("  Expected Team ID: \(expectedTeamID)", logType: logType)
                    if teamID != expectedTeamID {
                        Logger.log("  Team ID mismatch! Expected: \(expectedTeamID), Actual: \(teamID)", logType: logType)
                        throw NSError(domain: "LabelAutomation", code: 1003, userInfo: [NSLocalizedDescriptionKey : "Team ID mismatch"])
                    } else {
                        Logger.log("  Team ID matches", logType: logType)
                    }
                }
            } catch {
                Logger.log("Error inspecting package: \(error)", logType: logType)
                return false
            }
            
        case "app":
            
            // APP Application Signature Verification
            var inspectionResult = [String: Any]()
            
            do {
                let appPath = downloadURL.path
                
                // Execute cryptographic signature inspection for application bundles
                inspectionResult = try SignatureInspector.inspectAppSignature(appPath: appPath)
                Logger.log("  Application Signature Inspection Result: \(inspectionResult)", logType: logType)
                
                // Verify that the application signature is accepted by the system
                if let accepted = inspectionResult["Accepted"] as? Bool, accepted {
                    Logger.log("  Inspection Passed", logType: logType)
                } else {
                    Logger.log("  Inspection Failed", logType: logType)
                    throw NSError(domain: "LabelAutomation", code: 1001, userInfo: [NSLocalizedDescriptionKey : "Application signature inspection failed"])
                }
                
                // Validate Developer Team ID matches expected value for security
                if let teamID = inspectionResult["DeveloperTeam"] as? String {
                    Logger.log("  Download Team ID: \(teamID)", logType: logType)
                    Logger.log("  Expected Team ID: \(expectedTeamID)", logType: logType)
                    if teamID != expectedTeamID {
                        Logger.log("  Team ID mismatch! Expected: \(expectedTeamID), Actual: \(teamID)", logType: logType)
                        throw NSError(domain: "LabelAutomation", code: 1003, userInfo: [NSLocalizedDescriptionKey : "Team ID mismatch"])
                    } else {
                        Logger.log("  Team ID matches", logType: logType)
                    }
                }
            } catch {
                Logger.log("Error inspecting application: \(error)", logType: logType)
                return false
            }
            
        default:
            // Handle unsupported file types
            Logger.log("Unsupported file type: \(inspectionType)", logType: logType)
            Logger.log("Supported types: 'pkg' (installer packages) and 'app' (application bundles)", logType: logType)
            return false
            
        }
        
        // All signature validations passed successfully
        Logger.log("✅ Signature inspection completed successfully for \(inspectionType)", logType: logType)
        return true
    }

}
