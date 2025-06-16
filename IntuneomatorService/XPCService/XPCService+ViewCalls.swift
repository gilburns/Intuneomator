//
//  XPCService+ViewCalls.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// XPCService extension for main application operations and view controller support
/// Handles GUI application requests for label management, metadata operations, and content processing
/// All operations are executed asynchronously with appropriate error handling and logging
extension XPCService {
    
    // MARK: - Main Application Operations
    
    /// Scans and processes all managed Installomator label folders concurrently
    /// Validates folder structure and executes label processing scripts for each managed title
    /// - Parameter reply: Callback with overall success status of all label processing operations
    func scanAllManagedLabels(reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let managedLabelsURL = AppConstants.intuneomatorManagedTitlesFolderURL
                var isDir: ObjCBool = false
                if !FileManager.default.fileExists(atPath: managedLabelsURL.path, isDirectory: &isDir) {
                    try FileManager.default.createDirectory(at: managedLabelsURL, withIntermediateDirectories: true, attributes: nil)
                    reply(true)
                    return
                }
                let directoryContents = try FileManager.default.contentsOfDirectory(
                    at: URL(fileURLWithPath: AppConstants.intuneomatorManagedTitlesFolderURL.path),
                    includingPropertiesForKeys: nil
                )
                let subdirectories = directoryContents.filter { $0.hasDirectoryPath }

                let success = await withTaskGroup(of: Bool.self) { taskGroup in
                    for subdir in subdirectories {
                        #if DEBUG
                        Logger.info("Directory to process: \(subdir.lastPathComponent)", category: .core)
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
                Logger.error("Error loading app data: \(error)", category: .core)
                reply(false)
            }
        }
    }
    
