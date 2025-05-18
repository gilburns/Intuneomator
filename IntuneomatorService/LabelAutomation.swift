//
//  LabelAutomation.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/28/25.
//

import Foundation

class LabelAutomation {
    
    // MARK: - Scan Folders to start the automation run
    static func scanAndValidateFolders() -> [String] {
        Logger.log("🔄 Starting Intune automation run...", logType: "Automation")
        Logger.log("--------------------------------------------------------", logType: "Automation")
        
        var validFolders: [String] = []
        let basePath = AppConstants.intuneomatorManagedTitlesFolderURL.path
        
        do {
            var folderContents = try FileManager.default.contentsOfDirectory(atPath: basePath)
            
            // Sort folder names alphabetically
            folderContents.sort()
            
            for folderName in folderContents {
                let folderPath = (basePath as NSString).appendingPathComponent(folderName)
                
                if AutomationCheck.validateFolder(at: folderPath) {
                    Logger.log("✅ Ready for automation: \(folderName)", logType: "Automation")
                    validFolders.append(folderName)
                } else {
                    Logger.log("⚠️ Not ready for automation: \(folderName)", logType: "Automation")
                }
            }
        } catch {
            Logger.log("❌ Error reading managed titles folder: \(error.localizedDescription)", logType: "LabelAutomation")
        }
        Logger.log("--------------------------------------------------------", logType: "Automation")
        
        Logger.log("📋 Valid software titles for automation: \(validFolders.joined(separator: ", "))", logType: "LabelAutomation")
        Logger.log("🏁 Scan complete. \(validFolders.count) folders ready for automation.", logType: "Automation")

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
        
        Logger.log("❌ Could not find Intuneomator.app in expected locations.", logType: "LabelAutomation")
        return nil
    }
    
    
    static func containsArchCommand(filePath: String) -> Bool {
        do {
            // Attempt to read the contents of the file
            let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Look for either "$(arch)" or "$(/usr/bin/arch)" in the file
            return fileContents.contains("$(arch)") || fileContents.contains("$(/usr/bin/arch)")
        } catch {
            Logger.log("Error reading file at \(filePath): \(error)", logType: "LabelAutomation")
            return false
        }
    }
    
    // Example usage:
    // let result = containsArchCommand(filePath: "/path/to/your/script.sh")
    // print("Contains architecture command: \(result)")
    
    
    static func runProcessLabelScript(for folderName: String) -> Bool {
        return InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
    }
    
    // MARK: - Collect the plist data so we can download the file
    
    // Function to extract plist data
    static func extractDataForProcessedAppResults(from folderName: String) -> ProcessedAppResults? {
        
        // Extract the label name (before the UUID part)
        let parts = folderName.split(separator: "_")
        let labelName = String(parts[0])
        let labelGUID = String(parts[1])
        
        // Verify we have a valid folder name
        guard parts.count == 2 else {
            Logger.log("❌ Invalid folder format: \(folderName)", logType: "LabelAutomation")
            return nil
        }
        
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
            Logger.log("Failed to load metadata: \(error)", logType: "LabelAutomation")
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
            Logger.log("❌ Critical metadata keys are missing for \(folderName). Skipping.", logType: "LabelAutomation")
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
        #if DEBUG
        Logger.log("  Title is dual arch: \(titleIsDualArch)", logType: "LabelAutomation")
        #endif
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
            Logger.log("❌ Missing plist file: \(plistPath)", logType: "LabelAutomation")
            return nil
        }
        
        Logger.log("  Reading plist: \(plistPath)", logType: "LabelAutomation")
        
        // Read plist data
        guard let plistData = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else {
            Logger.log("❌ Failed to parse plist: \(plistPath)", logType: "LabelAutomation")
            return nil
        }
        
        // We need both downloadURLs to build a Universal pkg
        if metadata?.deployAsArchTag == 2 && titleIsDualArch {
            guard let plistDatax86_64 = NSDictionary(contentsOfFile: plistPathx86_64) as? [String: Any] else {
                Logger.log("❌ Failed to parse plist: \(plistPathx86_64)", logType: "LabelAutomation")
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
            Logger.log("❌ Critical plist keys are missing for \(folderName). Skipping.", logType: "LabelAutomation")
            return nil
        }
        
        Logger.log("  Extracted plist and metadata for \(folderName): name=\(validatedName), version=\(appNewVersion ?? "N/A"), downloadURL=\(validatedDownloadURL), type=\(validatedType)", logType: "LabelAutomation")
        
        
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
                Logger.log("Error loading preinstall script: \(error)", logType: "LabelAutomation")
            }
        } else {
            preInstallScript = "" // Clear if file doesn't exist
        }
        
        // Load Postinstall Script
        if FileManager.default.fileExists(atPath: postInstallPath.path) {
            do {
                postInstallScript = try String(contentsOf: postInstallPath, encoding: .utf8)
            } catch {
                Logger.log("Error loading postinstall script: \(error)", logType: "LabelAutomation")
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
                #if DEBUG
                Logger.log("Loaded \(groupAssignments.count) group assignments", logType: "LabelAutomation")
                Logger.log("Group assignments: \(groupAssignments)", logType: "LabelAutomation")
                #endif
            } else {
                Logger.log("JSON format is invalid", logType: "LabelAutomation")
            }
        } catch {
            Logger.log("Failed to load assignments: \(error)", logType: "LabelAutomation")
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
    

    
    // MARK: - Downloaded file
    // Check if the version already exists in cache
    static func isVersionCached(forLabel labelName: String, displayName: String, version: String, deploymentType: Int, deploymentArch: Int) throws -> URL {
        let versionCheckPath = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent("\(labelName)/\(version)/")
        
        Logger.log("LabelAutomation: Checking cache for version: \(versionCheckPath)", logType: "LabelAutomation")
        Logger.log("Label: \(labelName)", logType: "LabelAutomation")
        Logger.log("Display name: \(displayName)", logType: "LabelAutomation")
        Logger.log("Version: \(version)", logType: "LabelAutomation")
        Logger.log("Deployment type: \(deploymentType)", logType: "LabelAutomation")
        Logger.log("Deployment arch: \(deploymentArch)", logType: "LabelAutomation")
        
        let fileName: String
        
        let fileSuffix: String
        if deploymentType == 0 {
            fileSuffix = "dmg"
        } else {
            fileSuffix = "pkg"
        }
        
        let fileArch: String
        if deploymentArch == 0 {
            fileArch = "arm64"
        } else if deploymentArch == 1 {
            fileArch = "x86_64"
        } else {
            fileArch = "universal"
        }
        
        if deploymentType == 2 {
            fileName = "\(displayName)-\(version).\(fileSuffix)"
        } else  {
            fileName = "\(displayName)-\(version)-\(fileArch).\(fileSuffix)"
        }
        
        
        let fullPath: URL = URL(fileURLWithPath: String(describing: versionCheckPath
            .appendingPathComponent(fileName).path.removingPercentEncoding!))
        
        if FileManager.default.fileExists(atPath: fullPath.path) {
            Logger.log("LabelAutomation: File exists: \(fullPath.path))", logType: "LabelAutomation")
            return fullPath
        } else {
            Logger.log("LabelAutomation: File does not exists: \(fullPath.path)", logType: "LabelAutomation")
        }
        
        throw NSError(domain: "InvalidURL", code: 100, userInfo: [NSLocalizedDescriptionKey: "Cached file not found: \(fileName)"])
    }
    
    
    // Async version of the function (alternative approach)
    static func isVersionUploadedToIntuneAsync(appInfo: [FilteredIntuneAppInfo], version: String) async -> Bool {
        // Simple direct check
        return appInfo.contains { app in
            return app.primaryBundleVersion == version
        }
    }
    
    
    // MARK: - Download File
    static func downloadFile(for folderName: String, processedAppResults: ProcessedAppResults, downloadArch: String = "Arm") async throws -> URL {
        
        var url: URL
        
        if downloadArch == "Arm" {
            guard let urlForArch = URL(string: processedAppResults.appDownloadURL) else {
                throw NSError(domain: "InvalidURL", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL provided"])
            }
            url = urlForArch
        } else {
            guard let urlForArch = URL(string: processedAppResults.appDownloadURLx86) else {
                throw NSError(domain: "InvalidURL", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL provided"])
            }
            url = urlForArch
        }
                
        Logger.log("  Starting download from \(String(describing: url))", logType: "LabelAutomation")
        
        let labelName = folderName.components(separatedBy: "_").first ?? folderName
        
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(labelName)
            .appendingPathComponent("tmp")
        
        
        // Create a temporary directory for the download
        let downloadsDir = downloadFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        
        // Download the file
        let (tempLocation, response) = try await URLSession.shared.download(from: url)
        
        // Validate the response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NetworkError", code: 101, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
        }
        
        // Try to extract filename from Content-Disposition header
        var finalFilename: String
        let finalURL = response.url ?? url
        if let lastComponent = finalURL.lastPathComponent.removingPercentEncoding,
           !lastComponent.isEmpty {
            finalFilename = lastComponent
        } else if let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition"),
                  let filename = extractFilename(from: contentDisposition) {
            finalFilename = filename
        } else {
            // Fallback if both URL and Content-Disposition failed
            let ext = finalURL.pathExtension.isEmpty ? "dmg" : finalURL.pathExtension
            finalFilename = "\(processedAppResults.appDisplayName)_\(processedAppResults.appVersionExpected).\(ext)"
        }
        
        let destinationURL = downloadsDir
            .appendingPathComponent(finalFilename)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
            Logger.log("🗑️ Removed existing file: \(destinationURL.path)", logType: "LabelAutomation")
        }
        
        // Move the file to temp destination
        try FileManager.default.moveItem(at: tempLocation, to: destinationURL)
        
        // Get file size for logging
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
        let fileSizeMB = Double(fileSizeBytes) / 1_048_576
        
        Logger.log("  Download complete: \(finalFilename) (\(String(format: "%.2f", fileSizeMB)) MB)", logType: "LabelAutomation")
        Logger.log("  Downloaded to: \(destinationURL.path)", logType: "LabelAutomation")
        
        Logger.logFileTransfer("\(labelName)\t\(finalFilename)\t\(String(format: "%.2f", fileSizeMB)) MB\t\(finalURL)", logType: "Download")

        
        return destinationURL
    }
    
    // file name from the Content Disposition
    private static func extractFilename(from contentDisposition: String) -> String? {
        // Look for format: attachment; filename="example.pkg"
        let pattern = #"filename="?([^"]+)"?"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: contentDisposition, options: [], range: NSRange(contentDisposition.startIndex..., in: contentDisposition)),
           let range = Range(match.range(at: 1), in: contentDisposition) {
            return String(contentDisposition[range])
        }
        return nil
    }
    
    
    // MARK: - Process Downloaded File
    static func processDownloadedFile(displayName: String, downloadURL: URL, downloadURLx86: URL, folderName: String, processedAppResults: ProcessedAppResults) async throws -> (url: URL, name: String, bundleID: String, version: String) {
        
        Logger.log("Processing downloaded file...", logType: "LabelAutomation")
        Logger.log("  Display Name: \(displayName)", logType: "LabelAutomation")
        Logger.log("  Download URL: \(downloadURL.absoluteString)", logType: "LabelAutomation")
        Logger.log("  Download URL x86: \(downloadURLx86.absoluteString)", logType: "LabelAutomation")
        Logger.log("  Folder name: \(folderName)", logType: "LabelAutomation")
        
        let downloadType = processedAppResults.appLabelType
        let labelName = folderName.components(separatedBy: "_").first ?? folderName
        
        var outputFileName: String? = nil
        var outputURL: URL? = nil
        var outputAppName: String? = nil
        var outputAppBundleID: String? = nil
        var outputAppVersion: String? = nil
        
        let version = processedAppResults.appVersionExpected
        
        Logger.log("  Processing downloaded file: \(downloadURL.lastPathComponent)", logType: "LabelAutomation")
        Logger.log("  File type: \(downloadType)", logType: "LabelAutomation")
                
        
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(labelName)

        // New Processing
        switch downloadType.lowercased() {
        case "pkg", "pkginzip", "pkgindmg", "pkgindmginzip":
        
            var pkgToProcessURL: URL!
            
            switch downloadType.lowercased() {
            case "pkg":
                Logger.log("Handle type pkg specifics", logType: "LabelAutomation")
                // Handle PKG file
                // Nothing needed here for pkg type
                pkgToProcessURL = downloadURL
            case "pkginzip":
                Logger.log("Handle type pkginzip specifics", logType: "LabelAutomation")
                // Extract ZIP, find PKG file
                let extractedFolder = try await extractZipFile(zipURL: downloadURL)
                let pkgFiles = try findFiles(inFolder: extractedFolder, withExtension: "pkg")
                
                guard let pkgFile = pkgFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 102, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in ZIP archive"])
                }
                pkgToProcessURL = pkgFile
                Logger.log("Pkg to process: \(pkgToProcessURL.absoluteString)", logType: "LabelAutomation")
                
            case "pkgindmg":
                Logger.log("Handle type pkgindmg specifics", logType: "LabelAutomation")
                // Mount DMG, find PKG file
                let mountPoint = try await mountDMGFile(dmgURL: downloadURL)
                defer { _ = try? unmountDMG(mountPoint: mountPoint) }

                let pkgFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "pkg")

                guard let pkgFile = pkgFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 103, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in mounted DMG"])
                }

                Logger.log("pkgFile: \(pkgFile.path)", logType: "LabelAutomation")
                let pkgName = pkgFile.lastPathComponent
                Logger.log("Pkg name: \(pkgName)", logType: "LabelAutomation")

                if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                    let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(pkgName)
                    // Remove existing file if present
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(atPath: pkgFile.path, toPath: destinationURL.path)
                    pkgToProcessURL = destinationURL
                    Logger.log("Pkg to process: \(pkgToProcessURL.absoluteString)", logType: "LabelAutomation")
                } else {
                    throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory"])
                }

            case "pkgindmginzip":
                Logger.log("Handle type pkgindmginzip specifics", logType: "LabelAutomation")
                // Extract ZIP, mount DMG, find PKG file
                let extractedFolder = try await extractZipFile(zipURL: downloadURL)
                let dmgFiles = try findFiles(inFolder: extractedFolder, withExtension: "dmg")
                
                guard let dmgFile = dmgFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 104, userInfo: [NSLocalizedDescriptionKey: "No DMG file found in ZIP archive"])
                }
                
                let mountPoint = try await mountDMGFile(dmgURL: dmgFile)
