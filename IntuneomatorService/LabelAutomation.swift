//
//  LabelAutomation.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/28/25.
//

import Foundation

class LabelAutomation {
    private static let logType = "LabelAutomation"

    // MARK: - Scan Folders to start the automation run
    static func scanAndValidateFolders() -> [String] {
        FolderScanner.scanAndValidateFolders()
    }
    
    
    // MARK: - Process label.sh for a given folder
    static func getIntuneomatorAppPath() -> String? {
        let possiblePaths = [
            "/Applications/Intuneomator.app",
            "\(NSHomeDirectory())/Applications/Intuneomator.app",
            "/usr/local/Intuneomator.app"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        Logger.log("❌ Could not find Intuneomator.app in expected locations.", logType: logType)
        return nil
    }
    
    
    static func containsArchCommand(filePath: String) -> Bool {
        do {
            // Attempt to read the contents of the file
            let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Look for either "$(arch)" or "$(/usr/bin/arch)" in the file
            return fileContents.contains("$(arch)") || fileContents.contains("$(/usr/bin/arch)")
        } catch {
            Logger.log("Error reading file at \(filePath): \(error)", logType: logType)
            return false
        }
    }
    
    
    
    static func runProcessLabelScript(for folderName: String) -> Bool {
        return InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
    }
    
    // MARK: - Collect the plist data so we can download the file

    static func extractDataForProcessedAppResults(from folderName: String) -> ProcessedAppResults? {
        MetadataLoader.extractDataForProcessedAppResults(from: folderName)
    }    
    
    
    
    enum AppArchitecture: String {
        case arm64
        case x86_64
        case universal
        case unknown
    }

    static func getAppArchitecture(at appURL: URL) throws -> AppArchitecture {
        // 1. Load Info.plist to get the executable name
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let plistData = try Data(contentsOf: infoPlistURL)
        guard
            let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
            let execName = plist["CFBundleExecutable"] as? String
        else {
            return .unknown
        }

        // 2. Point to the actual binary
        let binaryURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent(execName)

        // 3. Call `/usr/bin/file` on that binary
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        process.arguments = ["-bL", binaryURL.path] // -b for brief, -L to follow symlinks

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8)?.lowercased() else {
            return .unknown
        }

        // 4. Inspect the output
        let hasARM = output.contains("arm64")
        let hasX86 = output.contains("x86_64")

        switch (hasARM, hasX86) {
        case (true, true):
            return .universal
        case (true, false):
            return .arm64
        case (false, true):
            return .x86_64
        default:
            return .unknown
        }
    }
    
    
    
    enum ArchitectureValidationError: Error, CustomStringConvertible {
        case mismatch(at: URL, expected: AppArchitecture, found: AppArchitecture)
        
        var description: String {
            switch self {
            case let .mismatch(url, expected, found):
                return "Architecture mismatch for \(url.lastPathComponent): expected \(expected.rawValue), found \(found.rawValue)"
            }
        }
    }

    static func validateAppArchitectures(
        urls: [URL],
        expected: [AppArchitecture]
    ) throws {
        for (url, expArch) in zip(urls, expected) {
            let actualArch = try getAppArchitecture(at: url)
            guard actualArch == expArch else {
                throw ArchitectureValidationError.mismatch(at: url, expected: expArch, found: actualArch)
            }
        }
    }
    
    
    
    // MARK: - Inspection of download
    static func inspectSignatureOfDownloadedSoftware(for processedAppResults: ProcessedAppResults, downloadURL: URL, inspectionType: String) -> Bool {
        
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
                    Logger.log("  Expected Team ID: \(processedAppResults.appTeamID)", logType: logType)
                    if teamID != processedAppResults.appTeamID {
                        Logger.log("  Team ID mismatch! Expected: \(processedAppResults.appTeamID), Actual: \(teamID)", logType: logType)
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
                    Logger.log("  Expected Team ID: \(processedAppResults.appTeamID)", logType: logType)
                    if teamID != processedAppResults.appTeamID {
                        Logger.log("  Team ID mismatch! Expected: \(processedAppResults.appTeamID), Actual: \(teamID)", logType: logType)
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
    
    
    // MARK: - UPDATE METADATA ONLY FOR FOLDER
    static func processFolderMetadata(named folderName: String) async {
        // Variables to track label processing
        var processedAppResults: ProcessedAppResults?

        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo]

        Logger.log("--------------------------------------------------------", logType: logType)
        Logger.log("🚀 Start metadata update of \(folderName)", logType: logType)
        Logger.log("Start metadata update of: \(folderName)", logType: logType)

        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: logType)
            return
        }
                
        // Get the Processed App Results starter for this folder
        processedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults?.appDisplayName ?? "Unknown")", logType: logType)
        
