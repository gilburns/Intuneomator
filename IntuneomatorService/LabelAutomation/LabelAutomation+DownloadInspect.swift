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
        
        Logger.info("Inspecting \(inspectionType) signature...", category: .automation)
        
        // Route to appropriate signature inspection method based on file type
        switch inspectionType {
        case "pkg":
            
            // PKG Package Signature Verification
            var inspectionResult = [String: Any]()
            
            do {
                let pkgPath = downloadURL.path
                
                // Execute cryptographic signature inspection using SignatureInspector utility
                inspectionResult = try SignatureInspector.inspectPackageSignature(pkgPath: pkgPath)
                Logger.info("Package Signature Inspection Result: \(inspectionResult)", category: .automation)
                
                // Verify that the package signature is accepted by the system
                if let accepted = inspectionResult["Accepted"] as? Bool, accepted {
                    Logger.info("  Inspection Passed", category: .automation)
                } else {
                    Logger.error("  Inspection Failed", category: .automation)
                    throw NSError(domain: "LabelAutomation", code: 1001, userInfo: [NSLocalizedDescriptionKey : "Package signature inspection failed"])
                }
                
                // Validate Developer Team ID matches expected value for security
                if let teamID = inspectionResult["DeveloperTeam"] as? String {
                    Logger.info("  Download Team ID: \(teamID)", category: .automation)
                    Logger.info("  Expected Team ID: \(expectedTeamID)", category: .automation)
                    if teamID != expectedTeamID {
                        Logger.error("  Team ID mismatch! Expected: \(expectedTeamID), Actual: \(teamID)", category: .automation)
                        throw NSError(domain: "LabelAutomation", code: 1003, userInfo: [NSLocalizedDescriptionKey : "Team ID mismatch"])
                    } else {
                        Logger.info("  Team ID matches", category: .automation)
                    }
                }
            } catch {
                Logger.error("Error inspecting package: \(error)", category: .automation)
                return false
            }
            
        case "app":
            
            // APP Application Signature Verification
            var inspectionResult = [String: Any]()
            
            do {
                let appPath = downloadURL.path
                
                // Execute cryptographic signature inspection for application bundles
                inspectionResult = try SignatureInspector.inspectAppSignature(appPath: appPath)
                Logger.info("  Application Signature Inspection Result: \(inspectionResult)", category: .automation)
                
                // Verify that the application signature is accepted by the system
                if let accepted = inspectionResult["Accepted"] as? Bool, accepted {
                    Logger.info("  Inspection Passed", category: .automation)
                } else {
                    Logger.error("  Inspection Failed", category: .automation)
                    throw NSError(domain: "LabelAutomation", code: 1001, userInfo: [NSLocalizedDescriptionKey : "Application signature inspection failed"])
                }
                
                // Validate Developer Team ID matches expected value for security
                if let teamID = inspectionResult["DeveloperTeam"] as? String {
                    Logger.info("  Download Team ID: \(teamID)", category: .automation)
                    Logger.info("  Expected Team ID: \(expectedTeamID)", category: .automation)
                    if teamID != expectedTeamID {
                        Logger.error("  Team ID mismatch! Expected: \(expectedTeamID), Actual: \(teamID)", category: .automation)
                        throw NSError(domain: "LabelAutomation", code: 1003, userInfo: [NSLocalizedDescriptionKey : "Team ID mismatch"])
                    } else {
                        Logger.info("  Team ID matches", category: .automation)
                    }
                }
            } catch {
                Logger.error("Error inspecting application: \(error)", category: .automation)
                return false
            }
            
        default:
            // Handle unsupported file types
            Logger.info("Unsupported file type: \(inspectionType)", category: .automation)
            Logger.info("Supported types: 'pkg' (installer packages) and 'app' (application bundles)", category: .automation)
            return false
            
        }
        
        // All signature validations passed successfully
        Logger.info("✅ Signature inspection completed successfully for \(inspectionType)", category: .automation)
        return true
    }

}