//                defer { _ = try? unmountDMG(mountPoint: mountPoint) }
                
                let pkgFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "pkg")
                
                guard let pkgFile = pkgFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 105, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in mounted DMG (from ZIP)"])
                }
                
                Logger.log("pkgFile: \(pkgFile.path)", logType: "LabelAutomation")
                let pkgName = pkgFile.lastPathComponent
                Logger.log("Pkg name: \(pkgName)", logType: "LabelAutomation")

                if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                    let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(pkgName)
                    // Remove existing file if present
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(atPath: pkgFile.path, toPath: destinationURL.path)
                    pkgToProcessURL = destinationURL
                    Logger.log("Pkg to process: \(pkgToProcessURL.absoluteString)", logType: "LabelAutomation")
                } else {
                    throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory"])
                }

            default:
                break
            }
        
            // Check Signature
            let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: pkgToProcessURL, inpectionType: "pkg")
            
            Logger.log("  Inspect result: \(signatureResult)", logType: "LabelAutomation")
            
            if signatureResult == true {
                Logger.log("  Signature is valid.", logType: "LabelAutomation")
            } else {
                Logger.log("  Signature is invalid.", logType: "LabelAutomation")
                throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
            }
            
            // Get Version from download
            let pkgInspector = PkgInspector()
            let pkgURL = pkgToProcessURL
            let packageID = processedAppResults.appBundleIdExpected
            
            let downloadedVersion = await withCheckedContinuation { continuation in
                pkgInspector.getVersion(forPackageID: packageID, inPkgAt: pkgURL!) { result in
                    switch result {
                    case .success(let version):
                        if let version = version {
                            Logger.log("  Version for package ID '\(packageID)': \(version)", logType: "LabelAutomation")
                            continuation.resume(returning: version)
                        } else {
                            Logger.log("  Package ID '\(packageID)' not found in the .pkg", logType: "LabelAutomation")
                            continuation.resume(returning: "None")
                        }
                    case .failure(let error):
                        Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: "LabelAutomation")
                        continuation.resume(returning: "None")
                    }
                }
            }
            
            // Create the final destination folder
            let finalDestinationFolder = downloadFolder
                .appendingPathComponent(downloadedVersion)
            
            try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)

            // set output filename
            outputFileName = "\(displayName)-\(downloadedVersion).pkg"
            
            //set output full path
            let destinationURL = finalDestinationFolder
                .appendingPathComponent(outputFileName ?? "Unknown.pkg")
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: pkgToProcessURL, to: destinationURL)
            
            Logger.log("📁 Copied file to: \(destinationURL.path)", logType: "LabelAutomation")

            
            Logger.log("Output URL: \(destinationURL)", logType: "LabelAutomation")
            Logger.log("Output App Name: \(processedAppResults.appDisplayName)", logType: "LabelAutomation")
            Logger.log("Output App Bundle ID: \(packageID)", logType: "LabelAutomation")
            Logger.log("Output App Version: \(String(describing: outputAppVersion))", logType: "LabelAutomation")
            
            let outputURL: URL? = destinationURL
            
            return (url: outputURL!, name: processedAppResults.appDisplayName, bundleID: packageID, version: downloadedVersion)
            
            
        case "zip", "tbz", "dmg", "appindmginzip":
                        
            Logger.log("Processing App Download URL type: \(downloadType) - \(downloadURL)", logType: "LabelAutomation")
            
            // PKG - Universal - Dual Arch DMGs
            if processedAppResults.appDeploymentType == 1 && processedAppResults.appDeploymentArch == 2 && processedAppResults.appIsDualArchCapable == true {
                
                
                Logger.log("Building Universal Dual Arch Package", logType: "LabelAutomation")
                Logger.log("Arch 1: \(downloadURL)", logType: "LabelAutomation")
                Logger.log("Arch 2: \(downloadURLx86)", logType: "LabelAutomation")
                
                var appFiles: [URL]!
                var appFilesFound: [URL]! = []
                var finalDestinationFolder: URL!
                var downloadedVersions: [String] = []

                
                let downloadArray = [downloadURL, downloadURLx86]
                for downloadURL in downloadArray {
                    
                    Logger.log("Processing App Download URL: \(downloadURL)", logType: "LabelAutomation")
                    
                    switch downloadType.lowercased() {
                    case "zip":
                        Logger.log("Handle type zip specifics", logType: "LabelAutomation")
                        // Extract ZIP, find and copy .app
                        let extractedFolder = try await extractZipFileWithDitto(zipURL: downloadURL)
                        appFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
                        
                        guard let appFile = appFiles.first else {
                            throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "No .app file found in ZIP archive"])
                            
                        }
                        appFilesFound += [appFile]

                    case "tbz":
                        Logger.log("Handle type tbz specifics", logType: "LabelAutomation")
                        // Extract TBZ, find and copy .app
                        let extractedFolder = try await extractTBZFile(tbzURL: downloadURL)
                        let appFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
                        
                        guard let appFile = appFiles.first else {
                            throw NSError(domain: "ProcessingError", code: 107, userInfo: [NSLocalizedDescriptionKey: "No .app file found in TBZ archive"])
                        }
                        appFilesFound += [appFile]

                    case "dmg":
                        Logger.log("Handle type dmg specifics", logType: "LabelAutomation")
                        // Mount DMG, find and copy .app
                        let mountPoint = try await mountDMGFile(dmgURL: downloadURL)
                        defer { _ = try? unmountDMG(mountPoint: mountPoint) }
                        
                        let appFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
                        
                        guard let appFile = appFiles.first else {
                            throw NSError(domain: "ProcessingError", code: 108, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG"])
                        }
                        
                        Logger.log("appFile: \(appFile.path)", logType: "LabelAutomation")
                        let appName = appFile.lastPathComponent
                        Logger.log("App name: \(appName)", logType: "LabelAutomation")

                        if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                            let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(appName)
                            // Remove existing file if present
                            if FileManager.default.fileExists(atPath: destinationURL.path) {
                                try FileManager.default.removeItem(at: destinationURL)
                            }
                            try FileManager.default.copyItem(atPath: appFile.path, toPath: destinationURL.path)
                            
                            appFilesFound += [destinationURL]

                            Logger.log("App to process: \(String(describing: appFilesFound))", logType: "LabelAutomation")
                        } else {
                            throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory"])
                        }

                    case "appindmginzip":
                        Logger.log("Handle type appindmginzip specifics", logType: "LabelAutomation")
                        // Extract ZIP, mount DMG, find and copy .app
                        let extractedFolder = try await extractZipFile(zipURL: downloadURL)
                        let dmgFiles = try findFiles(inFolder: extractedFolder, withExtension: "dmg")
                        
                        guard let dmgFile = dmgFiles.first else {
                            throw NSError(domain: "ProcessingError", code: 109, userInfo: [NSLocalizedDescriptionKey: "No DMG file found in ZIP archive"])
                        }
                        
                        let mountPoint = try await mountDMGFile(dmgURL: dmgFile)
                        defer { _ = try? unmountDMG(mountPoint: mountPoint) }
                        let appFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
                        
                        guard let appFile = appFiles.first else {
                            throw NSError(domain: "ProcessingError", code: 110, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG (from ZIP)"])
                        }

                        Logger.log("appFile: \(appFile.path)", logType: "LabelAutomation")
                        let appName = appFile.lastPathComponent
                        Logger.log("App name: \(appName)", logType: "LabelAutomation")

                        if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                            let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(appName)
                            // Remove existing file if present
                            if FileManager.default.fileExists(atPath: destinationURL.path) {
                                try FileManager.default.removeItem(at: destinationURL)
                            }
                            try FileManager.default.copyItem(atPath: appFile.path, toPath: destinationURL.path)

                            appFilesFound += [destinationURL]

                            Logger.log("App to process: \(String(describing: appFilesFound))", logType: "LabelAutomation")
                        } else {
                            throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory"])
                        }

                    default:
                        break
                    }


                }

                // Validate and get info for apps
                
                for (index, appFile) in appFilesFound.enumerated() {
                    Logger.log("Checking app \(index): \(appFile)", logType: "LabelAutomation")

                    // Check Signature
                    let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: appFile, inpectionType: "app")
                    
                    Logger.log("  Inspect result: \(signatureResult)", logType: "LabelAutomation")
                    
                    if signatureResult == true {
                        Logger.log("  Signature is valid.", logType: "LabelAutomation")
                    } else {
                        Logger.log("  Signature is invalid.", logType: "LabelAutomation")
                        throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
                    }
                    
                    // Get Version from download
                    let expectedBundleID = processedAppResults.appBundleIdExpected
                    
                    let inspector = AppInspector()
                    var downloadedVersion = await withCheckedContinuation { continuation in
                        inspector.getVersion(forBundleID: expectedBundleID, inAppAt: appFile) { result in
                            switch result {
                            case .success(let version):
                                if let version = version {
                                    Logger.log("  Version for package ID '\(expectedBundleID)': \(version)", logType: "LabelAutomation")
                                    continuation.resume(returning: version)
                                } else {
                                    Logger.log("  Package ID '\(expectedBundleID)' not found in the .pkg", logType: "LabelAutomation")
                                    continuation.resume(returning: "None")
                                }
                            case .failure(let error):
                                Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: "LabelAutomation")
                                continuation.resume(returning: "None")
                            }
                        }
                    }
                    
                    downloadedVersions.append(downloadedVersion)
                    
                }
                
                if downloadedVersions[0] != downloadedVersions[1] {
                    Logger.log("🛑 Versions do not match!", logType: "LabelAutomation")
                } else {
                    Logger.log("✅ Versions match!", logType: "LabelAutomation")
                }
                
                
                // Check that the dual arhitecture matches expecations
                let expectedArchitectures: [AppArchitecture] = [.arm64, .x86_64]
                do {
                    try validateAppArchitectures(urls: appFilesFound, expected: expectedArchitectures)
                    // all good — proceed with your next steps
                    Logger.log("✅ Architectures match expected!", logType: "LabelAutomation")
                } catch {
                    // mismatch — handle or surface the error
                    Logger.log("❌ \(error)", logType: "LabelAutomation")
                }
                
                
                // Create the final destination folder
                finalDestinationFolder = AppConstants.intuneomatorCacheFolderURL
                    .appendingPathComponent(processedAppResults.appLabelName)
                    .appendingPathComponent(downloadedVersions[0])

                try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)

                Logger.log("Universal pkg creation", logType: "LabelAutomation")
                let pkgCreator = PKGCreatorUniversal()
                if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createUniversalPackage(inputPathArm64: appFilesFound[0].path, inputPathx86_64: appFilesFound[1].path, outputDir: finalDestinationFolder.path) {
                    Logger.log("  Package creation succeeded.", logType: "LabelAutomation")
                    outputURL = URL(string: outputURLResult)
                    outputAppName = outputAppNameResult
                    outputAppBundleID = outputAppBundleIDResult
                    outputAppVersion = outputAppVersionResult
                }
                
                return (url: outputURL!, name: outputAppName!, bundleID: outputAppBundleID!, version: outputAppVersion!)

                
            } else {
                
                var appFiles: [URL]!
                var appFileFound: URL!
                var finalDestinationFolder: URL!
                
                switch downloadType.lowercased() {
                case "zip":
                    Logger.log("Handle type zip specifics", logType: "LabelAutomation")
                    // Extract ZIP, find and copy .app
                    let extractedFolder = try await extractZipFileWithDitto(zipURL: downloadURL)
                    appFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
                    
                    guard let appFile = appFiles.first else {
                        throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "No .app file found in ZIP archive"])
                        
                    }
                    appFileFound = appFile

                case "tbz":
                    Logger.log("Handle type tbz specifics", logType: "LabelAutomation")
                    // Extract TBZ, find and copy .app
                    let extractedFolder = try await extractTBZFile(tbzURL: downloadURL)
                    let appFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
                    
                    guard let appFile = appFiles.first else {
                        throw NSError(domain: "ProcessingError", code: 107, userInfo: [NSLocalizedDescriptionKey: "No .app file found in TBZ archive"])
                    }
                    appFileFound = appFile

                case "dmg":
                    Logger.log("Handle type dmg specifics", logType: "LabelAutomation")
                    // Mount DMG, find and copy .app
                    let mountPoint = try await mountDMGFile(dmgURL: downloadURL)
                    defer { _ = try? unmountDMG(mountPoint: mountPoint) }
                    
                    let appFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
                    
                    guard let appFile = appFiles.first else {
                        throw NSError(domain: "ProcessingError", code: 108, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG"])
                    }
                    
                    Logger.log("appFile: \(appFile.path)", logType: "LabelAutomation")
                    let appName = appFile.lastPathComponent
                    Logger.log("App name: \(appName)", logType: "LabelAutomation")

                    if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                        let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(appName)
                        // Remove existing file if present
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.removeItem(at: destinationURL)
                        }
                        try FileManager.default.copyItem(atPath: appFile.path, toPath: destinationURL.path)
                        appFileFound = destinationURL
                        Logger.log("App to process: \(appFileFound.absoluteString)", logType: "LabelAutomation")
                    } else {
                        throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory"])
                    }

                case "appindmginzip":
                    Logger.log("Handle type appindmginzip specifics", logType: "LabelAutomation")
                    // Extract ZIP, mount DMG, find and copy .app
                    let extractedFolder = try await extractZipFile(zipURL: downloadURL)
                    let dmgFiles = try findFiles(inFolder: extractedFolder, withExtension: "dmg")
                    
                    guard let dmgFile = dmgFiles.first else {
                        throw NSError(domain: "ProcessingError", code: 109, userInfo: [NSLocalizedDescriptionKey: "No DMG file found in ZIP archive"])
                    }
                    
                    let mountPoint = try await mountDMGFile(dmgURL: dmgFile)
                    defer { _ = try? unmountDMG(mountPoint: mountPoint) }
                    let appFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
                    
                    guard let appFile = appFiles.first else {
                        throw NSError(domain: "ProcessingError", code: 110, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG (from ZIP)"])
                    }

                    Logger.log("appFile: \(appFile.path)", logType: "LabelAutomation")
                    let appName = appFile.lastPathComponent
                    Logger.log("App name: \(appName)", logType: "LabelAutomation")

                    if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                        let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(appName)
                        // Remove existing file if present
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.removeItem(at: destinationURL)
                        }
                        try FileManager.default.copyItem(atPath: appFile.path, toPath: destinationURL.path)
                        appFileFound = destinationURL
                        Logger.log("App to process: \(appFileFound.absoluteString)", logType: "LabelAutomation")
                    } else {
                        throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory"])
                    }

                default:
                    break
                }
                
                let appFile = appFileFound!
                                
                // Check Signature
                let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: appFile, inpectionType: "app")
                
                Logger.log("  Inspect result: \(signatureResult)", logType: "LabelAutomation")
                
                if signatureResult == true {
                    Logger.log("  Signature is valid.", logType: "LabelAutomation")
                } else {
                    Logger.log("  Signature is invalid.", logType: "LabelAutomation")
                    throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
                }
                
                // Get Version from download
                let expectedBundleID = processedAppResults.appBundleIdExpected
                
                let inspector = AppInspector()
                let downloadedVersion = await withCheckedContinuation { continuation in
                    inspector.getVersion(forBundleID: expectedBundleID, inAppAt: appFile) { result in
                        switch result {
                        case .success(let version):
                            if let version = version {
                                Logger.log("  Version for package ID '\(expectedBundleID)': \(version)", logType: "LabelAutomation")
                                continuation.resume(returning: version)
                            } else {
                                Logger.log("  Package ID '\(expectedBundleID)' not found in the .pkg", logType: "LabelAutomation")
                                continuation.resume(returning: "None")
                            }
                        case .failure(let error):
                            Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: "LabelAutomation")
                            continuation.resume(returning: "None")
                        }
                    }
                }
                
                // Create the final destination folder
                finalDestinationFolder = downloadFolder
                    .appendingPathComponent(downloadedVersion)
                
                try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)

                if processedAppResults.appDeploymentType == 0 {
                    // Create DMG for same app for Intune use
                    let dmgCreator = DMGCreator()
                    do {
                        let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = try dmgCreator.processToDMG(inputPath: appFile.path, outputDirectory: finalDestinationFolder.path)
                        Logger.log("Created DMG at \(String(describing: outputURLResult)) for \(outputAppNameResult) (\(outputAppBundleIDResult)) version \(outputAppVersionResult)", logType: "LabelAutomation")
                        
                        outputURL = URL(string: outputURLResult)
                        outputAppName = outputAppNameResult
                        outputAppBundleID = outputAppBundleIDResult
                        outputAppVersion = outputAppVersionResult
                    } catch {
                        Logger.log("Failed to process DMG: \(error.localizedDescription)", logType: "LabelAutomation")
                        // Handle the error appropriately
                    }
                    
                } else {
                    Logger.log("Standard single arch pkg creation", logType: "LabelAutomation")
                    let pkgCreator = PKGCreator()
                    if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createPackage(inputPath: appFile.path, outputDir: finalDestinationFolder.path) {
                        Logger.log("  Package creation succeeded.", logType: "LabelAutomation")
                        outputURL = URL(string: outputURLResult)
                        outputAppName = outputAppNameResult
                        outputAppBundleID = outputAppBundleIDResult
                        outputAppVersion = outputAppVersionResult
                    } else {
                        Logger.log("Package creation failed.", logType: "LabelAutomation")
                    }
                }
                
                Logger.log("  Output URL: \(outputURL!)", logType: "LabelAutomation")
                Logger.log("  Output App Name: \(outputAppName!)", logType: "LabelAutomation")
                Logger.log("  Output App Bundle ID: \(outputAppBundleID!)", logType: "LabelAutomation")
                Logger.log("  Output App Version: \(outputAppVersion!)", logType: "LabelAutomation")
                

            }
            
            return (url: outputURL!, name: outputAppName!, bundleID: outputAppBundleID!, version: outputAppVersion!)

            

        default:
            print("Unhandled type")
            throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type: \(downloadType)"])
        }


        // END NEW STUFF

        switch downloadType.lowercased() {
            // MARK: - processDownloadedFile pkg
        case "pkg":
            
            // Check Signature
            let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: downloadURL, inpectionType: "pkg")
            
            Logger.log("  Inspect result: \(signatureResult)", logType: "LabelAutomation")
            
            if signatureResult == true {
                Logger.log("  Signature is valid.", logType: "LabelAutomation")
            } else {
                Logger.log("  Signature is invalid.", logType: "LabelAutomation")
                throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
            }
            
            // Get Version from download
            let pkgInspector = PkgInspector()
            let pkgURL = downloadURL
            let packageID = processedAppResults.appBundleIdExpected
            
            let downloadedVersion = await withCheckedContinuation { continuation in
                pkgInspector.getVersion(forPackageID: packageID, inPkgAt: pkgURL) { result in
                    switch result {
                    case .success(let version):
                        if let version = version {
                            Logger.log("  Version for package ID '\(packageID)': \(version)", logType: "LabelAutomation")
                            continuation.resume(returning: version)
                        } else {
                            Logger.log("  Package ID '\(packageID)' not found in the .pkg", logType: "LabelAutomation")
                            continuation.resume(returning: "None")
                        }
                    case .failure(let error):
                        Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: "LabelAutomation")
                        continuation.resume(returning: "None")
                    }
                }
            }
            
            // Create the final destination folder
            let finalDestinationFolder = downloadFolder
                .appendingPathComponent(downloadedVersion)
            
            try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)

            // set output filename
            outputFileName = "\(displayName)-\(downloadedVersion).pkg"
            
            //set output full path
            let destinationURL = finalDestinationFolder
                .appendingPathComponent(outputFileName ?? "Unknown.pkg")
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: downloadURL, to: destinationURL)
            
            Logger.log("📁 Copied file to: \(destinationURL.path)", logType: "LabelAutomation")

            
            Logger.log("Output URL: \(destinationURL)", logType: "LabelAutomation")
            Logger.log("Output App Name: \(processedAppResults.appDisplayName)", logType: "LabelAutomation")
            Logger.log("Output App Bundle ID: \(packageID)", logType: "LabelAutomation")
            Logger.log("Output App Version: \(String(describing: outputAppVersion))", logType: "LabelAutomation")
            
            let outputURL: URL? = destinationURL
            
            return (url: outputURL!, name: processedAppResults.appDisplayName, bundleID: packageID, version: downloadedVersion)
            
            // MARK: - processDownloadedFile pkginzip
        case "pkginzip":

            // Extract ZIP, find PKG file
            let extractedFolder = try await extractZipFile(zipURL: downloadURL)
            let pkgFiles = try findFiles(inFolder: extractedFolder, withExtension: "pkg")
            
            guard let pkgFile = pkgFiles.first else {
                throw NSError(domain: "ProcessingError", code: 102, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in ZIP archive"])
            }
            
            // Check Signature
            let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: downloadURL, inpectionType: "pkg")
            
            Logger.log("  Inspect result: \(signatureResult)", logType: "LabelAutomation")
            
            if signatureResult == true {
                Logger.log("  Signature is valid.", logType: "LabelAutomation")
            } else {
                Logger.log("  Signature is invalid.", logType: "LabelAutomation")
                throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
            }
            
            // Get Version from download
            let pkgInspector = PkgInspector()
            let pkgURL = downloadURL
            let packageID = processedAppResults.appBundleIdExpected
            
            let downloadedVersion = await withCheckedContinuation { continuation in
                pkgInspector.getVersion(forPackageID: packageID, inPkgAt: pkgURL) { result in
                    switch result {
                    case .success(let version):
                        if let version = version {
                            Logger.log("  Version for package ID '\(packageID)': \(version)", logType: "LabelAutomation")
                            continuation.resume(returning: version)
                        } else {
                            Logger.log("  Package ID '\(packageID)' not found in the .pkg", logType: "LabelAutomation")
                            continuation.resume(returning: "None")
                        }
                    case .failure(let error):
                        Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: "LabelAutomation")
                        continuation.resume(returning: "None")
                    }
                }
            }
            
            // Create the final destination folder
            let finalDestinationFolder = downloadFolder
                .appendingPathComponent(downloadedVersion)
            
            try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)

            // set output filename
            outputFileName = "\(displayName)-\(downloadedVersion).pkg"
            
            //set output full path
            let destinationURL = finalDestinationFolder
                .appendingPathComponent(outputFileName ?? "Unknown.pkg")
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: downloadURL, to: destinationURL)
            
            Logger.log("📁 Copied file to: \(destinationURL.path)", logType: "LabelAutomation")

            
            Logger.log("Output URL: \(destinationURL)", logType: "LabelAutomation")
            Logger.log("Output App Name: \(processedAppResults.appDisplayName)", logType: "LabelAutomation")
            Logger.log("Output App Bundle ID: \(packageID)", logType: "LabelAutomation")
            Logger.log("Output App Version: \(String(describing: outputAppVersion))", logType: "LabelAutomation")
            
            let outputURL: URL? = destinationURL

            return (url: outputURL!, name: outputAppName!, bundleID: outputAppBundleID!, version: outputAppVersion!)
            
            // MARK: - processDownloadedFile pkgindmg
        case "pkgindmg":
            Logger.log("Type is pkgindmg", logType: "LabelAutomation")
            // Mount DMG, find PKG file
            let mountPoint = try await mountDMGFile(dmgURL: downloadURL)
