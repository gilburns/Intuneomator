//
//  LabelAutomation+DownloadInspect.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/23/25.
//

import Foundation

extension LabelAutomation {
    
    // MARK: - Inspection of download
    static func inspectSignatureOfDownloadedSoftware(for downloadURL: URL, expectedTeamID: String, inspectionType: String) -> Bool {
        
        Logger.log("Inspecting \(inspectionType) signature...", logType: logType)
        
        switch inspectionType {
        case "pkg":
            
            // Inspect pkg
            var inspectionResult = [String: Any]()
            
            do {
                let pkgPath = downloadURL.path
                inspectionResult = try SignatureInspector.inspectPackageSignature(pkgPath: pkgPath)
                Logger.log("Package Signature Inspection Result: \(inspectionResult)", logType: logType)
                if let accepted = inspectionResult["Accepted"] as? Bool, accepted {
                    Logger.log("  Inspection Passed", logType: logType)
                } else {
                    Logger.log("  Inspection Failed", logType: logType)
                    throw NSError(domain: "LabelAutomation", code: 1001, userInfo: [NSLocalizedDescriptionKey : "Package signature inspection failed"])
                }
                
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
            // Inspect app
            var inspectionResult = [String: Any]()
            
            do {
                let appPath = downloadURL.path
                inspectionResult = try SignatureInspector.inspectAppSignature(appPath: appPath)
                Logger.log("  Application Signature Inspection Result: \(inspectionResult)", logType: logType)
                if let accepted = inspectionResult["Accepted"] as? Bool, accepted {
                    Logger.log("  Inspection Passed", logType: logType)
                } else {
                    Logger.log("  Inspection Failed", logType: logType)
                    throw NSError(domain: "LabelAutomation", code: 1001, userInfo: [NSLocalizedDescriptionKey : "Package signature inspection failed"])
                }
                
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
            
        default:
            Logger.log("Unsupported file type: \(inspectionType)", logType: logType)
            return false
            
        }
        return true
    }
    

}
