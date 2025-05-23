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
        Logger.log("🔄 Starting Intune automation run...", logType: logType)
        Logger.log("--------------------------------------------------------", logType: logType)
        
        var validFolders: [String] = []
        let basePath = AppConstants.intuneomatorManagedTitlesFolderURL.path
        
        do {
            var folderContents = try FileManager.default.contentsOfDirectory(atPath: basePath)
            
            // Sort folder names alphabetically
            folderContents.sort()
            
            for folderName in folderContents {
                let folderPath = (basePath as NSString).appendingPathComponent(folderName)
                
                if AutomationCheck.validateFolder(at: folderPath) {
                    Logger.log("✅ Ready for automation: \(folderName)", logType: logType)
                    validFolders.append(folderName)
                } else {
                    Logger.log("⚠️ Not ready for automation: \(folderName)", logType: logType)
                }
            }
        } catch {
            Logger.log("❌ Error reading managed titles folder: \(error.localizedDescription)", logType: logType)
        }
        Logger.log("--------------------------------------------------------", logType: logType)

        Logger.log("📋 Valid software titles for automation: \(validFolders.joined(separator: ", "))", logType: logType)
        Logger.log("🏁 Scan complete. \(validFolders.count) folders ready for automation.", logType: logType)

        return validFolders
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
    
    // Function to extract plist data
    static func extractDataForProcessedAppResults(from folderName: String) -> ProcessedAppResults? {
        
        // Extract the label name (before the UUID part)
        let parts = folderName.split(separator: "_")
        // Verify we have a valid folder name
        guard parts.count == 2 else {
            Logger.log("❌ Invalid folder format: \(folderName)", logType: logType)
            return nil
        }
        let labelName = String(parts[0])
        let labelGUID = String(parts[1])
        
        // Full Path to the folder
        let folderPath = (AppConstants.intuneomatorManagedTitlesFolderURL.path as NSString).appendingPathComponent(folderName)
        
        // Load Metadata file
        var metadata: Metadata?
        let filePath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(folderName)")
            .appendingPathComponent("metadata.json")
        
        do {
            let data = try Data(contentsOf: filePath)
            metadata = try JSONDecoder().decode(Metadata.self, from: data)
            
        } catch {
            Logger.log("Failed to load metadata: \(error)", logType: logType)
        }
        
        // Extract necessary metadata keys
        let expectedBundleID = metadata?.CFBundleIdentifier
        let categories = metadata?.categories
        let developer = metadata?.developer ?? ""
        let deployAsArchTag = metadata?.deployAsArchTag
        let deploymentTypeTag = metadata?.deploymentTypeTag
        let description = metadata?.description
        let featured = metadata?.isFeatured ?? false
        let ignoreVersion = metadata?.ignoreVersionDetection ?? false
        let informationURL = metadata?.informationUrl ?? ""
        let managed = metadata?.isManaged ?? false
        let notes = metadata?.notes ?? ""
        let owner = metadata?.owner ?? ""
        let minimumOS = metadata?.minimumOS
        let privacyInformationUrl = metadata?.privacyInformationUrl ?? ""
        let publisher = metadata?.publisher
        
        // Validate required metadata fields
        guard let validatedExpectedBundleID = expectedBundleID, let validatedDeployAsArchTag = deployAsArchTag, let validatedDeploymentTypeTag = deploymentTypeTag, let validatedDescription = description, let validatedMinimumOS = minimumOS, let validatedPublisher = publisher else {
            Logger.log("❌ Critical metadata keys are missing for \(folderName). Skipping.", logType: logType)
            return nil
        }
        
        
        // PLIST Reading
        let plistPathArm64 = (folderPath as NSString)
            .appendingPathComponent("\(labelName).plist")
        let plistPathx86_64 = (folderPath as NSString)
            .appendingPathComponent("\(labelName)_i386.plist")
        var downloadURLx86_64: String = ""
        var plistPath: String = ""
        
        // Check to see if the label has separate binaries per architecture
        let titleIsDualArch = titleIsDualArch(forFolder: folderName)
        if titleIsDualArch {
            // Apple Silicon Architecture
            if metadata?.deployAsArchTag == 0 {
                plistPath = plistPathArm64
                
            // Intel Architecture
            } else if metadata?.deployAsArchTag == 1 {
                plistPath = plistPathx86_64
             
            // Universal pkg to be built
            } else if metadata?.deployAsArchTag == 2 {
                plistPath = plistPathArm64
            }
            
        } else {
            plistPath = plistPathArm64
        }
        
        guard FileManager.default.fileExists(atPath: plistPath) else {
            Logger.log("❌ Missing plist file: \(plistPath)", logType: logType)
            return nil
        }
        
        Logger.log("  Reading plist: \(plistPath)", logType: logType)
        
        // Read plist data
        guard let plistData = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else {
            Logger.log("❌ Failed to parse plist: \(plistPath)", logType: logType)
            return nil
        }
        
        // We need both downloadURLs to build a Universal pkg
        if metadata?.deployAsArchTag == 2 && titleIsDualArch {
            guard let plistDatax86_64 = NSDictionary(contentsOfFile: plistPathx86_64) as? [String: Any] else {
                Logger.log("❌ Failed to parse plist: \(plistPathx86_64)", logType: logType)
                return nil
            }
            let downloadURL = plistDatax86_64["downloadURL"] as? String
            downloadURLx86_64 = downloadURL ?? ""
        }
        
        // Extract necessary plist keys
        let appNewVersion = plistData["appNewVersion"] as? String
        let downloadURL = plistData["downloadURL"] as? String
        let expectedTeamID = plistData["expectedTeamID"] as? String
        let name = plistData["name"] as? String
        let type = plistData["type"] as? String
        let labelIcon = plistData["labelIcon"] as? String
        
        // Validate required plist fields
        guard let validatedDownloadURL = downloadURL, let validatedExpectedTeamID = expectedTeamID, let validatedName = name, let validatedType = type, let validatedLabelIcon = labelIcon else {
            Logger.log("❌ Critical plist keys are missing for \(folderName). Skipping.", logType: logType)
            return nil
        }
        
        Logger.log("  Extracted plist and metadata for \(folderName): name=\(validatedName), version=\(appNewVersion ?? "N/A"), downloadURL=\(validatedDownloadURL), type=\(validatedType)", logType: logType)
        
        
        // Load scripts if present
        let basePath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(folderName)")
        
        let preInstallPath = basePath.appendingPathComponent("preinstall.sh")
        let postInstallPath = basePath.appendingPathComponent("postinstall.sh")
        
        var preInstallScript: String?
        var postInstallScript: String?
        
        // Load Preinstall Script
        if FileManager.default.fileExists(atPath: preInstallPath.path) {
            do {
                preInstallScript = try String(contentsOf: preInstallPath, encoding: .utf8)
            } catch {
                Logger.log("Error loading preinstall script: \(error)", logType: logType)
            }
        } else {
            preInstallScript = "" // Clear if file doesn't exist
        }
        
        // Load Postinstall Script
        if FileManager.default.fileExists(atPath: postInstallPath.path) {
            do {
                postInstallScript = try String(contentsOf: postInstallPath, encoding: .utf8)
            } catch {
                Logger.log("Error loading postinstall script: \(error)", logType: logType)
            }
        } else {
            postInstallScript = "" // Clear if file doesn't exist
        }
        
        
        // Load the app assignments
        let assignmentsFilePath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(folderName)")
            .appendingPathComponent("assignments.json")

        var groupAssignments: [[String: Any]] = []

        func sortGroupAssignments() {
            let assignmentOrder = ["Required", "Available", "Uninstall"]
            groupAssignments.sort {
                let type1 = $0["assignmentType"] as? String ?? ""
                let type2 = $1["assignmentType"] as? String ?? ""
                let index1 = assignmentOrder.firstIndex(of: type1) ?? 999
                let index2 = assignmentOrder.firstIndex(of: type2) ?? 999
                if index1 != index2 {
                    return index1 < index2
                } else {
                    let name1 = $0["displayName"] as? String ?? ""
                    let name2 = $1["displayName"] as? String ?? ""
                    return name1.localizedCompare(name2) == .orderedAscending
                }
            }
        }

        do {
            let data = try Data(contentsOf: assignmentsFilePath)
            // Parse the JSON as an array of dictionaries
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                groupAssignments = json
                sortGroupAssignments()
            } else {
                Logger.log("JSON format is invalid", logType: logType)
            }
        } catch {
            Logger.log("Failed to load assignments: \(error)", logType: logType)
        }
        
        // Return the combo of plist and metadata files
        let processedResults =  ProcessedAppResults(
            appAssignments: groupAssignments,
            appBundleIdActual: "",
            appBundleIdExpected: validatedExpectedBundleID,
            appCategories: categories ?? [],
            appDeploymentArch: validatedDeployAsArchTag,
            appDeploymentType: validatedDeploymentTypeTag,
            appDescription: validatedDescription,
            appDeveloper: developer,
            appDisplayName: validatedName,
            appDownloadURL: validatedDownloadURL,
            appDownloadURLx86: downloadURLx86_64,
            appIconURL: validatedLabelIcon,
            appIgnoreVersion: ignoreVersion,
            appInfoURL: informationURL,
            appIsDualArchCapable: titleIsDualArch,
            appIsFeatured: featured,
            appIsManaged: managed,
            appLabelName: labelName,
            appLabelType: validatedType,
            appLocalURL: "",
            appLocalURLx86: "",
            appMinimumOS: validatedMinimumOS,
            appNotes: notes,
            appOwner: owner,
            appPlatform: "",
            appPrivacyPolicyURL: privacyInformationUrl,
            appPublisherName: validatedPublisher,
            appScriptPreInstall: preInstallScript ?? "",
            appScriptPostInstall: postInstallScript ?? "",
            appTeamID: validatedExpectedTeamID,
            appTrackingID: labelGUID,
            appVersionActual: "",
            appVersionExpected: appNewVersion ?? ""
        )
        return processedResults
    }
    
    static func titleIsDualArch(forFolder folder: String) -> Bool {
        //        let isDualPlatform: Bool = false
        
        let fileManager = FileManager.default
        
        let label = folder.components(separatedBy: "_").first ?? "Unknown"
        
        let labelX86PlistPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent("\(label)_i386.plist", isDirectory: false)
        
        let labelPlistPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent("\(label).plist", isDirectory: false)
        
        return fileManager.fileExists(atPath: labelX86PlistPath.path) &&
        fileManager.fileExists(atPath: labelPlistPath.path)
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