//            defer { _ = try? unmountDMG(mountPoint: mountPoint) }
            
            let pkgFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "pkg")
            
            guard let pkgFile = pkgFiles.first else {
                throw NSError(domain: "ProcessingError", code: 103, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in mounted DMG"])
            }
            
            // Check Signature
            let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: downloadURL, inpectionType: "pkg")
            
            Logger.log("  Inspect result: \(signatureResult)", logType: "LabelAutomation")
            
            if signatureResult == true {
                Logger.log("  Signature is valid.", logType: "LabelAutomation")
            } else {
                Logger.log("  Signature is invalid.", logType: "LabelAutomation")
                throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
            }
            
            // Get Version from download
            let pkgInspector = PkgInspector()
            let pkgURL = downloadURL
            let packageID = processedAppResults.appBundleIdExpected
            
            let downloadedVersion = await withCheckedContinuation { continuation in
                pkgInspector.getVersion(forPackageID: packageID, inPkgAt: pkgURL) { result in
                    switch result {
                    case .success(let version):
                        if let version = version {
                            Logger.log("  Version for package ID '\(packageID)': \(version)", logType: "LabelAutomation")
                            continuation.resume(returning: version)
                        } else {
                            Logger.log("  Package ID '\(packageID)' not found in the .pkg", logType: "LabelAutomation")
                            continuation.resume(returning: "None")
                        }
                    case .failure(let error):
                        Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: "LabelAutomation")
                        continuation.resume(returning: "None")
                    }
                }
            }
            
            // Create the final destination folder
            let finalDestinationFolder = downloadFolder
                .appendingPathComponent(downloadedVersion)
            
            try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)

            // set output filename
            outputFileName = "\(displayName)-\(downloadedVersion).pkg"
            
            //set output full path
            let destinationURL = finalDestinationFolder
                .appendingPathComponent(outputFileName ?? "Unknown.pkg")
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: downloadURL, to: destinationURL)
            
            Logger.log("📁 Copied file to: \(destinationURL.path)", logType: "LabelAutomation")

            
            Logger.log("Output URL: \(destinationURL)", logType: "LabelAutomation")
            Logger.log("Output App Name: \(processedAppResults.appDisplayName)", logType: "LabelAutomation")
            Logger.log("Output App Bundle ID: \(packageID)", logType: "LabelAutomation")
            Logger.log("Output App Version: \(String(describing: outputAppVersion))", logType: "LabelAutomation")
            
            let outputURL: URL? = destinationURL

            return (url: outputURL!, name: outputAppName!, bundleID: outputAppBundleID!, version: outputAppVersion!)
            
            // MARK: - processDownloadedFile pkgindmginzip
        case "pkgindmginzip":
            Logger.log("Type is pkgindmginzip", logType: "LabelAutomation")
            // Extract ZIP, mount DMG, find PKG file
            let extractedFolder = try await extractZipFile(zipURL: downloadURL)
            let dmgFiles = try findFiles(inFolder: extractedFolder, withExtension: "dmg")
            
            guard let dmgFile = dmgFiles.first else {
                throw NSError(domain: "ProcessingError", code: 104, userInfo: [NSLocalizedDescriptionKey: "No DMG file found in ZIP archive"])
            }
            
            let mountPoint = try await mountDMGFile(dmgURL: dmgFile)
