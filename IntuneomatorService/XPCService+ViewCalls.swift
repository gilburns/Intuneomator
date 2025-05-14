//
//  XPCService+ViewCalls.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

extension XPCService {
    
    // MARK: - Main View Controller
    func scanAllManagedLabels(reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let directoryContents = try FileManager.default.contentsOfDirectory(
                    at: URL(fileURLWithPath: AppConstants.intuneomatorManagedTitlesFolderURL.path),
                    includingPropertiesForKeys: nil
                )
                let subdirectories = directoryContents.filter { $0.hasDirectoryPath }

                let success = await withTaskGroup(of: Bool.self) { taskGroup in
                    for subdir in subdirectories {
                        #if DEBUG
                        Logger.log("Directory to process: \(subdir.lastPathComponent)", logType: "XPCService")
                        #endif
                        let folderName = subdir.lastPathComponent

                        taskGroup.addTask {
                            return InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
                        }
                    }

                    // Reduce results: only true if all were successful
                    return await taskGroup.reduce(true) { $0 && $1 }
                }

                reply(success)
            } catch {
                Logger.log("Error loading app data: \(error)", logType: "XPCService")
                reply(false)
            }
        }
    }
    
    
    // MARK: - New Mangeged Software Label

    func addNewLabelContent(_ labelName: String, _ source: String, reply: @escaping (String?) -> Void) {
        Task {
            let newGUID = UUID().uuidString
            var copyShFilePath: String
            
            var descriptionFromPlist: String? = ""
            var documentationURLFromPlist: String? = ""
            var publisherURLFromPlist: String? = ""
            var privacyURLFromPlist: String? = ""
            
            let newDirectoryURL = AppConstants.intuneomatorManagedTitlesFolderURL.appendingPathComponent("\(labelName)_\(newGUID)")
            
            let newDirectoryName = newDirectoryURL.lastPathComponent
            
            // Fetch description and documentation before proceeding
            do {
                let info = try await fetchLabelInfo(labelName: labelName)
                descriptionFromPlist = info.description
                documentationURLFromPlist = info.documentation
                publisherURLFromPlist = info.publisher
                privacyURLFromPlist = info.privacy
            } catch {
                Logger.log("Error fetching plist: \(error)", logType: "XPCService")
                descriptionFromPlist = ""
                documentationURLFromPlist = ""
                publisherURLFromPlist = ""
                privacyURLFromPlist = ""
            }
            
            switch source {
            case "installomator":
                copyShFilePath = AppConstants.installomatorLabelsFolderURL
                    .appendingPathComponent("\(labelName).sh")
                    .path
            case "custom":
                copyShFilePath = AppConstants.installomatorCustomLabelsFolderURL
                    .appendingPathComponent("\(labelName).sh")
                    .path
            default:
                reply(nil)
                return
            }
            
            Logger.log("Creating new directory: \(newDirectoryURL)", logType: "XPCService")
            Logger.log("Copying \(labelName).sh to \(newDirectoryURL)", logType: "XPCService")
            Logger.log("Source: \(source)", logType: "XPCService")
            Logger.log("Copy Sh file path: \(copyShFilePath)", logType: "XPCService")
            
            do {
                // Create the new directory
                try FileManager.default.createDirectory(atPath: newDirectoryURL.path, withIntermediateDirectories: true, attributes: nil)
                
                // Create the .sh file
                let newShFileURL = newDirectoryURL
                    .appendingPathComponent("\(labelName).sh")
                                
                Logger.log("New Sh file path: \(newShFileURL.path)", logType: "XPCService")
                
                Logger.log("Creating new .sh file: \(newShFileURL)", logType: "XPCService")
                
                guard let copyShFileContents = try? String(contentsOfFile: copyShFilePath) else {
                    Logger.log("Failed to read contents of \(copyShFilePath)", logType: "XPCService")
                    reply(nil)
                    return
                }
                
                try copyShFileContents.write(toFile: newShFileURL.path, atomically: true, encoding: .utf8)
                
                if source == "custom" {
                    let touchFileURL = newDirectoryURL
                        .appendingPathComponent(".custom")

                    Logger.log("Touch file path: \(touchFileURL.path)", logType: "XPCService")
                    FileManager.default.createFile(atPath: touchFileURL.path, contents: nil, attributes: nil)
                }
                
                // Run the label processor
                let installomatorLabelProcessor = InstallomatorLabelProcessor.runProcessLabelScript(for: newDirectoryName)
                if installomatorLabelProcessor {
                    Logger.log("Label processor ran successfully", logType: "XPCService")
                } else {
                    Logger.log("Label processor failed", logType: "XPCService")
                }
                
                // Attempt to download icon from server
                let iconDestinationURL = newDirectoryURL
                    .appendingPathComponent("\(labelName).png")
                Logger.log("Attempting to download icon from: https://icons.intuneomator.org/\(labelName).png", logType: "XPCService")
                
                if let iconURL = URL(string: "https://icons.intuneomator.org")?.appendingPathComponent("\(labelName).png"),
                   let iconData = try? Data(contentsOf: iconURL) {
                    do {
                        try iconData.write(to: iconDestinationURL)
                        Logger.log("Successfully downloaded and saved icon to: \(iconDestinationURL)", logType: "XPCService")
                    } catch {
                        Logger.log("Failed to save downloaded icon: \(error)", logType: "XPCService")
                        let fallbackSuccess = IconExporter.saveGenericAppIcon(to: iconDestinationURL.path)
                        Logger.log("Fallback export icon status: \(fallbackSuccess ? "Success" : "Failure")", logType: "XPCService")
                    }
                } else {
                    Logger.log("Download failed or icon unavailable, falling back to generic icon", logType: "XPCService")
                    let fallbackSuccess = IconExporter.saveGenericAppIcon(to: iconDestinationURL.path)
                    Logger.log("Fallback export icon status: \(fallbackSuccess ? "Success" : "Failure")", logType: "XPCService")
                }
                
                // Read the new Plist and then create the metadata.json
                let plistURL = newDirectoryURL
                    .appendingPathComponent("\(labelName).plist")
                
                
                var plistDictionary: [String: Any] = [:]
                
                // Read the plist
                do {
                    Logger.log("Reading plist file: \(plistURL)", logType: "XPCService")
                    let plistData = try Data(contentsOf: plistURL)
                    plistDictionary = try PropertyListSerialization.propertyList(
                        from: plistData,
                        options: [],
                        format: nil
                    ) as! [String: Any]
                    
                } catch {
                    Logger.log("Failed to load plist: \(error)", logType: "XPCService")
                    reply(nil)
                    return
                }
                
                
                let sourceType = plistDictionary["type"] as? String ?? ""
                
                var managedState: Bool = false
                
                if ["pkg", "pkgInDmg", "pkgInZip", "pkgInDmgInZip"].contains(sourceType) {
                    managedState = true
                }
                
                var deploymentTypeTag: Int = 0
                if ["pkg", "pkgInDmg", "pkgInZip", "pkgInDmgInZip"].contains(sourceType) {
                    deploymentTypeTag = 2
                } else if ["dmg", "zip", "tbz", "appInDmgInZip"].contains(sourceType) {
                    deploymentTypeTag = 0
                }
                
                let metadataJSONURL = newDirectoryURL
                    .appendingPathComponent("metadata.json")
                
                // Create a default metadata object to use as baseline
                let defaultMetadata = Metadata(
                    categories: [],
                    description: descriptionFromPlist ?? "",
                    deployAsArchTag: 0,
                    deploymentTypeTag: deploymentTypeTag,
                    developer: publisherURLFromPlist,
                    informationUrl: documentationURLFromPlist,
                    ignoreVersionDetection: false,
                    isFeatured: false,
                    isManaged: managedState,
                    minimumOS: "v13_0",
                    minimumOSDisplay: "macOS Ventura 13.0",
                    notes: "",
                    owner: "",
                    privacyInformationUrl: privacyURLFromPlist,
                    publisher: publisherURLFromPlist ?? "",
                    CFBundleIdentifier: ""
                )
                
                // write metadata
                do {
                    // Write the raw JSON string as UTF-8
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    
                    let jsonData = try encoder.encode(defaultMetadata)
                    
                    try jsonData.write(to: metadataJSONURL)
                    
                    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: metadataJSONURL.path)
                    
                } catch {
                    Logger.log("Failed to save metadata: \(error)", logType: "XPCService")
                    reply(nil)
                    return
                }
                
                reply(newDirectoryURL.path)
            } catch {
                Logger.log("Failed to create new content: \(error)", logType: "XPCService")
                reply(nil)
            }
        }
    }
    
    func removeLabelContent(_ labelDirectory: String, reply: @escaping (Bool) -> Void) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: labelDirectory)
            reply(true)
        } catch {
            Logger.log("Failed to remove label content: \(error)", logType: "XPCService")
            reply(false)
        }
    }

    
    // MARK: - Metadata about a label from plist
    // 2. A fetch function that hits the server, decodes the plist, and returns your two strings
    func fetchLabelInfo(labelName: String) async throws -> LabelPlistInfo {
        // build URL
        guard let url = URL(string: "https://intuneomator.org/labels")?
                .appendingPathComponent("\(labelName).plist") else {
            throw URLError(.badURL)
        }
        
        Logger.log("Plist URL: \(url)", logType: "XPCService")

        // fetch data
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // decode plist into LabelInfo
        let decoder = PropertyListDecoder()
        let info = try decoder.decode(LabelPlistInfo.self, from: data)
        return info
    }

    // MARK: - Installomator Label Updates
    func updateLabelsFromGitHub(reply: @escaping (Bool) -> Void) {
        InstallomatorLabels.installInstallomatorLabels { success, message in
            if success {
                Logger.log("Installomator labels downloaded successfully.", logType: "XPCService")
            } else {
                Logger.log("Failed to download Installomator labels: \(message)", logType: "XPCService")
            }
            reply(success)
        }
    }
        
    // MARK: - TabView Actions
    func saveLabelContent(_ labelFolder: String, _ content: NSDictionary, reply: @escaping (Bool) -> Void) {

    }
    
    func toggleCustomLabel(_ labelFolder: String, _ toggle: Bool, reply: @escaping (Bool) -> Void) {
        
        let labelName = labelFolder.components(separatedBy: "_")[0]

        let labelFolderURL = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(labelFolder)
        
        let existingLabelURL = labelFolderURL
            .appendingPathComponent("\(labelName).sh")
        
        let touchFileURL = labelFolderURL
            .appendingPathComponent(".custom")

        if toggle {
            do {
                FileManager.default.createFile(atPath: touchFileURL.path, contents: nil, attributes: nil)

                let sourceLabelURL = AppConstants.installomatorCustomLabelsFolderURL
                    .appendingPathComponent("\(labelName).sh")

                if FileManager.default.fileExists(atPath: existingLabelURL.path) {
                    try? FileManager.default.removeItem(atPath: existingLabelURL.path)
                }

                try FileManager.default.copyItem(at: sourceLabelURL, to: existingLabelURL)
                
                LabelAutomation.runProcessLabelScript(for: labelFolder)

                reply(true)
            } catch {
                Logger.log("Faied to copy custom label: \(error.localizedDescription)", logType: "XPCService")
                reply(false)
            }
        } else {
            do {
                try FileManager.default.removeItem(atPath: touchFileURL.path)
                
                let sourceLabelURL = AppConstants.installomatorLabelsFolderURL
                    .appendingPathComponent("\(labelName).sh")

                if FileManager.default.fileExists(atPath: existingLabelURL.path) {
                    try? FileManager.default.removeItem(atPath: existingLabelURL.path)
                }

                try FileManager.default.copyItem(at: sourceLabelURL, to: existingLabelURL)

                LabelAutomation.runProcessLabelScript(for: labelFolder)
                
                reply(true)
            } catch {
                Logger.log("Faied to delete custom label touch file: \(error.localizedDescription)", logType: "XPCService")
                reply(false)
            }
        }
    }

    
    // MARK: - Label Edit Actions
    func importIconToLabel(_ iconPath: String, _ labelFolder: String, reply: @escaping (Bool) -> Void) {
        
        let labelFolderPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(labelFolder)
            .path

        let parts = labelFolder.split(separator: "_")
        var labelName = ""
        
        if parts.count == 2 {
            labelName = String(parts[0]) // Assign the name
        } else {
            Logger.log("Invalid directory format.", logType: "XPCService")
            return
        }

        // Create the icon file
        let iconDestinationPath = (labelFolderPath as NSString)
            .appendingPathComponent("\(labelName).png")
        
//        Logger.log("Creating new icon file: \(iconDestinationPath)", logType: "XPCService")

        // Check if the icon is an app bundle
        if URL(string: iconPath)!.pathExtension == "app" {
            Logger.log("Selected app bundle", logType: "XPCService")
            let iconSuccess = IconExporter.extractAppIcon(appPath: iconPath, outputPath: iconDestinationPath)
            Logger.log("Export status: \(iconSuccess ? "Success" : "Failure")", logType: "XPCService")
            reply(iconSuccess)
        } else {
//            Logger.log("Selected image file", logType: "XPCService")
            if let cgImage = IconExporter.getCGImageFromPath(fileImagePath: iconPath) {
                IconExporter.saveCGImageAsPNG(cgImage, to: iconDestinationPath)
                reply(true)
            }
        }
    }

    
    
    func importGenericIconToLabel(_ labelFolder: String, reply: @escaping (Bool) -> Void) {
        
        let labelFolderPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(labelFolder)
            .path
        
        let parts = labelFolder.split(separator: "_")
        var labelName = ""
        
        if parts.count == 2 {
            labelName = String(parts[0]) // Assign the name
        } else {
            Logger.log("Invalid directory format.", logType: "XPCService")
            return
        }
        
        // Create the icon file
        let iconDestinationPath = (labelFolderPath as NSString)
            .appendingPathComponent("\(labelName).png")
        
//        Logger.log("Creating new icon file: \(iconDestinationPath)", logType: "XPCService")
        
        let iconSuccess = IconExporter.saveGenericAppIcon(to: iconDestinationPath)
        Logger.log("Export status: \(iconSuccess ? "Success" : "Failure")", logType: "XPCService")
        reply(iconSuccess)
    }
    
    
    
    
    // MARK: - Edit View Controller
    
    func saveMetadataForLabel(_ metadata: String, _ labelFolder: String, reply: @escaping (Bool) -> Void) {
        let basePath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(labelFolder)
        let filePath = basePath.appendingPathComponent("metadata.json")

        do {
            try FileManager.default.createDirectory(
                at: filePath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // Write the raw JSON string as UTF-8
            try metadata.write(to: filePath, atomically: true, encoding: .utf8)

            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: filePath.path)

            reply(true)
        } catch {
            Logger.log("Failed to save metadata: \(error)", logType: "XPCService")
            reply(false)
        }
    }
    
    
    


    // MARK: - Script View Controller
    func savePreInstallScriptForLabel(_ script: String, _ labelFolder: String, reply: @escaping (Bool) -> Void) {

        // Define the folder and file path to save the assignments
        let basePath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(labelFolder)")
        
        let preInstallPath = basePath.appendingPathComponent("preinstall.sh")

        // Save or delete Preinstall Script
        let preInstallContents = script.trimmingCharacters(in: .whitespacesAndNewlines)
        if preInstallContents.isEmpty {
            // Delete the file if the script is blank
            do {
                if FileManager.default.fileExists(atPath: preInstallPath.path) {
                    try FileManager.default.removeItem(at: preInstallPath)
                    Logger.log("Deleted preinstall script: \(preInstallPath)", logType: "XPCService")
                    reply(true)
                } else {
//                    Logger.log("No preinstall script to delete at: \(preInstallPath)", logType: "XPCService")
                    reply(true)
                }
            } catch {
                Logger.log("Error deleting preinstall script: \(error)", logType: "XPCService")
                reply(false)
            }
        } else {
            // Save the file if the script is not blank
            do {
                try preInstallContents.write(to: preInstallPath, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: preInstallPath.path)
                Logger.log("Saved preinstall script: \(preInstallPath)", logType: "XPCService")
                reply(true)
            } catch {
                Logger.log("Error saving preinstall script: \(error)", logType: "XPCService")
                reply(false)
            }
        }
    }
        

    func savePostInstallScriptForLabel(_ script: String, _ labelFolder: String, reply: @escaping (Bool) -> Void) {

        // Define the folder and file path to save the assignments
        let basePath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(labelFolder)")
        
        let postInstallPath = basePath.appendingPathComponent("postinstall.sh")

        // Save or delete Postinstall Script
        let postInstallContents = script.trimmingCharacters(in: .whitespacesAndNewlines)
        if postInstallContents.isEmpty {
            // Delete the file if the script is blank
            do {
                if FileManager.default.fileExists(atPath: postInstallPath.path) {
                    try FileManager.default.removeItem(at: postInstallPath)
                    Logger.log("Deleted postinstall script: \(postInstallPath)", logType: "XPCService")
                    reply(true)
                } else {
//                    Logger.log("No postinstall script to delete at: \(postInstallPath)", logType: "XPCService")
                    reply(true) // No file is considered "successfully deleted"
                }
            } catch {
                Logger.log("Error deleting postinstall script: \(error)", logType: "XPCService")
                reply(false)
            }
        } else {
            // Save the file if the script is not blank
            do {
                try postInstallContents.write(to: postInstallPath, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: postInstallPath.path)
                Logger.log("Saved postinstall script: \(postInstallPath)", logType: "XPCService")
                reply(true)

            } catch {
                Logger.log("Error saving postinstall script: \(error)", logType: "XPCService")
                reply(false)
            }
        }
    }

    
    // MARK: - Group Assigment View Controller
    
    func saveGroupAssignmentsForLabel(_ groupAssignments: [[String : Any]], _ labelFolder: String, reply: @escaping (Bool) -> Void) {
        
        // Define the folder and file path to save the assignments
        let basePath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(labelFolder)")
        
        let filePath = basePath.appendingPathComponent("assignments.json")
        
        // Ensure the directory exists
        do {
            try FileManager.default.createDirectory(at: basePath, withIntermediateDirectories: true, attributes: nil)
            
            // Convert assignments to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: groupAssignments, options: [.sortedKeys, .prettyPrinted])
            
            // Write JSON data to the file
            try jsonData.write(to: filePath, options: .atomic)
            
            reply(true)
        } catch {
            Logger.log("Failed to create directory at \(basePath): \(error)", logType: "XPCService")
            reply(false)
        }
    }
    
    // MARK: - Discovered Applications

    func fetchDiscoveredMacApps(reply: @escaping (Data?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                let apps: [DetectedApp] = try await EntraGraphRequests.fetchMacOSDetectedApps(authToken: authToken)
                do {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(apps)
                    reply(data)
                } catch {
                    Logger.log("Error encoding DetectedApp array: \(error)", logType: "XPCService")
                    reply(nil)
                }
            } catch {
                Logger.log("❌ Error fetching detected apps: \(error)", logType: "XPCService")
                reply(nil)
            }
        }
    }
        

    func fetchDevices(forAppID appID: String, reply: @escaping (Data?) -> Void) {
        Task {
            do {
                let authToken = try await EntraAuthenticator().getEntraIDToken()
                let rawDevices = try await EntraGraphRequests.fetchDevices(authToken: authToken, forAppID: appID)
                
                // Map the tuple array into an array of our Codable struct
                let infos = rawDevices.map {
                    DeviceInfo(deviceName: $0.deviceName, id: $0.id, emailAddress: $0.emailAddress)
                }
                
                let data = try JSONEncoder().encode(infos)
                reply(data)
            }
            catch {
                Logger.log("❌ fetchDevices error: \(error)", logType: "XPCService")
                reply(nil)
            }
        }
    }
    

    
}