    /// Updates metadata for a specific managed application label
    /// Processes folder metadata and synchronizes with Microsoft Graph API
    /// - Parameters:
    ///   - labelFolderName: Name of the label folder to process
    ///   - displayName: Human-readable display name for logging
    ///   - reply: Callback with success message or nil on failure
    func updateAppMetadata(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                await LabelAutomation.processFolderMetadata(named: labelFolderName)
                reply("Updated \(displayName) metadata")
            }
        }
    }

    /// Updates pre/post-install scripts for a specific managed application label
    /// Processes and uploads custom script content to Microsoft Intune
    /// - Parameters:
    ///   - labelFolderName: Name of the label folder to process
    ///   - displayName: Human-readable display name for logging
    ///   - reply: Callback with success message or nil on failure
    func updateAppScripts(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                await LabelAutomation.processFolderScripts(named: labelFolderName)
                reply("Updated \(displayName) scripts")
            }
        }
    }

    /// Updates group assignments for a specific managed application label
    /// Processes assignment configurations and applies them to Microsoft Intune
    /// - Parameters:
    ///   - labelFolderName: Name of the label folder to process
    ///   - displayName: Human-readable display name for logging
    ///   - reply: Callback with success message or nil on failure
    func updateAppAssignments(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                await LabelAutomation.processFolderAssignments(named: labelFolderName)
                reply("Updated \(displayName) assignments")
            }
        }
    }

    /// Removes all automation components from Microsoft Intune for a specific label
    /// Deletes applications, scripts, and assignments associated with the managed title
    /// - Parameters:
    ///   - labelFolderName: Name of the label folder to remove from Intune
    ///   - displayName: Human-readable display name for logging
    ///   - reply: Callback with success message or nil on failure
    func deleteAutomationsFromIntune(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                await LabelAutomation.deleteAutomationsFromIntune(named: labelFolderName)
                reply("Deleted all \(displayName) automations.")
            }
        }
    }

    
    /// Triggers on-demand automation processing for a specific label
    /// Creates trigger file for the Launch Daemon to process the specified label immediately
    /// - Parameters:
    ///   - labelFolderName: Name of the label folder to process
    ///   - displayName: Human-readable display name for user feedback
    ///   - reply: Callback with status message indicating queue status or result
    func onDemandLabelAutomation(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void) {
        let touchFileURL = AppConstants.intuneomatorOndemandTriggerURL
            .appendingPathComponent("\(labelFolderName).trigger")

        if FileManager.default.fileExists(atPath: touchFileURL.path) {
            reply("⚠️ Automation for \(displayName) is already queued or running.")
            return
        }

        let success = FileManager.default.createFile(atPath: touchFileURL.path, contents: nil)

        if success {
            reply("✅ Started \(displayName) automation run.")
        } else {
            reply("❌ Failed to start automation for \(displayName).")
        }
    }
    
    
    /// Verifies existence of managed applications in Microsoft Intune
    /// Scans all managed label folders and checks if corresponding applications exist in Intune
    /// Updates .uploaded status files based on current Intune state
    /// - Parameter reply: Callback with overall success status of verification process
    func checkIntuneForAutomation(reply: @escaping (Bool) -> Void) {
        Task {
            let validFolders = scanAndValidateFolders()

            let success = await withTaskGroup(of: Bool.self) { group in
                for folderName in validFolders {
                    group.addTask { [self] in
                        let labelName = folderName.components(separatedBy: "_")[0]
                        let trackingID = folderName.components(separatedBy: "_")[1]

                        #if DEBUG
                        Logger.info("Checking for Intune automation in folder \(labelName) (GUID: \(trackingID))", category: .core)
                        #endif

                        do {
                            let entraAuthenticator = EntraAuthenticator.shared
                            let authToken = try await entraAuthenticator.getEntraIDToken()

                            let apps = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)

                            let uploadedFileURL = AppConstants.intuneomatorManagedTitlesFolderURL
                                .appendingPathComponent(folderName)
                                .appendingPathComponent(".uploaded")

                            if apps.count > 0 {
                                // Write app count to the file
                                let appCountString = "\(apps.count)"
                                try appCountString.write(to: uploadedFileURL, atomically: true, encoding: .utf8)
                            } else {
                                if FileManager.default.fileExists(atPath: uploadedFileURL.path) {
                                    try FileManager.default.removeItem(atPath: uploadedFileURL.path)
                                    Logger.info("Removed stale .uploaded file for \(labelName)", category: .core)
                                }
                            }

                            return true
                        } catch {
                            Logger.error("❌ Error checking automation for \(labelName): \(error)", category: .core)
                            return false
                        }
                    }
                }

                return await group.reduce(true) { $0 && $1 }
            }

            reply(success)
        }
    }
    
    // MARK: - Label Content Management

    /// Creates a new managed label folder with initial content and metadata
    /// Downloads icon, generates metadata, and prepares label for automation processing
    /// - Parameters:
    ///   - labelName: Name of the Installomator label to create
    ///   - source: Source type ("installomator" or "custom")
    ///   - reply: Callback with new directory path or nil on failure
    func addNewLabelContent(_ labelName: String, _ source: String, reply: @escaping (String?) -> Void) {
        Task {
            let newGUID = UUID().uuidString
            var copyShFilePath: String
            
            var appIDFromPlist: String? = ""
            var descriptionFromPlist: String? = ""
            var documentationURLFromPlist: String? = ""
            var publisherURLFromPlist: String? = ""
            var privacyURLFromPlist: String? = ""
            
            let newDirectoryURL = AppConstants.intuneomatorManagedTitlesFolderURL.appendingPathComponent("\(labelName)_\(newGUID)")
            
            let newDirectoryName = newDirectoryURL.lastPathComponent
            
            // Fetch description and documentation before proceeding
            do {
                let info = try await fetchLabelInfo(labelName: labelName)
                appIDFromPlist = info.appID
                descriptionFromPlist = info.description
                documentationURLFromPlist = info.documentation
                publisherURLFromPlist = info.publisher
                privacyURLFromPlist = info.privacy
            } catch {
                Logger.error("Error fetching plist: \(error)", category: .core)
                appIDFromPlist = ""
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
            
            Logger.info("Creating new directory: \(newDirectoryURL)", category: .core)
            Logger.info("Copying \(labelName).sh to \(newDirectoryURL)", category: .core)
            Logger.info("Source: \(source)", category: .core)
            Logger.info("Copy Sh file path: \(copyShFilePath)", category: .core)
            
            do {
                // Create the new directory
                try FileManager.default.createDirectory(atPath: newDirectoryURL.path, withIntermediateDirectories: true, attributes: nil)
                
                // Create the .sh file
                let newShFileURL = newDirectoryURL
                    .appendingPathComponent("\(labelName).sh")
                                
                Logger.info("New Sh file path: \(newShFileURL.path)", category: .core)
                
                Logger.info("Creating new .sh file: \(newShFileURL)", category: .core)
                
                guard let copyShFileContents = try? String(contentsOfFile: copyShFilePath) else {
                    Logger.error("Failed to read contents of \(copyShFilePath)", category: .core)
                    reply(nil)
                    return
                }
                
                try copyShFileContents.write(toFile: newShFileURL.path, atomically: true, encoding: .utf8)
                
                if source == "custom" {
                    let touchFileURL = newDirectoryURL
                        .appendingPathComponent(".custom")

                    Logger.info("Touch file path: \(touchFileURL.path)", category: .core)
                    FileManager.default.createFile(atPath: touchFileURL.path, contents: nil, attributes: nil)
                }
                
                // Run the label processor
                let installomatorLabelProcessor = InstallomatorLabelProcessor.runProcessLabelScript(for: newDirectoryName)
                if installomatorLabelProcessor {
                    Logger.info("Label processor ran successfully", category: .core)
                } else {
                    Logger.error("Label processor failed", category: .core)
                }
                
                // Attempt to download icon from server
                let iconDestinationURL = newDirectoryURL
                    .appendingPathComponent("\(labelName).png")
                Logger.info("Attempting to download icon from: https://icons.intuneomator.org/\(labelName).png", category: .core)
                
                if let iconURL = URL(string: "https://icons.intuneomator.org")?.appendingPathComponent("\(labelName).png"),
                   let iconData = try? Data(contentsOf: iconURL) {
                    do {
                        try iconData.write(to: iconDestinationURL)
                        Logger.info("Successfully downloaded and saved icon to: \(iconDestinationURL)", category: .core)
                    } catch {
                        Logger.error("Failed to save downloaded icon: \(error)", category: .core)
                        let fallbackSuccess = IconExporter.saveGenericAppIcon(to: iconDestinationURL.path)
                        Logger.info("Fallback export icon status: \(fallbackSuccess ? "Success" : "Failure")", category: .core)
                    }
                } else {
                    Logger.info("Download failed or icon unavailable, falling back to generic icon", category: .core)
                    let fallbackSuccess = IconExporter.saveGenericAppIcon(to: iconDestinationURL.path)
                    Logger.info("Fallback export icon status: \(fallbackSuccess ? "Success" : "Failure")", category: .core)
                }
                
                // Read the new Plist and then create the metadata.json
                let plistURL = newDirectoryURL
                    .appendingPathComponent("\(labelName).plist")
                
                
                var plistDictionary: [String: Any] = [:]
                
                // Read the plist
                do {
                    Logger.info("Reading plist file: \(plistURL)", category: .core)
                    let plistData = try Data(contentsOf: plistURL)
                    plistDictionary = try PropertyListSerialization.propertyList(
                        from: plistData,
                        options: [],
                        format: nil
                    ) as! [String: Any]
                    
                } catch {
                    Logger.error("Failed to load plist: \(error)", category: .core)
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
                    CFBundleIdentifier: appIDFromPlist ?? ""
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
                    Logger.error("Failed to save metadata: \(error)", category: .core)
                    reply(nil)
                    return
                }
                
                reply(newDirectoryURL.path)
            } catch {
                Logger.error("Failed to create new content: \(error)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Removes a managed label folder and all associated content
    /// Permanently deletes the label directory and all files within it
    /// - Parameters:
    ///   - labelDirectory: Full path to the label directory to remove
    ///   - reply: Callback with success status of the removal operation
    func removeLabelContent(_ labelDirectory: String, reply: @escaping (Bool) -> Void) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: labelDirectory)
            reply(true)
        } catch {
            Logger.error("Failed to remove label content: \(error)", category: .core)
            reply(false)
        }
    }

    
    // MARK: - Label Information Retrieval
    
    /// Fetches label metadata from the Intuneomator server
    /// Downloads and decodes plist information for application details and documentation
    /// - Parameter labelName: Name of the label to fetch information for
    /// - Returns: LabelPlistInfo containing app details, description, and URLs
    /// - Throws: URLError if request fails or server returns invalid response
    func fetchLabelInfo(labelName: String) async throws -> LabelPlistInfo {
        // build URL
        guard let url = URL(string: "https://intuneomator.org/labels")?
                .appendingPathComponent("\(labelName).plist") else {
            throw URLError(.badURL)
        }
        
        Logger.info("Plist URL: \(url)", category: .core)

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
    
    /// Downloads and updates Installomator labels from the official GitHub repository
    /// Refreshes local label collection with latest versions and new applications
    /// - Parameter reply: Callback with success status of the download operation
    func updateLabelsFromGitHub(reply: @escaping (Bool) -> Void) {
        InstallomatorLabels.installInstallomatorLabels { [self] success, message in
            if success {
                Logger.info("Installomator labels downloaded successfully.", category: .core)
            } else {
                Logger.error("Failed to download Installomator labels: \(message)", category: .core)
            }
            reply(success)
        }
    }
        
    // MARK: - Label Configuration Operations
    
    /// Saves label content configuration (placeholder method)
    /// - Parameters:
    ///   - labelFolder: Target label folder name
    ///   - content: Configuration data to save
    ///   - reply: Callback with save operation success status
    func saveLabelContent(_ labelFolder: String, _ content: NSDictionary, reply: @escaping (Bool) -> Void) {
        // Implementation placeholder
    }
    
    /// Toggles between standard Installomator and custom label versions
    /// Switches label script source and updates processing accordingly
    /// - Parameters:
    ///   - labelFolder: Name of the label folder to modify
    ///   - toggle: True to enable custom label, false for standard Installomator
    ///   - reply: Callback with success status of the toggle operation
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
                
                _ = LabelAutomation.runProcessLabelScript(for: labelFolder)

                reply(true)
            } catch {
                Logger.error("Faied to copy custom label: \(error.localizedDescription)", category: .core)
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

                _ = LabelAutomation.runProcessLabelScript(for: labelFolder)
                
                reply(true)
            } catch {
                Logger.error("Faied to delete custom label touch file: \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }

    
    // MARK: - Icon Management Operations
    
    /// Imports an icon file or extracts icon from application bundle for a label
    /// Supports both image files and application bundle icon extraction
    /// - Parameters:
    ///   - iconPath: Path to image file or application bundle
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback with import operation success status
    func importIconToLabel(_ iconPath: String, _ labelFolder: String, reply: @escaping (Bool) -> Void) {
        
        let labelFolderPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(labelFolder)
            .path

        let parts = labelFolder.split(separator: "_")
        var labelName = ""
        
        if parts.count == 2 {
            labelName = String(parts[0]) // Assign the name
        } else {
            Logger.info("Invalid directory format.", category: .core)
            return
        }

        // Create the icon file
        let iconDestinationPath = (labelFolderPath as NSString)
            .appendingPathComponent("\(labelName).png")
        
//        Logger.info("Creating new icon file: \(iconDestinationPath)", category: .core)

        // Check if the icon is an app bundle
        if URL(string: iconPath)!.pathExtension == "app" {
            Logger.info("Selected app bundle", category: .core)
            let iconSuccess = IconExporter.extractAppIcon(appPath: iconPath, outputPath: iconDestinationPath)
            Logger.info("Export status: \(iconSuccess ? "Success" : "Failure")", category: .core)
            reply(iconSuccess)
        } else {
//            Logger.info("Selected image file", category: .core)
            if let cgImage = IconExporter.getCGImageFromPath(fileImagePath: iconPath) {
                IconExporter.saveCGImageAsPNG(cgImage, to: iconDestinationPath)
                reply(true)
            }
        }
    }

    
    
    /// Applies a generic application icon to a label
    /// Uses the default system application icon as fallback
    /// - Parameters:
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback with import operation success status
    func importGenericIconToLabel(_ labelFolder: String, reply: @escaping (Bool) -> Void) {
        
        let labelFolderPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(labelFolder)
            .path
        
        let parts = labelFolder.split(separator: "_")
        var labelName = ""
        
        if parts.count == 2 {
            labelName = String(parts[0]) // Assign the name
        } else {
            Logger.info("Invalid directory format.", category: .core)
            return
        }
        
        // Create the icon file
        let iconDestinationPath = (labelFolderPath as NSString)
            .appendingPathComponent("\(labelName).png")
        
//        Logger.info("Creating new icon file: \(iconDestinationPath)", category: .core)
        
        let iconSuccess = IconExporter.saveGenericAppIcon(to: iconDestinationPath)
        Logger.info("Export status: \(iconSuccess ? "Success" : "Failure")", category: .core)
        reply(iconSuccess)
    }
    
    
    
    
    // MARK: - Metadata Management
    
    /// Saves application metadata configuration to JSON file
    /// Stores detailed application information for Intune deployment
    /// - Parameters:
    ///   - metadata: JSON metadata string to save
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback with save operation success status
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
            Logger.error("Failed to save metadata: \(error)", category: .core)
            reply(false)
        }
    }
    
    
    


    // MARK: - Script Management
    
    /// Saves or removes pre-installation script for a label
    /// Handles script content persistence and file permissions
    /// - Parameters:
    ///   - script: Script content (empty string removes the script)
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback with save operation success status
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
                    Logger.info("Deleted preinstall script: \(preInstallPath)", category: .core)
                    reply(true)
                } else {
//                    Logger.info("No preinstall script to delete at: \(preInstallPath)", category: .core)
                    reply(true)
                }
            } catch {
                Logger.error("Error deleting preinstall script: \(error)", category: .core)
                reply(false)
            }
        } else {
            // Save the file if the script is not blank
            do {
                try preInstallContents.write(to: preInstallPath, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: preInstallPath.path)
                Logger.info("Saved preinstall script: \(preInstallPath)", category: .core)
                reply(true)
            } catch {
                Logger.error("Error saving preinstall script: \(error)", category: .core)
                reply(false)
            }
        }
    }
        

    /// Saves or removes post-installation script for a label
    /// Handles script content persistence and file permissions
    /// - Parameters:
    ///   - script: Script content (empty string removes the script)
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback with save operation success status
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
                    Logger.info("Deleted postinstall script: \(postInstallPath)", category: .core)
                    reply(true)
                } else {
//                    Logger.info("No postinstall script to delete at: \(postInstallPath)", category: .core)
                    reply(true) // No file is considered "successfully deleted"
                }
            } catch {
                Logger.error("Error deleting postinstall script: \(error)", category: .core)
                reply(false)
            }
        } else {
            // Save the file if the script is not blank
            do {
                try postInstallContents.write(to: postInstallPath, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: postInstallPath.path)
                Logger.info("Saved postinstall script: \(postInstallPath)", category: .core)
                reply(true)

            } catch {
                Logger.error("Error saving postinstall script: \(error)", category: .core)
                reply(false)
            }
        }
    }

    
    // MARK: - Group Assignment Management
    
    /// Saves group assignment configuration for a label
    /// Stores targeting and deployment settings for Microsoft Intune groups
    /// - Parameters:
    ///   - groupAssignments: Array of group assignment dictionaries
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback with save operation success status
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
            Logger.error("Failed to create directory at \(basePath): \(error)", category: .core)
            reply(false)
        }
    }
    
    // MARK: - Application Discovery
    
    /// Retrieves discovered macOS applications from Microsoft Intune
    /// Fetches detected applications across managed devices for analysis
    /// - Parameter reply: Callback with encoded DetectedApp array data or nil on failure
    func fetchDiscoveredMacApps(reply: @escaping (Data?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                let apps: [DetectedApp] = try await EntraGraphRequests.fetchMacOSDetectedApps(authToken: authToken)
                do {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(apps)
                    reply(data)
                } catch {
                    Logger.error("Error encoding DetectedApp array: \(error)", category: .core)
                    reply(nil)
                }
            } catch {
                Logger.error("❌ Error fetching detected apps: \(error)", category: .core)
                reply(nil)
            }
        }
    }
        

    /// Fetches device information for a specific discovered application
    /// Retrieves device details where the specified application is installed
    /// - Parameters:
    ///   - appID: Application identifier to search for
    ///   - reply: Callback with encoded DeviceInfo array data or nil on failure
    func fetchDevices(forAppID appID: String, reply: @escaping (Data?) -> Void) {
        Task {
            do {
                let authToken = try await EntraAuthenticator.shared.getEntraIDToken()
                let rawDevices = try await EntraGraphRequests.fetchDevices(authToken: authToken, forAppID: appID)
                
                // Map the tuple array into an array of our Codable struct
                let infos = rawDevices.map {
                    DeviceInfo(deviceName: $0.deviceName, id: $0.id, emailAddress: $0.emailAddress)
                }
                
                let data = try JSONEncoder().encode(infos)
                reply(data)
            }
            catch {
                Logger.error("❌ fetchDevices error: \(error)", category: .core)
                reply(nil)
            }
        }
    }
    
    // MARK: - Automation Trigger
    
    /// Triggers automation by creating the trigger file for the Launch Daemon
    /// Creates the `.automation.trigger` file that the Launch Daemon watches for automation start
    /// - Parameter reply: Callback with success status and optional message
    func triggerAutomation(reply: @escaping (Bool, String?) -> Void) {
        let triggerFileURL = URL(fileURLWithPath: "/Library/Application Support/Intuneomator/.automation.trigger")
        
        do {
            // Ensure the directory exists
            let parentDirectory = triggerFileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDirectory.path) {
                try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Create/touch the trigger file
            let triggerContent = "Triggered by GUI at \(Date())\n"
            try triggerContent.write(to: triggerFileURL, atomically: true, encoding: .utf8)
            
            Logger.info("✅ Automation trigger file created successfully", category: .core)
            reply(true, "Automation triggered successfully")
            
        } catch {
            Logger.error("❌ Failed to create automation trigger file: \(error.localizedDescription)", category: .core)
            reply(false, "Failed to trigger automation: \(error.localizedDescription)")
        }
    }
    
    /// Checks if automation is currently running by examining the status file
    /// Determines if any operations are active (downloading, processing, uploading)
    /// - Parameter reply: Callback indicating if automation is currently active
    func isAutomationRunning(reply: @escaping (Bool) -> Void) {
        let statusFileURL = AppConstants.intuneomatorOperationStatusFileURL
        
        guard FileManager.default.fileExists(atPath: statusFileURL.path) else {
            // No status file means no automation is running
            reply(false)
            return
        }
        
        do {
            let jsonData = try Data(contentsOf: statusFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            
            // Decode the status file to check for active operations
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let operations = json["operations"] as? [String: Any] {
                
                // Check if any operation has an active status
                for (_, operationData) in operations {
                    if let operationDict = operationData as? [String: Any],
                       let statusString = operationDict["status"] as? String {
                        
                        // Check for active statuses
                        if ["downloading", "processing", "uploading"].contains(statusString) {
                            Logger.info("Found active automation operation with status: \(statusString)", category: .core)
                            reply(true)
                            return
                        }
                    }
                }
            }
            
            // No active operations found
            reply(false)
            
        } catch {
            Logger.error("Failed to check automation status: \(error.localizedDescription)", category: .core)
            // If we can't read the status file, assume automation is not running
            reply(false)
        }
    }

    
}