//            defer { _ = try? unmountDMG(mountPoint: mountPoint) }
            
            let pkgFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "pkg")
            
            guard let pkgFile = pkgFiles.first else {
                throw NSError(domain: "ProcessingError", code: 105, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in mounted DMG (from ZIP)"])
            }
            
            // Check Signature
            let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: downloadURL, inpectionType: "pkg")
            
            Logger.log("  Inspect result: \(signatureResult)", logType: "LabelAutomation")
            
            if signatureResult == true {
                Logger.log("  Signature is valid.", logType: "LabelAutomation")
            } else {
                Logger.log("  Signature is invalid.", logType: "LabelAutomation")
                throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
            }
            
            // Get Version from download
            let pkgInspector = PkgInspector()
            let pkgURL = downloadURL
            let packageID = processedAppResults.appBundleIdExpected
            
            let downloadedVersion = await withCheckedContinuation { continuation in
                pkgInspector.getVersion(forPackageID: packageID, inPkgAt: pkgURL) { result in
                    switch result {
                    case .success(let version):
                        if let version = version {
                            Logger.log("  Version for package ID '\(packageID)': \(version)", logType: "LabelAutomation")
                            continuation.resume(returning: version)
                        } else {
                            Logger.log("  Package ID '\(packageID)' not found in the .pkg", logType: "LabelAutomation")
                            continuation.resume(returning: "None")
                        }
                    case .failure(let error):
                        Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: "LabelAutomation")
                        continuation.resume(returning: "None")
                    }
                }
            }
            
            // Create the final destination folder
            let finalDestinationFolder = downloadFolder
                .appendingPathComponent(downloadedVersion)
            
            try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)

            // set output filename
            outputFileName = "\(displayName)-\(downloadedVersion).pkg"
            
            //set output full path
            let destinationURL = finalDestinationFolder
                .appendingPathComponent(outputFileName ?? "Unknown.pkg")
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: downloadURL, to: destinationURL)
            
            Logger.log("📁 Copied file to: \(destinationURL.path)", logType: "LabelAutomation")

            
            Logger.log("Output URL: \(destinationURL)", logType: "LabelAutomation")
            Logger.log("Output App Name: \(processedAppResults.appDisplayName)", logType: "LabelAutomation")
            Logger.log("Output App Bundle ID: \(packageID)", logType: "LabelAutomation")
            Logger.log("Output App Version: \(String(describing: outputAppVersion))", logType: "LabelAutomation")
            
            let outputURL: URL? = destinationURL

            return (url: outputURL!, name: outputAppName!, bundleID: outputAppBundleID!, version: outputAppVersion!)
            
            // MARK: - processDownloadedFile zip
        case "zip":
            Logger.log("Type is zip", logType: "LabelAutomation")
            
            var downloadArray: [URL] = [downloadURL]
            if processedAppResults.appDeploymentArch == 2 && titleIsDualArch(forFolder: folderName){
                downloadArray += [downloadURLx86]
            }
            
            var appFile: URL!
            var appFileArray: [URL] = []
            
            var finalDestinationFolder: URL!
            
            for downloadURL in downloadArray {
                Logger.log("Processing Download URL: \(downloadURL)", logType: "LabelAutomation")
                
                
                // Extract ZIP, find and copy .app
                let extractedFolder = try await extractZipFileWithDitto(zipURL: downloadURL)
                let appFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
                
                guard let appFileFound = appFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "No .app file found in ZIP archive"])
                }
                
                appFile = appFileFound
                appFileArray.append(appFile)
                                
                // Check Signature
                let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: appFile, inpectionType: "app")
                
                Logger.log("  Inspect result: \(signatureResult)", logType: "LabelAutomation")
                
                if signatureResult == true {
                    Logger.log("  Signature is valid.", logType: "LabelAutomation")
                } else {
                    Logger.log("  Signature is invalid.", logType: "LabelAutomation")
                    throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
                }
                
                // Get Version from download
                let expectedBundleID = processedAppResults.appBundleIdExpected
                
                let inspector = AppInspector()
                let downloadedVersion = await withCheckedContinuation { continuation in
                    inspector.getVersion(forBundleID: expectedBundleID, inAppAt: appFile) { result in
                        switch result {
                        case .success(let version):
                            if let version = version {
                                Logger.log("  Version for package ID '\(expectedBundleID)': \(version)", logType: "LabelAutomation")
                                continuation.resume(returning: version)
                            } else {
                                Logger.log("  Package ID '\(expectedBundleID)' not found in the .pkg", logType: "LabelAutomation")
                                continuation.resume(returning: "None")
                            }
                        case .failure(let error):
                            Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: "LabelAutomation")
                            continuation.resume(returning: "None")
                        }
                    }
                }
                
                // Create the final destination folder
                finalDestinationFolder = downloadFolder
                    .appendingPathComponent(downloadedVersion)
                
                try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)

            }
                        
            if processedAppResults.appDeploymentType == 0 {
                // Create DMG for same app for Intune use
                let dmgCreator = DMGCreator()
                do {
                    let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = try dmgCreator.processToDMG(inputPath: appFile.path, outputDirectory: finalDestinationFolder.path)
                    Logger.log("Created DMG at \(String(describing: outputURLResult)) for \(outputAppNameResult) (\(outputAppBundleIDResult)) version \(outputAppVersionResult)", logType: "LabelAutomation")
                    
                    outputURL = URL(string: outputURLResult)
                    outputAppName = outputAppNameResult
                    outputAppBundleID = outputAppBundleIDResult
                    outputAppVersion = outputAppVersionResult
                } catch {
                    Logger.log("Failed to process DMG: \(error.localizedDescription)", logType: "LabelAutomation")
                    // Handle the error appropriately
                }
                
            } else {
                // Create PKG for same app for Intune use.
                if processedAppResults.appDeploymentArch == 2 && titleIsDualArch(forFolder: folderName){
                    Logger.log("Universal pkg creation", logType: "LabelAutomation")
                    let pkgCreator = PKGCreatorUniversal()
                    if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createUniversalPackage(inputPathArm64: appFileArray.first!.path, inputPathx86_64: appFileArray.last!.path, outputDir: finalDestinationFolder.path) {
                        Logger.log("  Package creation succeeded.", logType: "LabelAutomation")
                        outputURL = URL(string: outputURLResult)
                        outputAppName = outputAppNameResult
                        outputAppBundleID = outputAppBundleIDResult
                        outputAppVersion = outputAppVersionResult
                    }

                } else {
                    Logger.log("Standard single arch pkg creation", logType: "LabelAutomation")
                    let pkgCreator = PKGCreator()
                    if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createPackage(inputPath: appFile.path, outputDir: finalDestinationFolder.path) {
                        Logger.log("  Package creation succeeded.", logType: "LabelAutomation")
                        outputURL = URL(string: outputURLResult)
                        outputAppName = outputAppNameResult
                        outputAppBundleID = outputAppBundleIDResult
                        outputAppVersion = outputAppVersionResult
                    } else {
                        Logger.log("Package creation failed.", logType: "LabelAutomation")
                    }
                }
            }
            
            Logger.log("  Output URL: \(outputURL!)", logType: "LabelAutomation")
            Logger.log("  Output App Name: \(outputAppName!)", logType: "LabelAutomation")
            Logger.log("  Output App Bundle ID: \(outputAppBundleID!)", logType: "LabelAutomation")
            Logger.log("  Output App Version: \(outputAppVersion!)", logType: "LabelAutomation")
            
            return (url: outputURL!, name: outputAppName!, bundleID: outputAppBundleID!, version: outputAppVersion!)
            
            // MARK: - processDownloadedFile tbz
        case "tbz":
            Logger.log("Type is tbz", logType: "LabelAutomation")
            
            var downloadArray: [URL] = [downloadURL]
            if processedAppResults.appDeploymentArch == 2 && titleIsDualArch(forFolder: folderName){
                downloadArray += [downloadURLx86]
            }
            
            var appFile: URL!
            var appFileArray: [URL] = []
            
            var finalDestinationFolder: URL!

            
            for downloadURL in downloadArray {
                Logger.log("Processing Download URL: \(downloadURL)", logType: "LabelAutomation")
                
                
                // Extract TBZ, find and copy .app
                let extractedFolder = try await extractTBZFile(tbzURL: downloadURL)
                let appFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
                
                guard let appFileFound = appFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 107, userInfo: [NSLocalizedDescriptionKey: "No .app file found in TBZ archive"])
                }
                
                appFile = appFileFound
                appFileArray.append(appFile)
                                
                // Check Signature
                let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: appFile, inpectionType: "app")
                
                Logger.log("  Inspect result: \(signatureResult)", logType: "LabelAutomation")
                
                if signatureResult == true {
                    Logger.log("  Signature is valid.", logType: "LabelAutomation")
                } else {
                    Logger.log("  Signature is invalid.", logType: "LabelAutomation")
                    throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
                }
                
                // Get Version from download
                let expectedBundleID = processedAppResults.appBundleIdExpected
                
                let inspector = AppInspector()
                let downloadedVersion = await withCheckedContinuation { continuation in
                    inspector.getVersion(forBundleID: expectedBundleID, inAppAt: appFile) { result in
                        switch result {
                        case .success(let version):
                            if let version = version {
                                Logger.log("  Version for package ID '\(expectedBundleID)': \(version)", logType: "LabelAutomation")
                                continuation.resume(returning: version)
                            } else {
                                Logger.log("  Package ID '\(expectedBundleID)' not found in the .pkg", logType: "LabelAutomation")
                                continuation.resume(returning: "None")
                            }
                        case .failure(let error):
                            Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: "LabelAutomation")
                            continuation.resume(returning: "None")
                        }
                    }
                }
                
                // Create the final destination folder
                finalDestinationFolder = downloadFolder
                    .appendingPathComponent(downloadedVersion)
                
                try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)

            }
            
            if processedAppResults.appDeploymentType == 0 {
                // Create DMG for same app for Intune use
                let dmgCreator = DMGCreator()
                do {
                    let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = try dmgCreator.processToDMG(inputPath: appFile.path, outputDirectory: finalDestinationFolder.path)
                    Logger.log("Created DMG at \(String(describing: outputURLResult)) for \(outputAppNameResult) (\(outputAppBundleIDResult)) version \(outputAppVersionResult)", logType: "LabelAutomation")
                    
                    outputURL = URL(string: outputURLResult)
                    outputAppName = outputAppNameResult
                    outputAppBundleID = outputAppBundleIDResult
                    outputAppVersion = outputAppVersionResult
                } catch {
                    Logger.log("Failed to process DMG: \(error.localizedDescription)", logType: "LabelAutomation")
                    // Handle the error appropriately
                }
                
            } else {
                // Create PKG for same app for Intune use.
                if processedAppResults.appDeploymentArch == 2 && titleIsDualArch(forFolder: folderName){
                    Logger.log("Universal pkg creation", logType: "LabelAutomation")
                    let pkgCreator = PKGCreatorUniversal()
                    if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createUniversalPackage(inputPathArm64: appFile.path, inputPathx86_64: downloadURLx86.path, outputDir: finalDestinationFolder.path) {
                        Logger.log("  Package creation succeeded.", logType: "LabelAutomation")
                        outputURL = URL(string: outputURLResult)
                        outputAppName = outputAppNameResult
                        outputAppBundleID = outputAppBundleIDResult
                        outputAppVersion = outputAppVersionResult
                    }

                } else {
                    // Create PKG for same app for Intune use.
                    let pkgCreator = PKGCreator()
                    if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createPackage(inputPath: appFile.path, outputDir: finalDestinationFolder.path) {
                        Logger.log("  Package creation succeeded.", logType: "LabelAutomation")
                        outputURL = URL(string: outputURLResult)
                        outputAppName = outputAppNameResult
                        outputAppBundleID = outputAppBundleIDResult
                        outputAppVersion = outputAppVersionResult
                    } else {
                        Logger.log("Package creation failed.", logType: "LabelAutomation")
                    }
                }
            }
            
            Logger.log("  Output URL: \(outputURL!)", logType: "LabelAutomation")
            Logger.log("  Output App Name: \(outputAppName!)", logType: "LabelAutomation")
            Logger.log("  Output App Bundle ID: \(outputAppBundleID!)", logType: "LabelAutomation")
            Logger.log("  Output App Version: \(outputAppVersion!)", logType: "LabelAutomation")
            
            return (url: outputURL!, name: outputAppName!, bundleID: outputAppBundleID!, version: outputAppVersion!)
            
            
            //            return (url: resultURL, version: downloadedVersion)
            
            // MARK: - processDownloadedFile dmg
        case "dmg":
            Logger.log("  Type is dmg", logType: "LabelAutomation")
            
            var downloadArray: [URL] = [downloadURL]
            if processedAppResults.appDeploymentArch == 2 && titleIsDualArch(forFolder: folderName){
                downloadArray += [downloadURLx86]
            }
            
            var appFile: URL!
            var appFileArray: [URL] = []
            
            var finalDestinationFolder: URL!


            for downloadURL in downloadArray {
                Logger.log("Processing Download URL: \(downloadURL)", logType: "LabelAutomation")
                
                // Mount DMG, find and copy .app
                let mountPoint = try await mountDMGFile(dmgURL: downloadURL)
                defer { _ = try? unmountDMG(mountPoint: mountPoint) }
                
                let appFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
                
                guard let appFileFound = appFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 108, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG"])
                }
                
                appFile = appFileFound
                appFileArray.append(appFile)

                // Check Signature
                let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: appFile, inpectionType: "app")
                
                Logger.log("  Inspect result: \(signatureResult)", logType: "LabelAutomation")
                
                if signatureResult == true {
                    Logger.log("  Signature is valid.", logType: "LabelAutomation")
                } else {
                    Logger.log("  Signature is invalid.", logType: "LabelAutomation")
                    throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
                }
                
                // Get Version from download
                let expectedBundleID = processedAppResults.appBundleIdExpected
                
                let inspector = AppInspector()
                let downloadedVersion = await withCheckedContinuation { continuation in
                    inspector.getVersion(forBundleID: expectedBundleID, inAppAt: appFile) { result in
                        switch result {
                        case .success(let version):
                            if let version = version {
                                Logger.log("  Version for package ID '\(expectedBundleID)': \(version)", logType: "LabelAutomation")
                                continuation.resume(returning: version)
                            } else {
                                Logger.log("  Package ID '\(expectedBundleID)' not found in the .pkg", logType: "LabelAutomation")
                                continuation.resume(returning: "None")
                            }
                        case .failure(let error):
                            Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: "LabelAutomation")
                            continuation.resume(returning: "None")
                        }
                    }
                }
                
                // Create the final destination folder
                finalDestinationFolder = downloadFolder
                    .appendingPathComponent(downloadedVersion)
                
                try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)

            }
            
            if processedAppResults.appDeploymentType == 0 {
                // Create DMG for same app for Intune use
                let dmgCreator = DMGCreator()
                do {
                    let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = try dmgCreator.processToDMG(inputPath: appFile.path, outputDirectory: finalDestinationFolder.path)
                    Logger.log("Created DMG at \(String(describing: outputURLResult)) for \(outputAppNameResult) (\(outputAppBundleIDResult)) version \(outputAppVersionResult)", logType: "LabelAutomation")
                    
                    outputURL = URL(string: outputURLResult)
                    outputAppName = outputAppNameResult
                    outputAppBundleID = outputAppBundleIDResult
                    outputAppVersion = outputAppVersionResult
                } catch {
                    Logger.log("Failed to process DMG: \(error.localizedDescription)", logType: "LabelAutomation")
                    // Handle the error appropriately
                }
            } else {
                if processedAppResults.appDeploymentArch == 2 && titleIsDualArch(forFolder: folderName){
                    Logger.log("Universal pkg creation", logType: "LabelAutomation")
                    Logger.log("  Arm64 DMG located here: \(downloadURL.absoluteString)", logType: "LabelAutomation")
                    Logger.log("  x86_64 DMG located here: \(downloadURLx86.absoluteString)", logType: "LabelAutomation")

                    
                    // Mount ARM64 DMG, find and copy .app
                    let mountPointArm = try await mountDMGFile(dmgURL: downloadURL)
                    
                    defer { _ = try? unmountDMG(mountPoint: mountPointArm) }
                    
                    let appFilesArm = try findFiles(inFolder: URL(fileURLWithPath: mountPointArm), withExtension: "app")
                    
                    guard let appFileFoundArm = appFilesArm.first else {
                        throw NSError(domain: "ProcessingError", code: 108, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG"])
                    }

                    // Mount x86_64 DMG, find and copy .app
                    let mountPointx86 = try await mountDMGFile(dmgURL: downloadURLx86)
                    
                    defer { _ = try? unmountDMG(mountPoint: mountPointx86) }
                    
                    let appFilesx86 = try findFiles(inFolder: URL(fileURLWithPath: mountPointArm), withExtension: "app")
                    
                    guard let appFileFoundx86 = appFilesx86.first else {
                        throw NSError(domain: "ProcessingError", code: 108, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG"])
                    }

                    
                    let pkgCreator = PKGCreatorUniversal()
                    if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createUniversalPackage(inputPathArm64: appFileFoundArm.path, inputPathx86_64: appFileFoundx86.path, outputDir: finalDestinationFolder.path) {
                        Logger.log("  Package creation succeeded.", logType: "LabelAutomation")
                        outputURL = URL(string: outputURLResult)
                        outputAppName = outputAppNameResult
                        outputAppBundleID = outputAppBundleIDResult
                        outputAppVersion = outputAppVersionResult
                    }

                } else {
                    
                    // Create PKG for same app for Intune use.
                    
                    // Mount DMG, find and copy .app
                    let mountPoint = try await mountDMGFile(dmgURL: downloadURL)
                    
                    defer { _ = try? unmountDMG(mountPoint: mountPoint) }
                    
                    let appFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
                    
                    guard let appFileFound = appFiles.first else {
                        throw NSError(domain: "ProcessingError", code: 108, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG"])
                    }
                    
                    let pkgCreator = PKGCreator()
                    if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createPackage(inputPath: appFileFound.path, outputDir: finalDestinationFolder.path) {
                        Logger.log("  Package creation succeeded.", logType: "LabelAutomation")
                        outputURL = URL(string: outputURLResult)
                        outputAppName = outputAppNameResult
                        outputAppBundleID = outputAppBundleIDResult
                        outputAppVersion = outputAppVersionResult
                    } else {
                        Logger.log("Package creation failed.", logType: "LabelAutomation")
                    }
                }
            }
            
            Logger.log("  Output URL: \(outputURL!)", logType: "LabelAutomation")
            Logger.log("  Output App Name: \(outputAppName!)", logType: "LabelAutomation")
            Logger.log("  Output App Bundle ID: \(outputAppBundleID!)", logType: "LabelAutomation")
            Logger.log("  Output App Version: \(outputAppVersion!)", logType: "LabelAutomation")
            
            return (url: outputURL!, name: outputAppName!, bundleID: outputAppBundleID!, version: outputAppVersion!)
            
            // MARK: - processDownloadedFile appindmginzip
        case "appindmginzip":
            Logger.log("Type is appindmginzip", logType: "LabelAutomation")
            
            var downloadArray: [URL] = [downloadURL]
            if processedAppResults.appDeploymentArch == 2 && titleIsDualArch(forFolder: folderName){
                downloadArray += [downloadURLx86]
            }
            
            var appFile: URL!
            var appFileArray: [URL] = []
            
            var finalDestinationFolder: URL!


            for downloadURL in downloadArray {
                Logger.log("Processing Download URL: \(downloadURL)", logType: "LabelAutomation")
                
                // Extract ZIP, mount DMG, find and copy .app
                let extractedFolder = try await extractZipFile(zipURL: downloadURL)
                let dmgFiles = try findFiles(inFolder: extractedFolder, withExtension: "dmg")
                
                guard let dmgFile = dmgFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 109, userInfo: [NSLocalizedDescriptionKey: "No DMG file found in ZIP archive"])
                }
                
                let mountPoint = try await mountDMGFile(dmgURL: dmgFile)
                defer { _ = try? unmountDMG(mountPoint: mountPoint) }
                let appFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
                
                guard let appFileFound = appFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 110, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG (from ZIP)"])
                }
                
                appFile = appFileFound
                appFileArray.append(appFile)

                // Check Signature
                let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: appFile, inpectionType: "app")
                
                Logger.log("  Inspect result: \(signatureResult)", logType: "LabelAutomation")
                
                if signatureResult == true {
                    Logger.log("  Signature is valid.", logType: "LabelAutomation")
                } else {
                    Logger.log("  Signature is invalid.", logType: "LabelAutomation")
                    throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
                }
                
                // Get Version from download
                let expectedBundleID = processedAppResults.appBundleIdExpected
                
                let inspector = AppInspector()
                let downloadedVersion = await withCheckedContinuation { continuation in
                    inspector.getVersion(forBundleID: expectedBundleID, inAppAt: appFile) { result in
                        switch result {
                        case .success(let version):
                            if let version = version {
                                Logger.log("  Version for package ID '\(expectedBundleID)': \(version)", logType: "LabelAutomation")
                                continuation.resume(returning: version)
                            } else {
                                Logger.log("  Package ID '\(expectedBundleID)' not found in the .pkg", logType: "LabelAutomation")
                                continuation.resume(returning: "None")
                            }
                        case .failure(let error):
                            Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: "LabelAutomation")
                            continuation.resume(returning: "None")
                        }
                    }
                }
                
                // Create the final destination folder
                finalDestinationFolder = downloadFolder
                    .appendingPathComponent(downloadedVersion)
                
                try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)

            }
            
            if processedAppResults.appDeploymentType == 0 {
                // Create DMG for same app for Intune use
                let dmgCreator = DMGCreator()
                do {
                    let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = try dmgCreator.processToDMG(inputPath: appFile.path, outputDirectory: finalDestinationFolder.path)
                    Logger.log("Created DMG at \(String(describing: outputURLResult)) for \(outputAppNameResult) (\(outputAppBundleIDResult)) version \(outputAppVersionResult)", logType: "LabelAutomation")
                    
                    outputURL = URL(string: outputURLResult)
                    outputAppName = outputAppNameResult
                    outputAppBundleID = outputAppBundleIDResult
                    outputAppVersion = outputAppVersionResult
                } catch {
                    Logger.log("Failed to process DMG: \(error.localizedDescription)", logType: "LabelAutomation")
                    // Handle the error appropriately
                }
            } else {
                if processedAppResults.appDeploymentArch == 2 && titleIsDualArch(forFolder: folderName){
                    Logger.log("Universal pkg creation", logType: "LabelAutomation")
                    let pkgCreator = PKGCreatorUniversal()
                    if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createUniversalPackage(inputPathArm64: appFile.path, inputPathx86_64: downloadURLx86.path, outputDir: finalDestinationFolder.path) {
                        Logger.log("  Package creation succeeded.", logType: "LabelAutomation")
                        outputURL = URL(string: outputURLResult)
                        outputAppName = outputAppNameResult
                        outputAppBundleID = outputAppBundleIDResult
                        outputAppVersion = outputAppVersionResult
                    }

                } else {
                    
                    // Create PKG for same app for Intune use.
                    let pkgCreator = PKGCreator()
                    if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createPackage(inputPath: appFile.path, outputDir: finalDestinationFolder.path) {
                        Logger.log("  Package creation succeeded.", logType: "LabelAutomation")
                        outputURL = URL(string: outputURLResult)
                        outputAppName = outputAppNameResult
                        outputAppBundleID = outputAppBundleIDResult
                        outputAppVersion = outputAppVersionResult
                    } else {
                        Logger.log("Package creation failed.", logType: "LabelAutomation")
                    }
                }
            }
            
            Logger.log("  Output URL: \(outputURL!)", logType: "LabelAutomation")
            Logger.log("  Output App Name: \(outputAppName!)", logType: "LabelAutomation")
            Logger.log("  Output App Bundle ID: \(outputAppBundleID!)", logType: "LabelAutomation")
            Logger.log("  Output App Version: \(outputAppVersion!)", logType: "LabelAutomation")
            
            return (url: outputURL!, name: outputAppName!, bundleID: outputAppBundleID!, version: outputAppVersion!)
            
        default:
            throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type: \(downloadType)"])
        }
    }
    
    
    
    // MARK: - Helper Functions for download processing
    
    private static func copyToFinalDestination(sourceURL: URL, destinationFolder: URL, keepOriginalName: Bool) throws -> URL {
        
        let fileName = keepOriginalName ? sourceURL.lastPathComponent : UUID().uuidString + "." + sourceURL.pathExtension
        let destinationURL = destinationFolder.appendingPathComponent(fileName)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // Copy the file
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        Logger.log("📁 Copied file to: \(destinationURL.path)", logType: "LabelAutomation")
        return destinationURL
    }
    
    private static func extractZipFile(zipURL: URL) async throws -> URL {
        Logger.log("Extracting ZIP file: \(zipURL.lastPathComponent)", logType: "LabelAutomation")
        
        let extractFolder = zipURL.deletingLastPathComponent()
        
        try FileManager.default.createDirectory(at: extractFolder, withIntermediateDirectories: true)
        
        Logger.log("📦 Extracting ZIP file: \(zipURL.lastPathComponent)", logType: "LabelAutomation")
        
        // Use Process to run unzip command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipURL.path, "-d", extractFolder.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ExtractionError", code: 201, userInfo: [NSLocalizedDescriptionKey: "Failed to extract ZIP file"])
        }
        
        Logger.log("✅ ZIP extraction complete", logType: "LabelAutomation")
        Logger.log("Extracted folder: \(extractFolder.path)", logType: "LabelAutomation")
        return extractFolder
    }
    
    private static func extractZipFileWithDitto(zipURL: URL) async throws -> URL {
        Logger.log("Extracting ZIP file: \(zipURL.lastPathComponent)", logType: "LabelAutomation")
        
        let extractFolder = zipURL.deletingLastPathComponent()
        
        try FileManager.default.createDirectory(at: extractFolder, withIntermediateDirectories: true)
        
        Logger.log("📦 Extracting ZIP file: \(zipURL.lastPathComponent)", logType: "LabelAutomation")
        
        // Use Process to run unzip command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, extractFolder.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ExtractionError", code: 201, userInfo: [NSLocalizedDescriptionKey: "Failed to extract ZIP file"])
        }
        
        Logger.log("✅ ZIP extraction complete", logType: "LabelAutomation")
        Logger.log("Extracted folder: \(extractFolder.path)", logType: "LabelAutomation")
        return extractFolder
    }
    
    
    private static func extractTBZFile(tbzURL: URL) async throws -> URL {
        Logger.log("Extracting TBZ file: \(tbzURL.lastPathComponent)", logType: "LabelAutomation")
        
        let extractFolder = tbzURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: extractFolder, withIntermediateDirectories: true)
        
        // Use Process to run tar command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xf", tbzURL.path, "-C", extractFolder.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ExtractionError", code: 202, userInfo: [NSLocalizedDescriptionKey: "Failed to extract TBZ file"])
        }
        
        Logger.log("✅ TBZ extraction complete", logType: "LabelAutomation")
        return extractFolder
    }
    
    private static func mountDMGFile(dmgURL: URL) async throws -> String {
        Logger.log("  Mounting DMG file: \(dmgURL.lastPathComponent)", logType: "LabelAutomation")
        
        let tempDir = dmgURL.deletingLastPathComponent()

        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            
            // Convert the DMG first if it has a Software License Agreement
            if dmgHasSLA(at: dmgURL.path) {
                let success = await convertDmgWithSLA(at: dmgURL.path)
                if success {
                    Logger.logUser("Successfully converted dmg with SLA", logType: "EditViewController")
                } else {
                    Logger.logUser("Failed to convert dmg with SLA", logType: "EditViewController")
                    throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert dmg containing pkg"])
                }
            }
        }

        sleep(UInt32(0.5))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", dmgURL.path, "-nobrowse", "-plist"]
                
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        let errorPipe = Pipe()
        process.standardError = errorPipe
            
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
            Logger.log("Error: Failed to mount .dmg file. \(errorOutput)", logType: "LabelAutomation")
            throw NSError(domain: "MountError", code: 301, userInfo: [NSLocalizedDescriptionKey: "Failed to mount DMG file: \(errorOutput)"])
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        
        guard let plist = try PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else {
            throw NSError(domain: "MountError", code: 302, userInfo: [NSLocalizedDescriptionKey: "Failed to parse mount output"])
        }
        
        for entity in entities {
            if let mountPoint = entity["mount-point"] as? String {
                Logger.log("  DMG mounted at: \(mountPoint)", logType: "LabelAutomation")
                return mountPoint
            }
        }
        
        throw NSError(domain: "MountError", code: 303, userInfo: [NSLocalizedDescriptionKey: "No mount point found in DMG output"])
    }
    
    private static func dmgHasSLA(at path: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/hdiutil"
        process.arguments = ["imageinfo", path, "-plist"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            Logger.log("Error: Failed to check for SLA in DMG.", logType: "LabelAutomation")
            return false
        }
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
              let properties = plist["Properties"] as? [String: Any],
              let hasSLA = properties["Software License Agreement"] as? Bool else {
            return false
        }
        
        return hasSLA
    }
    
    
    private static func convertDmgWithSLA(at path: String) async -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent(fileName)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["convert", "-format", "UDRW", "-o", tempFileURL.path, path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            Logger.logUser("Error: Could not launch hdiutil: \(error)", logType: "LabelAutomation")
            return false
        }

        // Wait asynchronously for the process to finish
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        guard process.terminationStatus == 0 else {
            Logger.logUser("Error: hdiutil failed to convert DMG with SLA.", logType: "LabelAutomation")
            return false
        }

        guard FileManager.default.fileExists(atPath: tempFileURL.path) else {
            Logger.logUser("Error: Converted file not found at expected location.", logType: "LabelAutomation")
            return false
        }

        do {
            try FileManager.default.removeItem(atPath: path)
            try FileManager.default.moveItem(atPath: tempFileURL.path, toPath: path)
        } catch {
            Logger.logUser("Failed to finalize converted DMG: \(error)", logType: "LabelAutomation")
            return false
        }

        return true
    }

    
    private static func unmountDMG(mountPoint: String) throws {
        Logger.log("  Unmounting DMG: \(mountPoint)", logType: "LabelAutomation")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint, "-force"]
        
        // Redirect stdout to /dev/null but capture stderr
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            Logger.log("  DMG unmounted successfully", logType: "LabelAutomation")
        } else {
            // Capture error output for logging
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            Logger.log("  Failed to unmount DMG: \(errorMessage)", logType: "LabelAutomation")
        }
    }
    
    
    private static func findFiles(inFolder folderURL: URL, withExtension ext: String) throws -> [URL] {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        
        var foundFiles = [URL]()
        
        while let fileURL = enumerator?.nextObject() as? URL {
            // Special case for .app bundles which are directories
            if ext.lowercased() == "app" {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true && fileURL.pathExtension.lowercased() == "app" {
                    foundFiles.append(fileURL)
                }
            } else {
                // Normal files
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == false && fileURL.pathExtension.lowercased() == ext.lowercased() {
                    foundFiles.append(fileURL)
                }
            }
        }
        
        Logger.log("  Found \(foundFiles.count) files with extension .\(ext) in \(folderURL.path)", logType: "LabelAutomation")
        for file in foundFiles {
            Logger.log("   - \(file.lastPathComponent)", logType: "LabelAutomation")
        }
        
        // Sort by shortest full path length
        foundFiles.sort { $0.path.count < $1.path.count }

        return foundFiles
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
    
    /*
     let appURL = URL(fileURLWithPath: "/Applications/Pages.app")
     do {
         let arch = try getAppArchitecture(at: appURL)
         print("Architecture is \(arch.rawValue)")
     } catch {
         print("Error determining architecture: \(error)")
     }
     
     */
    
    
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
    
    /*
     let appURLs = [
         URL(fileURLWithPath: "/path/to/Arm64OnlyApp.app"),
         URL(fileURLWithPath: "/path/to/X86OnlyApp.app")
     ]
     let expectedArchitectures: [AppArchitecture] = [.arm64, .x86_64]

     do {
         try validateAppArchitectures(urls: appURLs, expected: expectedArchitectures)
         // all good — proceed with your next steps
         print("✅ All architectures match!")
     } catch {
         // mismatch — handle or surface the error
         print("❌ \(error)")
     }
     
     */
    
    
    // MARK: - Inspection of download
    static func inspectSignatureOfDownloadedSoftware(for processedAppResults: ProcessedAppResults, downloadURL: URL, inpectionType: String) -> Bool {
        
        Logger.log("Inspecting \(inpectionType) signature...", logType: "LabelAutomation")
        
        switch inpectionType {
        case "pkg":
            
            // Inspect pkg
            var inspectionResult = [String: Any]()
            
            do {
                let pkgPath = downloadURL.path
                inspectionResult = try SignatureInspector.inspectPackageSignature(pkgPath: pkgPath)
                Logger.log("Package Signature Inspection Result: \(inspectionResult)", logType: "LabelAutomation")
                if let accepted = inspectionResult["Accepted"] as? Bool, accepted {
                    Logger.log("  Inspection Passed", logType: "LabelAutomation")
                } else {
                    Logger.log("  Inspection Failed", logType: "LabelAutomation")
                    throw NSError(domain: "LabelAutomation", code: 1001, userInfo: [NSLocalizedDescriptionKey : "Package signature inspection failed"])
                }
                
                if let teamID = inspectionResult["DeveloperTeam"] as? String {
                    Logger.log("  Download Team ID: \(teamID)", logType: "LabelAutomation")
                    Logger.log("  Expected Team ID: \(processedAppResults.appTeamID)", logType: "LabelAutomation")
                    if teamID != processedAppResults.appTeamID {
                        Logger.log("  Team ID mismatch! Expected: \(processedAppResults.appTeamID), Actual: \(teamID)", logType: "LabelAutomation")
                        throw NSError(domain: "LabelAutomation", code: 1003, userInfo: [NSLocalizedDescriptionKey : "Team ID mismatch"])
                    } else {
                        Logger.log("  Team ID matches", logType: "LabelAutomation")
                    }
                }
            } catch {
                Logger.log("Error inspecting package: \(error)", logType: "LabelAutomation")
                return false
            }
            
        case "app":
            // Inspect app
            var inspectionResult = [String: Any]()
            
            do {
                let appPath = downloadURL.path
                inspectionResult = try SignatureInspector.inspectAppSignature(appPath: appPath)
                Logger.log("  Application Signature Inspection Result: \(inspectionResult)", logType: "LabelAutomation")
                if let accepted = inspectionResult["Accepted"] as? Bool, accepted {
                    Logger.log("  Inspection Passed", logType: "LabelAutomation")
                } else {
                    Logger.log("  Inspection Failed", logType: "LabelAutomation")
                    throw NSError(domain: "LabelAutomation", code: 1001, userInfo: [NSLocalizedDescriptionKey : "Package signature inspection failed"])
                }
                
                if let teamID = inspectionResult["DeveloperTeam"] as? String {
                    Logger.log("  Download Team ID: \(teamID)", logType: "LabelAutomation")
                    Logger.log("  Expected Team ID: \(processedAppResults.appTeamID)", logType: "LabelAutomation")
                    if teamID != processedAppResults.appTeamID {
                        Logger.log("  Team ID mismatch! Expected: \(processedAppResults.appTeamID), Actual: \(teamID)", logType: "LabelAutomation")
                        throw NSError(domain: "LabelAutomation", code: 1003, userInfo: [NSLocalizedDescriptionKey : "Team ID mismatch"])
                    } else {
                        Logger.log("  Team ID matches", logType: "LabelAutomation")
                    }
                }
            } catch {
                Logger.log("Error inspecting package: \(error)", logType: "LabelAutomation")
                return false
            }
            
        default:
            Logger.log("Unsupported file type: \(inpectionType)", logType: "LabelAutomation")
            return false
            
        }
        return true
    }
    
    
    
    // MARK: - OLD CODE
    // Download function
    static func downloadSoftware(for plistData: PlistData, folderName: String, completion: @escaping (DownloadedFile?) -> Void) {
        
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL.appendingPathComponent(folderName)
        let finalDownloadFolder = downloadFolder.appendingPathComponent(plistData.appNewVersion ?? "Unknown")
        
        let expectedFilePath = finalDownloadFolder.appendingPathComponent("\(plistData.name) \(plistData.appNewVersion ?? "latest").pkg")
        
        // ✅ Check if file already exists in cache
        Logger.log("📦 Checking for cached version of \(plistData.name)", logType: "LabelAutomation")
        
        if FileManager.default.fileExists(atPath: expectedFilePath.path) {
            Logger.log("✅ Cached version \(plistData.appNewVersion ?? "Unknown") found. Skipping download.", logType: "LabelAutomation")
            completion(nil)  // ✅ Ensure completion is called
            return
        }
        
        // ✅ Create a temp working folder for the download
        Logger.log("📂 Create a temp working folder for the download of \(plistData.name)", logType: "LabelAutomation")
        let tempDownloadFolder = downloadFolder.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: tempDownloadFolder, withIntermediateDirectories: true)
            Logger.log("📂 Temp folder created successfully.", logType: "LabelAutomation")
            
        } catch {
            Logger.log("❌ Failed to create temp folder: \(error.localizedDescription)", logType: "LabelAutomation")
            completion(nil)  // ✅ Ensure completion is called on error
            return
        }
        
        let fileDestination = tempDownloadFolder.appendingPathComponent("\(plistData.name) \(plistData.appNewVersion ?? "latest").pkg")
        
        Logger.log("🌐 Proceeding with download for \(folderName)", logType: "LabelAutomation")
        
        
        downloadFile(from: plistData.downloadURL, to: fileDestination) { success, fileSize in
            if success {
                Logger.log("✅ Successfully downloaded \(plistData.name) to \(fileDestination.path) (\(fileSize) bytes)", logType: "LabelAutomation")
                
                // Move validated downloads to the final folder
                do {
                    try FileManager.default.createDirectory(at: finalDownloadFolder, withIntermediateDirectories: true)
                    let finalPath = finalDownloadFolder.appendingPathComponent("\(plistData.name) \(plistData.appNewVersion ?? "latest").pkg")
                    try FileManager.default.moveItem(at: fileDestination, to: finalPath)
                    
                    completion(DownloadedFile(filePath: finalPath.path, fileName: finalPath.lastPathComponent, fileSize: fileSize))
                } catch {
                    Logger.log("❌ Failed to move file to final location: \(error.localizedDescription)", logType: "LabelAutomation")
                    completion(nil)  // ✅ Ensure completion is called on error
                }
            } else {
                Logger.log("❌ Failed to download \(plistData.name)", logType: "LabelAutomation")
                completion(nil)  // ✅ Ensure completion is called on error
            }
        }
        
    }
    
    
    static func downloadFile(from urlString: String, to destinationURL: URL, completion: @escaping (Bool, Int64) -> Void) {
        
        Logger.log("Starting download of file from: \(urlString)", logType: "LabelAutomation")
        
        guard let url = URL(string: urlString) else {
            Logger.log("❌ Invalid download URL: \(urlString)", logType: "LabelAutomation")
            completion(false, 0)
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                Logger.log("❌ Download failed: \(error.localizedDescription)", logType: "LabelAutomation")
                completion(false, 0)
                return
            }
            
            guard let tempURL = tempURL, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                Logger.log("❌ Invalid response or status code", logType: "LabelAutomation")
                completion(false, 0)
                return
            }
            
            do {
                // Move the downloaded file to the destination
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                
                // Get file size
                let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                Logger.log("✅ File downloaded: \(destinationURL.path) (\(fileSize) bytes)", logType: "LabelAutomation")
                completion(true, fileSize)
            } catch {
                Logger.log("❌ Failed to move downloaded file: \(error.localizedDescription)", logType: "LabelAutomation")
                completion(false, 0)
            }
        }
        
        task.resume()
    }
    
    // Actual download implementation
    static func proceedWithDownload(plistData: PlistData, completion: @escaping (DownloadedFile?) -> Void) {
        Logger.log("🌐 Starting download for \(plistData.name) from \(plistData.downloadURL)", logType: "LabelAutomation")
        
        // Create working directory: AppConstants.intuneomatorCacheFolderURL/labelname/UUID/
        let uuid = UUID().uuidString
        let workingPath = (AppConstants.intuneomatorCacheFolderURL.path as NSString)
            .appendingPathComponent("\(plistData.name)/\(uuid)/")
        
        try? FileManager.default.createDirectory(atPath: workingPath, withIntermediateDirectories: true)
        
        guard let url = URL(string: plistData.downloadURL) else {
            Logger.log("❌ Invalid download URL: \(plistData.downloadURL)", logType: "LabelAutomation")
            completion(nil)
            return
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        let session = URLSession.shared
        var downloadedFile: DownloadedFile?
        
        let task = session.downloadTask(with: url) { tempURL, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                Logger.log("❌ Download failed for \(plistData.name): \(error.localizedDescription)", logType: "LabelAutomation")
                return
            }
            
            guard let tempURL = tempURL, let httpResponse = response as? HTTPURLResponse,
                  let suggestedFilename = httpResponse.suggestedFilename else {
                Logger.log("❌ No file received for \(plistData.name)", logType: "LabelAutomation")
                return
            }
            
            do {
                let destinationPath = (workingPath as NSString).appendingPathComponent(suggestedFilename)
                let fileManager = FileManager.default
                
                if fileManager.fileExists(atPath: destinationPath) {
                    try fileManager.removeItem(atPath: destinationPath) // Remove old file if exists
                }
                
                try fileManager.moveItem(at: tempURL, to: URL(fileURLWithPath: destinationPath))
                
                let fileSize = try fileManager.attributesOfItem(atPath: destinationPath)[.size] as? Int64 ?? 0
                downloadedFile = DownloadedFile(filePath: destinationPath, fileName: suggestedFilename, fileSize: fileSize)
                
                Logger.log("✅ Successfully downloaded \(plistData.name) to \(destinationPath) (\(fileSize) bytes)", logType: "LabelAutomation")
            } catch {
                Logger.log("❌ Failed to move downloaded file for \(plistData.name): \(error.localizedDescription)", logType: "LabelAutomation")
            }
        }
        
        task.resume()
        semaphore.wait() // Wait until the download completes
        
        completion(downloadedFile)
    }
    
    
    // Placeholder: Extract version from a downloaded package
    static func extractVersion(from filePath: String) -> String? {
        // Placeholder implementation: Call existing Swift class to extract version
        return "135.0.1" // Replace this with real version extraction logic
    }
    
    // MARK: - UPDATE ASSIGNMENTS ONLY FOR FOLDER
    static func processFolderAssignments(named folderName: String) async {
        // Variables to track label processing
        var processedAppResults: ProcessedAppResults?

        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo]

        Logger.log("--------------------------------------------------------", logType: "Automation")
        Logger.log("🚀 Start assignment update of \(folderName)", logType: "Automation")
        Logger.log("Start assignment update of: \(folderName)", logType: "LabelAutomation")

        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: "LabelAutomation")
            return
        }
                
        // Get the Processed App Results starter for this folder
        processedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults?.appDisplayName ?? "Unknown")", logType: "LabelAutomation")
        
        Logger.log("  Label: \(String(describing: processedAppResults?.appLabelName))", logType: "LabelAutomation")
        
        guard let trackingID = processedAppResults?.appTrackingID else {
            Logger.log("Tracking ID is missing", logType: "LabelAutomation")
            return
        }
        Logger.log("  Tracking ID: \(trackingID)", logType: "LabelAutomation")


        // MARK: - Check Intune for any versions
        
        // Check Intune for an existing versions
        Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: "LabelAutomation")
        
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.log("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: "Automation")
            
            for app in appInfo {
                Logger.log("    ---", logType: "Automation")
                Logger.log("    App: \(app.displayName)", logType: "Automation")
                Logger.log("    Ver: \(app.primaryBundleVersion)", logType: "Automation")
                Logger.log("     ID: \(app.id)", logType: "Automation")
                
                
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
                        Logger.log("Error updating \(processedAppResults?.appDisplayName ?? "unknown") with AppID \(app.id) assignment in Intune: \(error.localizedDescription)", logType: "LabelAutomation")
                    }
                }
            }
            
        } catch {
            Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: "LabelAutomation")
            return
        }
    }

    
    // MARK: - UPDATE METADATA ONLY FOR FOLDER
    static func processFolderMetadata(named folderName: String) async {
        // Variables to track label processing
        var processedAppResults: ProcessedAppResults?

        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo]

        Logger.log("--------------------------------------------------------", logType: "Automation")
        Logger.log("🚀 Start metadata update of \(folderName)", logType: "Automation")
        Logger.log("Start metadata update of: \(folderName)", logType: "LabelAutomation")

        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: "LabelAutomation")
            return
        }
                
        // Get the Processed App Results starter for this folder
        processedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults?.appDisplayName ?? "Unknown")", logType: "LabelAutomation")
        
        Logger.log("  Label: \(String(describing: processedAppResults?.appLabelName))", logType: "LabelAutomation")
        Logger.log("  Tracking ID: \(String(describing: processedAppResults?.appTrackingID))", logType: "LabelAutomation")
        Logger.log("  Version to check: \(String(describing: processedAppResults?.appVersionExpected))", logType: "LabelAutomation")
        
        guard let trackingID = processedAppResults?.appTrackingID else {
            Logger.log("Tracking ID is missing", logType: "LabelAutomation")
            return
        }
        
        Logger.log("Processed App Results: \(String(describing: processedAppResults))", logType: "LabelAutomation")

        // MARK: - Check Intune for any versions
        
        // Check Intune for an existing versions
        Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: "LabelAutomation")
        
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.log("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: "Automation")
            
            for app in appInfo {
                Logger.log("    ---", logType: "Automation")
                Logger.log("    App: \(app.displayName)", logType: "Automation")
                Logger.log("    Ver: \(app.primaryBundleVersion)", logType: "Automation")
                Logger.log("     ID: \(app.id)", logType: "Automation")
                
                
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
                    Logger.log("Error updating \(processedAppResults?.appDisplayName ?? "unknown") with AppID \(app.id) metadata in Intune: \(error.localizedDescription)", logType: "LabelAutomation")
                }

            }
            
        } catch {
            Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: "LabelAutomation")
            return
        }

        
    }
    
    
    // MARK: - UPDATE SCRIPTS ONLY FOR FOLDER
    static func processFolderScripts(named folderName: String) async {
        // Variables to track label processing
        var processedAppResults: ProcessedAppResults?

        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo]

        Logger.log("--------------------------------------------------------", logType: "Automation")
        Logger.log("🚀 Start assignment update of \(folderName)", logType: "Automation")
        Logger.log("Start assignment update of: \(folderName)", logType: "LabelAutomation")

        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: "LabelAutomation")
            return
        }
                
        // Get the Processed App Results starter for this folder
        processedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults?.appDisplayName ?? "Unknown")", logType: "LabelAutomation")
        
        Logger.log("  Label: \(String(describing: processedAppResults?.appLabelName))", logType: "LabelAutomation")
        
        guard let trackingID = processedAppResults?.appTrackingID else {
            Logger.log("Tracking ID is missing", logType: "LabelAutomation")
            return
        }
        Logger.log("  Tracking ID: \(trackingID)", logType: "LabelAutomation")


        // MARK: - Check Intune for any versions
        
        // Check Intune for an existing versions
        Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: "LabelAutomation")
        
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.log("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: "Automation")
            
            for app in appInfo {
                Logger.log("    ---", logType: "Automation")
                Logger.log("    App: \(app.displayName)", logType: "Automation")
                Logger.log("    Ver: \(app.primaryBundleVersion)", logType: "Automation")
                Logger.log("     ID: \(app.id)", logType: "Automation")
                
                // MARK: - Upload scripts to Intune
                do {
                    
                    let entraAuthenticator = EntraAuthenticator()
                    let authToken = try await entraAuthenticator.getEntraIDToken()
                    
                    // Call the update function
                    try await EntraGraphRequests.updateAppIntuneScripts(authToken: authToken, app: processedAppResults!, appId: app.id)
                    
                } catch {
                    Logger.log("Error updating \(processedAppResults?.appDisplayName ?? "unknown") with AppID \(app.id) scripts in Intune: \(error.localizedDescription)", logType: "LabelAutomation")
                }
            }
            
        } catch {
            Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: "LabelAutomation")
            return
        }
    }


    
    // MARK: - FULLY PROCESS FOLDER
    static func processFolder(named folderName: String) async {
        
        // Variables to track label processing
        var processedAppResults: ProcessedAppResults?
        var checkedIntune: Bool = false
        var versionsExpectedAndActualMatched: Bool = false
        
        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo]
        
        Logger.log("--------------------------------------------------------", logType: "Automation")
        Logger.log("🚀 Start processing of \(folderName)", logType: "Automation")
        Logger.log("Start processing: \(folderName)", logType: "LabelAutomation")

        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: "LabelAutomation")
            return
        }
                
        // Get the Processed App Results starter for this folder
        processedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults?.appDisplayName ?? "Unknown")", logType: "LabelAutomation")
        
        Logger.log("  Label: \(String(describing: processedAppResults?.appLabelName))", logType: "LabelAutomation")
        Logger.log("  Tracking ID: \(String(describing: processedAppResults?.appTrackingID))", logType: "LabelAutomation")
        Logger.log("  Version to check: \(String(describing: processedAppResults?.appVersionExpected))", logType: "LabelAutomation")
        
        guard let trackingID = processedAppResults?.appTrackingID else {
            Logger.log("Tracking ID is missing", logType: "LabelAutomation")
            return
        }
        
        Logger.log("Processed App Results: \(String(describing: processedAppResults))", logType: "LabelAutomation")
        
        // MARK: - Check Intune with expected version
        
        // appNewVersion has a known value.
        if processedAppResults?.appVersionExpected != "" {
            
            // Check Intune for an existing version
            Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: "LabelAutomation")
            
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
                
                Logger.log("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: "Automation")
                
                for app in appInfo {
                    Logger.log("    ---", logType: "Automation")
                    Logger.log("    App: \(app.displayName)", logType: "Automation")
                    Logger.log("    Ver: \(app.primaryBundleVersion)", logType: "Automation")
                    Logger.log("     ID: \(app.id)", logType: "Automation")
                }
                
                // Check if current version is already uploaded to Intune
                let versionExistsInIntune = await isVersionUploadedToIntuneAsync(appInfo: appInfo, version: processedAppResults!.appVersionExpected)
                
                // Version is already in Intune. No need to continue
                if versionExistsInIntune {
                    Logger.log("    ---", logType: "Automation")
                    Logger.log("    Version \(processedAppResults!.appVersionExpected) is already uploaded to Intune", logType: "Automation")
                    return
                }
                
                checkedIntune = true
                
                Logger.log("  Version \(processedAppResults!.appVersionExpected) is not yet uploaded to Intune", logType: "LabelAutomation")
                
            } catch {
                Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: "LabelAutomation")
                return
            }
        }
        
        // MARK: - Check cache for pre-existing download
        
        var cacheCheckURL: URL = URL(fileURLWithPath: "/")
        
        do{
            cacheCheckURL = try isVersionCached(forLabel: processedAppResults?.appLabelName ?? "", displayName: processedAppResults?.appDisplayName ?? "", version: processedAppResults?.appVersionExpected ?? "", deploymentType: processedAppResults?.appDeploymentType ?? 0, deploymentArch: processedAppResults?.appDeploymentArch ?? 0)

            Logger.log("cacheCheck: \(cacheCheckURL)", logType: "LabelAutomation")

        } catch {
            Logger.log("No cache data found", logType: "LabelAutomation")
        }
        
        
        
        // MARK: - Download the file
        
        if cacheCheckURL != URL(fileURLWithPath: "/") {
            Logger.log("Cache hit. No need to download", logType: "LabelAutomation")
            
            processedAppResults?.appLocalURL = cacheCheckURL.path

            let actualBundleID = processedAppResults?.appBundleIdExpected
            let actualVersion = processedAppResults?.appVersionExpected
            
            processedAppResults?.appBundleIdActual = actualBundleID ?? "None"
            processedAppResults?.appVersionActual = actualVersion ?? "None"
            
            Logger.log("  Processed file ready at: \(String(describing: processedAppResults?.appLocalURL))", logType: "LabelAutomation")
            Logger.log("  Version: \(String(describing: processedAppResults?.appVersionActual))", logType: "LabelAutomation")
            
        } else {
            Logger.log("Cache miss. Downloading...", logType: "LabelAutomation")
            
            // Proceed with the download
            do {
                // Version needs to be downloaded and then uploaded to intune
                let downloadURL = processedAppResults?.appDownloadURL
                
                Logger.log("  Download URL: \(String(describing: downloadURL))", logType: "LabelAutomation")
                guard ((downloadURL?.isEmpty) != nil) else {
                    Logger.log("  No download URL available for \(processedAppResults!.appDisplayName)", logType: "LabelAutomation")
                    return
                }
                
                var downloadedFileURLx86 = URL(string: "ftp://")!

                // First, download the file
                let downloadedFileURL = try await downloadFile(
                    for: folderName,
                    processedAppResults: processedAppResults!
                )
                
                // check for universal pkg
                if processedAppResults?.appDeploymentArch == 2 && titleIsDualArch(forFolder: folderName){
                    Logger.log("Downloading x86 version of the app", logType: "LabelAutomation")
                    Logger.log("Deployment arch is \(processedAppResults?.appDeploymentArch ?? 5), and \(folderName) is dual arch", logType: "LabelAutomation")
                    let downloadedFileURL = try await downloadFile(
                        for: folderName,
                        processedAppResults: processedAppResults!,
                        downloadArch: "x86"
                    )
                    downloadedFileURLx86 = downloadedFileURL
                }
                
                Logger.log("  Downloaded file path: \(downloadedFileURL.path)", logType: "LabelAutomation")
                
                Logger.log ("  Processing file for: \(downloadURL ?? "None")", logType: "LabelAutomation")
                Logger.log("  Processing folder: \(folderName)", logType: "LabelAutomation")
                
                // MARK: - Process the downloaded file
                
                Logger.log("Downloaded file URL 1: \(downloadedFileURL)", logType: "LabelAutomation")
                Logger.log("Downloaded file URL 2: \(downloadedFileURLx86)", logType: "LabelAutomation")

                // Process the downloaded file based on its type
                let processedFileResult = try await processDownloadedFile(
                    displayName: processedAppResults!.appDisplayName,
                    downloadURL: downloadedFileURL,
                    downloadURLx86: downloadedFileURLx86,
                    folderName: folderName,
                    processedAppResults: processedAppResults!
                )
                Logger.log ("  Processed file result: \(processedFileResult)", logType: "LabelAutomation")
                
                Logger.log ("  URL: \(processedFileResult.url)", logType: "LabelAutomation")
                Logger.log ("  name: \(processedFileResult.name)", logType: "LabelAutomation")
                Logger.log ("  bundleID: \(processedFileResult.bundleID)", logType: "LabelAutomation")
                Logger.log ("  version: \(processedFileResult.version)", logType: "LabelAutomation")
                
                
                processedAppResults?.appLocalURL = processedFileResult.url.path
                if processedFileResult.name != "" {
                    processedAppResults?.appDisplayName = processedFileResult.name
                }
                if processedFileResult.bundleID != "" {
                    processedAppResults?.appBundleIdActual = processedFileResult.bundleID
                }
                if processedFileResult.version != "" {
                    processedAppResults?.appVersionActual = processedFileResult.version
                }
                
                
                Logger.log("  Processed file ready at: \(String(describing: processedAppResults?.appLocalURL))", logType: "LabelAutomation")
                Logger.log("  Version: \(String(describing: processedAppResults?.appVersionActual))", logType: "LabelAutomation")
                
                
                
                // MARK: - Check Intune with download version
                if processedAppResults?.appVersionActual != processedAppResults?.appVersionExpected || checkedIntune == false {
                    Logger.log("  Version mismatch or Intune check not performed previously.", logType: "LabelAutomation")
                    
                    // Check Intune for an existing version
                    Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: "LabelAutomation")
                    
                    do {
                        let entraAuthenticator = EntraAuthenticator()
                        let authToken = try await entraAuthenticator.getEntraIDToken()
                        
                        appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
                        
                        Logger.log("  Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: "LabelAutomation")
                        
                        for app in appInfo {
                            Logger.log("    ---", logType: "Automation")
                            Logger.log("    App: \(app.displayName)", logType: "Automation")
                            Logger.log("    Ver: \(app.primaryBundleVersion)", logType: "Automation")
                            Logger.log("     ID: \(app.id)", logType: "Automation")
                        }
                        
                        // Check if current version is already uploaded to Intune
                        let versionExistsInIntune = await isVersionUploadedToIntuneAsync(appInfo: appInfo, version: processedAppResults!.appVersionActual)
                        
                        // Version is already in Intune. No need to continue
                        if versionExistsInIntune {
                            Logger.log("    ---", logType: "Automation")
                            Logger.log("    Version \(processedAppResults!.appVersionActual) is already uploaded to Intune", logType: "LabelAutomation")
                                         
                            
                            // Clean up the download before we bail
                            let downloadFolder = AppConstants.intuneomatorCacheFolderURL
                                .appendingPathComponent(processedAppResults!.appLabelName)
                                .appendingPathComponent("tmp")
                            
                            if FileManager.default.fileExists(atPath: downloadFolder.path) {
                                // Delete the tmp directory
                                do{
                                    try FileManager.default.removeItem(at: downloadFolder)
                                } catch {
                                    Logger.log("❌ Failed to delete tmp folder: \(error.localizedDescription)", logType: "LabelAutomation")
                                }
                            }
                            return
                        }
                        
                        checkedIntune = true
                        
                        Logger.log("  Version \(processedAppResults!.appVersionActual) is not yet uploaded to Intune", logType: "LabelAutomation")
                        
                    } catch {
                        Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: "LabelAutomation")
                        return
                    }
                    
                    
                } else {
                    versionsExpectedAndActualMatched = true
                }
                // Here you would continue with additional processing,
                // such as uploading to Intune or other operations
                
            } catch {
                Logger.log("❌ Processing failed: \(error.localizedDescription)", logType: "LabelAutomation")
            }

        }
        
        Logger.log("\(processedAppResults!)", logType: "LabelAutomation")
        
        
        // MARK: - Upload to Intune
        do {
            
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            // Call the upload function
            try await EntraGraphRequests.uploadAppToIntune(authToken: authToken, app: processedAppResults!)
            
        } catch {
            Logger.log("Error uploading \(processedAppResults?.appLocalURL ?? "unknown") to Intune: \(error.localizedDescription)", logType: "LabelAutomation")
        }
        
        
        // Get file size for logging
        do {
            let labelDisplayName = processedAppResults!.appDisplayName
            let labelName = processedAppResults!.appLabelName
            let finalFilename = URL(string: processedAppResults!.appLocalURL)?.lastPathComponent
            // file size
            let fileIdentifier = processedAppResults!.appBundleIdActual
            let fileVersionActual = processedAppResults!.appVersionActual
            let fileVersionExpected = processedAppResults!.appVersionExpected
            let labelTrackingID = processedAppResults!.appTrackingID
            let finalURL = processedAppResults!.appLocalURL

            let fileAttributes = try FileManager.default.attributesOfItem(atPath: finalURL)
            let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSizeBytes) / 1_048_576
                    
            Logger.logFileTransfer("\(labelDisplayName)\t\(labelName)\t\(finalFilename ?? "Unknown")\t\(String(format: "%.2f", fileSizeMB)) MB\t\(fileIdentifier)\t\(fileVersionActual)\t\(fileVersionExpected)\t\(labelTrackingID)\t\(finalURL)", logType: "Upload")
            
        } catch {
            Logger.log("Unable to get file size: \(error.localizedDescription)", logType: "LabelAutomation")
        }

        
        // MARK: - Check Intune for the new version and unassign or remove old versions.
        // Check Intune for the new version
        Logger.log("  " + folderName + ": Confirming app upload to Intune...", logType: "LabelAutomation")
        
        var uploadSucceeded: Bool = false
        
        do {
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.log("  Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: "LabelAutomation")
            
            // Check if current version is already uploaded to Intune
            uploadSucceeded = await isVersionUploadedToIntuneAsync(appInfo: appInfo, version: processedAppResults!.appVersionActual)
            
            
            // Unassign old versions
            for app in appInfo {
                Logger.log("App: \(app.displayName)", logType: "LabelAutomation")
                Logger.log("Version: \(app.primaryBundleVersion)", logType: "LabelAutomation")
                Logger.log("Tracking ID: \(app.id)", logType: "LabelAutomation")
                
                if app.primaryBundleVersion != processedAppResults!.appVersionActual {
                    if app.isAssigned == true {
                        Logger.log("Older assigned version found in Intune!", logType: "LabelAutomation")
                        Logger.log("Unassigning older version for app \(app.displayName)", logType: "LabelAutomation")
                        Logger.log("Unassigning older version for app \(app.primaryBundleVersion)", logType: "LabelAutomation")
                        Logger.log("Unassigning older version for app \(app.id)", logType: "LabelAutomation")

                        try await EntraGraphRequests.removeAllAppAssignments(authToken: authToken, appId: app.id)
                    }
                }
            }
            
            // Clean up extra older versions of the app
            let appVersionsToKeep = ConfigManager.readPlistValue(key: "AppVersionsToKeep") ?? 2
            let totalVersions = appInfo.count
            let versionsToDeleteCount = max(0, totalVersions - appVersionsToKeep)
            if versionsToDeleteCount > 0 {
                // Since appInfo is sorted oldest to newest, delete the earliest ones
                let appsToDelete = appInfo.prefix(versionsToDeleteCount)
                for app in appsToDelete {
                    guard !app.isAssigned else { continue }
                    Logger.log("Deleting older app \(app.displayName)", logType: "LabelAutomation")
                    Logger.log("Deleting older app \(app.primaryBundleVersion)", logType: "LabelAutomation")
                    Logger.log("Deleting older app \(app.id)", logType: "LabelAutomation")
                    try await EntraGraphRequests.deleteIntuneApp(authToken: authToken, appId: app.id)
                }
            }
            
            // Version is in Intune. Success!
            if uploadSucceeded {
                Logger.log("Version \(processedAppResults!.appVersionActual) was uploaded to Intune", logType: "LabelAutomation")
            }
            
        } catch {
            Logger.log("Failed to check for successful upload to Intune: \(error.localizedDescription)", logType: "LabelAutomation")
            return
        }
    
        
        // MARK: - Send Teams Notification
        
        // Get the Teams notification state from Config
        let sendTeamNotification = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false

        // If we should send a notification
        if sendTeamNotification {
            // get the webhook URL
            let url = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
            
            if url.isEmpty {
                Logger.log("No Teams Webhook URL set in Config. Not sending notification.", logType: "LabelAutomation")
            } else {
                
                // Set the Icon for the notification
                let iconImageURL = "https://icons.intuneomator.org/\(processedAppResults?.appLabelName ?? "genericapp").png"
                
                // Get file size for Teams Notification
                var fileSizeDisplay: String = ""
                do {
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: processedAppResults?.appLocalURL ?? "")
                    let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
                    let fileSizeMB = Double(fileSizeBytes) / 1_048_576

                    if fileSizeMB >= 1000 {
                        let fileSizeGB = fileSizeMB / 1024
                        fileSizeDisplay = String(format: "%.2f GB", fileSizeGB)
                    } else {
                        fileSizeDisplay = String(format: "%.2f MB", fileSizeMB)
                    }

                    Logger.log("File size: \(fileSizeDisplay)", logType: "LabelAutomation")
                } catch {
                    Logger.log("Unable to get file size: \(error.localizedDescription)", logType: "LabelAutomation")
                }

                // Get time stamp for notification:
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                let dateString = formatter.string(from: Date())

                let friendlyDate = "🕰️ \(dateString)"

                // Set the deployment type for the notification
                var deploymentType: String = ""
                switch processedAppResults?.appDeploymentType ?? 0 {
                case 0:
                    deploymentType = "💾 DMG"
                case 1:
                    deploymentType = "📦 PKG"
                case 2:
                    deploymentType = "🏢 LOB"
                default:
                    deploymentType = "🔄 Unknown"
                }
                
                // Set the deployment arch for the notification
                var deploymentArch: String = ""
                switch processedAppResults?.appDeploymentArch ?? 0 {
                    case 0:
                    deploymentArch = "🌍 Arm64"
                case 1:
                    deploymentArch = "🌍 x86_64"
                case 2:
                    deploymentArch = "🌍 Universal"
                default:
                    deploymentArch = "🔄 Unknown"
                }
                
                // We were sucessful with the upload
                if uploadSucceeded {
                    do {
                        
                        // Initilaize the Notifier
                        let teamsNotifier = TeamsNotifier(webhookURL: url)
                        
                        // Send the notification (Currently missing some attributes)
                        teamsNotifier.sendNotification(
                            title: processedAppResults?.appDisplayName ?? "",
                            version: processedAppResults?.appVersionActual ?? "",
                            size: fileSizeDisplay,
                            time: friendlyDate,
                            imageURL: iconImageURL,
                            deploymentType: deploymentType,
                            architecture: deploymentArch,
                            releaseNotesURL: nil,
                            requiredGroups: "",
                            availableGroups: "",
                            uninstallGroups: "",
                            isSuccess: true
                        )
                    }
                } else {
                    do {
                        
                        // Initilaize the Notifier
                        let teamsNotifier = TeamsNotifier(webhookURL: url)
                        
                        // Send the notification (Currently missing some attributes)
                        teamsNotifier.sendNotification(
                            title: processedAppResults?.appDisplayName ?? "",
                            version: processedAppResults?.appVersionActual ?? "",
                            size: fileSizeDisplay,
                            time: friendlyDate,
                            imageURL: iconImageURL,
                            deploymentType: deploymentType,
                            architecture: deploymentArch,
                            releaseNotesURL: nil,
                            requiredGroups: nil,
                            availableGroups: nil,
                            uninstallGroups: nil,
                            isSuccess: false,
                            errorMessage: "Failed to upload to Intune. The automation will try again the next time it runs."
                        )
                    }
                }
            }
        } else {
            Logger.log("❌ Teams notifications are not enabled.", logType: "LabelAutomation")
        }
        
        
        // MARK: - Clean up
        // Clean up
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(processedAppResults!.appLabelName)
            .appendingPathComponent("tmp")
        
        if FileManager.default.fileExists(atPath: downloadFolder.path) {
            // Delete the tmp directory
            do{
                try FileManager.default.removeItem(at: downloadFolder)
            } catch {
                Logger.log("❌ Failed to delete tmp folder: \(error.localizedDescription)", logType: "LabelAutomation")
            }
        }
    }
}