        Logger.log("  Label: \(String(describing: processedAppResults?.appLabelName))", logType: logType)
        Logger.log("  Tracking ID: \(String(describing: processedAppResults?.appTrackingID))", logType: logType)
        Logger.log("  Version to check: \(String(describing: processedAppResults?.appVersionExpected))", logType: logType)
        
        guard let trackingID = processedAppResults?.appTrackingID else {
            Logger.log("Tracking ID is missing", logType: logType)
            return
        }
        
        Logger.log("Processed App Results: \(String(describing: processedAppResults))", logType: logType)

        // MARK: - Check Intune for any versions
        
        // Check Intune for an existing versions
        Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: logType)
        
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.log("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: logType)
            
            for app in appInfo {
                Logger.log("    ---", logType: logType)
                Logger.log("    App: \(app.displayName)", logType: logType)
                Logger.log("    Ver: \(app.primaryBundleVersion)", logType: logType)
                Logger.log("     ID: \(app.id)", logType: logType)
                
                
                // MARK: - Upload metadata to Intune
                do {
                    
                    let entraAuthenticator = EntraAuthenticator()
                    let authToken = try await entraAuthenticator.getEntraIDToken()
                    
                    // Call the update function
                    try await EntraGraphRequests.updateAppIntuneMetadata(authToken: authToken, app: processedAppResults!, appId: app.id)
                    
                    // Remove all categories
                    try await EntraGraphRequests.removeAllCategoriesFromIntuneApp(authToken: authToken, appID: app.id)
                    
                    // Assign the categories to the app
                    try await EntraGraphRequests.assignCategoriesToIntuneApp(
                        authToken: authToken,
                        appID: app.id,
                        categories: processedAppResults?.appCategories ?? []
                    )

                    
                } catch {
                    Logger.log("Error updating \(processedAppResults?.appDisplayName ?? "unknown") with AppID \(app.id) metadata in Intune: \(error.localizedDescription)", logType: logType)
                }
            }
            
        } catch {
            Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: logType)
            return
        }
    }

    // MARK: - UPDATE SCRIPTS ONLY FOR FOLDER
    static func processFolderScripts(named folderName: String) async {
        // Variables to track label processing
        var processedAppResults: ProcessedAppResults?

        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo]

        Logger.log("--------------------------------------------------------", logType: logType)
        Logger.log("🚀 Start scripts update of \(folderName)", logType: logType)
        Logger.log("Start scripts update of: \(folderName)", logType: logType)

        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: logType)
            return
        }
                
        // Get the Processed App Results starter for this folder
        processedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults?.appDisplayName ?? "Unknown")", logType: logType)
        
        Logger.log("  Label: \(String(describing: processedAppResults?.appLabelName))", logType: logType)
        
        guard let trackingID = processedAppResults?.appTrackingID else {
            Logger.log("Tracking ID is missing", logType: logType)
            return
        }
        Logger.log("  Tracking ID: \(trackingID)", logType: logType)


        // MARK: - Check Intune for any versions
        
        // Check Intune for an existing versions
        Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: logType)
        
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.log("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: logType)
            
            for app in appInfo {
                Logger.log("    ---", logType: logType)
                Logger.log("    App: \(app.displayName)", logType: logType)
                Logger.log("    Ver: \(app.primaryBundleVersion)", logType: logType)
                Logger.log("     ID: \(app.id)", logType: logType)
                
                // MARK: - Upload scripts to Intune
                do {
                    
                    let entraAuthenticator = EntraAuthenticator()
                    let authToken = try await entraAuthenticator.getEntraIDToken()
                    
                    // Call the update function
                    try await EntraGraphRequests.updateAppIntuneScripts(authToken: authToken, app: processedAppResults!, appId: app.id)
                    
                } catch {
                    Logger.log("Error updating \(processedAppResults?.appDisplayName ?? "unknown") with AppID \(app.id) scripts in Intune: \(error.localizedDescription)", logType: logType)
                }
            }
            
        } catch {
            Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: logType)
            return
        }
    }

    
    // MARK: - UPDATE ASSIGNMENTS ONLY FOR FOLDER
    static func processFolderAssignments(named folderName: String) async {
        // Variables to track label processing
        var processedAppResults: ProcessedAppResults?

        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo]

        Logger.log("--------------------------------------------------------", logType: logType)
        Logger.log("🚀 Start assignment update of \(folderName)", logType: logType)
        Logger.log("Start assignment update of: \(folderName)", logType: logType)

        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: logType)
            return
        }
                
        // Get the Processed App Results starter for this folder
        processedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults?.appDisplayName ?? "Unknown")", logType: logType)
        
        Logger.log("  Label: \(String(describing: processedAppResults?.appLabelName))", logType: logType)
        
        guard let trackingID = processedAppResults?.appTrackingID else {
            Logger.log("Tracking ID is missing", logType: logType)
            return
        }
        Logger.log("  Tracking ID: \(trackingID)", logType: logType)


        // MARK: - Check Intune for any versions
        
        // Check Intune for an existing versions
        Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: logType)
        
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.log("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: logType)
            
            for app in appInfo {
                Logger.log("    ---", logType: logType)
                Logger.log("    App: \(app.displayName)", logType: logType)
                Logger.log("    Ver: \(app.primaryBundleVersion)", logType: logType)
                Logger.log("     ID: \(app.id)", logType: logType)
                
                
                // MARK: - Update group assignments in Intune
                if app.isAssigned {
                    do {
                                            
                        // Remove all existing assignments
                        try await EntraGraphRequests.removeAllAppAssignments(authToken: authToken, appId: app.id)
                        
                        let intuneAppType: String
                        switch processedAppResults?.appDeploymentType {
                            case 0:
                            intuneAppType = "macOSDmgApp"
                        case 1:
                            intuneAppType = "macOSPkgApp"
                        case 2:
                            intuneAppType = "macOSLobApp"
                        default:
                            intuneAppType = "macOSLobApp"
                        }
                        
                        // Assign the groups to the app
                        try await EntraGraphRequests.assignGroupsToApp(authToken: authToken, appId: app.id, appAssignments: processedAppResults?.appAssignments ?? [], appType: intuneAppType, installAsManaged: false)

                        try await EntraGraphRequests.assignCategoriesToIntuneApp(
                            authToken: authToken,
                            appID: app.id,
                            categories: processedAppResults?.appCategories ?? []
                        )
                        
                    } catch {
                        Logger.log("Error updating \(processedAppResults?.appDisplayName ?? "unknown") with AppID \(app.id) assignment in Intune: \(error.localizedDescription)", logType: logType)
                    }
                }
            }
            
        } catch {
            Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: logType)
            return
        }
    }

    
    // MARK: - REMOVE ALL INTUNE AUTOMATIONS FOR FOLDER
    static func deleteAutomationsFromIntune(named folderName: String) async {
        // Variables to track label processing
        var processedAppResults: ProcessedAppResults?

        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo]

        Logger.log("--------------------------------------------------------", logType: logType)
        Logger.log("🚀 Start removal of Intune automations for: \(folderName)", logType: logType)
        Logger.log("Start removal of Intune automations for: \(folderName)", logType: logType)

        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: logType)
            return
        }
                
        // Get the Processed App Results starter for this folder
        processedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults?.appDisplayName ?? "Unknown")", logType: logType)
        
        Logger.log("  Label: \(String(describing: processedAppResults?.appLabelName))", logType: logType)
        Logger.log("  Tracking ID: \(String(describing: processedAppResults?.appTrackingID))", logType: logType)
        Logger.log("  Version to check: \(String(describing: processedAppResults?.appVersionExpected))", logType: logType)
        
        guard let trackingID = processedAppResults?.appTrackingID else {
            Logger.log("Tracking ID is missing", logType: logType)
            return
        }
        
        Logger.log("Processed App Results: \(String(describing: processedAppResults))", logType: logType)

        // MARK: - Check Intune for any versions
        
        // Check Intune for an existing versions
        Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: logType)
        
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.log("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: logType)
            
            for app in appInfo {
                Logger.log("    ---", logType: logType)
                Logger.log("    App: \(app.displayName)", logType: logType)
                Logger.log("    Ver: \(app.primaryBundleVersion)", logType: logType)
                Logger.log("     ID: \(app.id)", logType: logType)
                
                
                // MARK: - Remove all automations from Intune
                do {
                    
                    let entraAuthenticator = EntraAuthenticator()
                    let authToken = try await entraAuthenticator.getEntraIDToken()
                    
                    // Call the DELETE function
                    try await EntraGraphRequests.deleteIntuneApp(authToken: authToken, appId: app.id)
                    
                } catch {
                    Logger.log("Error removing \(processedAppResults?.appDisplayName ?? "unknown") item with AppID \(app.id) from Intune: \(error.localizedDescription)", logType: logType)
                }
            }
            
            
            let labelFolderName = "\(processedAppResults?.appLabelName ?? "Unknown")_\(processedAppResults?.appTrackingID ?? "Unknown")"
            
            let labelFolderURL = AppConstants.intuneomatorManagedTitlesFolderURL.appendingPathComponent(labelFolderName)
            
            if FileManager.default.fileExists(atPath: labelFolderURL.path) {
                let intuneUploadTouchFile = labelFolderURL.appendingPathComponent(".uploaded")
                
                if FileManager.default.fileExists(atPath: intuneUploadTouchFile.path) {
                    try FileManager.default.removeItem(at: intuneUploadTouchFile)
                }
            }
            
            
        } catch {
            Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: logType)
            return
        }
    }

}
