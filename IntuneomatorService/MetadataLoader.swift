//
//  MetadataLoader.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/29/25.
//

import Foundation

/// Loads metadata, plist, installer scripts, and assignments for each Intuneomator managed title.
struct MetadataLoader {
    private static let logType = "MetadataLoader"
    
    /// Extracts metadata, plist, scripts, and group assignments into a `ProcessedAppResults`.
    /// - Parameter folderName: The Intuneomator managed title folder (e.g. "Safari_<UUID>").
    /// - Returns: A `ProcessedAppResults` if all required fields are present; otherwise `nil`.
    static func extractDataForProcessedAppResults(from folderName: String) -> ProcessedAppResults? {
        // Extract the label name (before the UUID part)
        let parts = folderName.split(separator: "_")
        guard parts.count == 2 else {
            Logger.log("❌ Invalid folder format: \(folderName)", logType: logType)
            return nil
        }
        let labelName = String(parts[0])
        let labelGUID = String(parts[1])
        
        // Full path to the managed title folder
        let folderPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(folderName)
            .path
        
        // Load metadata.json
        var metadata: Metadata?
        let metadataURL = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(folderName)
            .appendingPathComponent("metadata.json")
        do {
            let data = try Data(contentsOf: metadataURL)
            metadata = try JSONDecoder().decode(Metadata.self, from: data)
        } catch {
            Logger.log("Failed to load metadata: \(error)", logType: logType)
        }
        
        // Extract metadata fields
        let expectedBundleID = metadata?.CFBundleIdentifier
        let categories = metadata?.categories
        let developer = metadata?.developer ?? ""
        let deployAsArchTagRaw = metadata?.deployAsArchTag
        let deploymentTypeTagRaw = metadata?.deploymentTypeTag
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
        
        
        guard
            let validatedExpectedBundleID = expectedBundleID,
            let deployAsArchTagRawValue = deployAsArchTagRaw,
            let deploymentTypeTagRawValue = deploymentTypeTagRaw,
            let deployAsArchTag = DeploymentArchTag(rawValue: deployAsArchTagRawValue),
            let deploymentTypeTag = DeploymentTypeTag(rawValue: deploymentTypeTagRawValue),
            let validatedDescription = description,
            let validatedMinimumOS = minimumOS,
            let validatedPublisher = publisher
        else {
            Logger.log("❌ Critical metadata keys are missing for \(folderName). Skipping.", logType: logType)
            return nil
        }
        
        // Determine which .plist to read
        let plistPathArm64 = (folderPath as NSString).appendingPathComponent("\(labelName).plist")
        let plistPathx86_64 = (folderPath as NSString).appendingPathComponent("\(labelName)_i386.plist")
        var downloadURLx86_64String: String = ""
        
        let isDualArch = titleIsDualArch(forFolder: folderName)
        var plistPath: String = ""
        if isDualArch {
            switch deployAsArchTag {
            case .x86_64:
                plistPath = plistPathx86_64
            case .arm64, .universal:
                plistPath = plistPathArm64
            }
        } else {
            plistPath = plistPathArm64
        }
        
        guard FileManager.default.fileExists(atPath: plistPath) else {
            Logger.log("❌ Missing plist file: \(plistPath)", logType: logType)
            return nil
        }
        
        guard let plistData = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else {
            Logger.log("❌ Failed to parse plist: \(plistPath)", logType: logType)
            return nil
        }
        
        if deployAsArchTag == .universal && isDualArch {
            guard let plistDatax86 = NSDictionary(contentsOfFile: plistPathx86_64) as? [String: Any] else {
                Logger.log("❌ Failed to parse plist: \(plistPathx86_64)", logType: logType)
                return nil
            }
            downloadURLx86_64String = plistDatax86["downloadURL"] as? String ?? ""
        }
        let downloadURLx86_64 = downloadURLx86_64String
        
        let appNewVersion = plistData["appNewVersion"] as? String
        let downloadURLString = plistData["downloadURL"] as? String
        let downloadURL = downloadURLString
        let expectedTeamID = plistData["expectedTeamID"] as? String
        let name = plistData["name"] as? String
        let type = plistData["type"] as? String
        let labelIcon = plistData["labelIcon"] as? String
        
        guard
            let validatedDownloadURL = downloadURL,
            let validatedExpectedTeamID = expectedTeamID,
            let validatedName = name,
            let validatedType = type,
            let validatedLabelIcon = labelIcon,
            let validatedAppNewVersion = appNewVersion
        else {
            Logger.log("❌ Critical plist keys are missing for \(folderName). Skipping.", logType: logType)
            return nil
        }
//        Logger.log("  Extracted plist and metadata for \(folderName): name=\(validatedName), version=\(appNewVersion ?? "N/A"), downloadURL=\(validatedDownloadURL), type=\(validatedType)", logType: logType)
        
        // calculate the file name
        var filename: String
        do {
            let finalFileNameCalculated = try finalFilename(forAppTitle: validatedName, version: validatedAppNewVersion, deploymentType: DeploymentTypeTag(rawValue: deploymentTypeTag.rawValue) ?? .pkg, deploymentArch: DeploymentArchTag(rawValue: deployAsArchTag.rawValue) ?? .universal, isDualArch: isDualArch)
            filename = finalFileNameCalculated
        } catch {
            filename = "UnknownFile"
        }

        // Load installer scripts
        let scriptsBase = AppConstants.intuneomatorManagedTitlesFolderURL.appendingPathComponent(folderName)
        let preScriptURL = scriptsBase.appendingPathComponent("preinstall.sh")
        let postScriptURL = scriptsBase.appendingPathComponent("postinstall.sh")
        
        var preInstallScript: String?
        var postInstallScript: String?
        if FileManager.default.fileExists(atPath: preScriptURL.path) {
            preInstallScript = (try? String(contentsOf: preScriptURL, encoding: .utf8)) ?? ""
        } else {
            preInstallScript = ""
        }
        if FileManager.default.fileExists(atPath: postScriptURL.path) {
            postInstallScript = (try? String(contentsOf: postScriptURL, encoding: .utf8)) ?? ""
        } else {
            postInstallScript = ""
        }
        
        // Load group assignments
        let assignmentsURL = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(folderName)
            .appendingPathComponent("assignments.json")
        var groupAssignments: [[String: Any]] = []
        func sortGroupAssignments() {
            let order = ["Required", "Available", "Uninstall"]
            groupAssignments.sort {
                let i1 = order.firstIndex(of: $0["assignmentType"] as? String ?? "") ?? .max
                let i2 = order.firstIndex(of: $1["assignmentType"] as? String ?? "") ?? .max
                if i1 != i2 { return i1 < i2 }
                let n1 = $0["displayName"] as? String ?? ""
                let n2 = $1["displayName"] as? String ?? ""
                return n1.localizedCompare(n2) == .orderedAscending
            }
        }
        do {
            let data = try Data(contentsOf: assignmentsURL)
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                groupAssignments = json
                sortGroupAssignments()
            } else {
                Logger.log("JSON format is invalid", logType: logType)
            }
        } catch {
            Logger.log("Failed to load assignments: \(error)", logType: logType)
        }
        
        // Build the final ProcessedAppResults
        let results = ProcessedAppResults(
            appAssignments: groupAssignments,
            appBundleIdActual: "",
            appBundleIdExpected: validatedExpectedBundleID,
            appCategories: categories ?? [],
            appDeploymentArch: deployAsArchTag.rawValue,
            appDeploymentType: deploymentTypeTag.rawValue,
            appDescription: validatedDescription,
            appDeveloper: developer,
            appDisplayName: validatedName,
            appDownloadURL: validatedDownloadURL,
            appDownloadURLx86: downloadURLx86_64,
            appIconURL: validatedLabelIcon,
            appIgnoreVersion: ignoreVersion,
            appInfoURL: informationURL,
            appIsDualArchCapable: isDualArch,
            appIsFeatured: featured,
            appIsManaged: managed,
            appLabelName: labelName,
            appLabelType: validatedType,
            appLocalURL: "",
            appLocalURLx86: "",
            appMinimumOS: validatedMinimumOS,
            appNotes: notes,
            appOwner: owner,
            appPrivacyPolicyURL: privacyInformationUrl,
            appPublisherName: validatedPublisher,
            appScriptPreInstall: preInstallScript ?? "",
            appScriptPostInstall: postInstallScript ?? "",
            appTeamID: validatedExpectedTeamID,
            appTrackingID: labelGUID,
            appVersionActual: "",
            appVersionExpected: appNewVersion ?? "",
            appUploadFilename: filename
        )
        return results
    }
    
    /// Detects if both ARM64 and x86_64 plists exist for a title, indicating a dual-arch package.
    static func titleIsDualArch(forFolder folder: String) -> Bool {
        let base = AppConstants.intuneomatorManagedTitlesFolderURL.appendingPathComponent(folder)
        let label = folder.components(separatedBy: "_").first ?? ""
        let armURL = base.appendingPathComponent("\(label).plist")
        let x86URL = base.appendingPathComponent("\(label)_i386.plist")
        return FileManager.default.fileExists(atPath: armURL.path) &&
        FileManager.default.fileExists(atPath: x86URL.path)
    }
    
    
    static func finalFilename(forAppTitle title: String, version: String, deploymentType: DeploymentTypeTag, deploymentArch: DeploymentArchTag, isDualArch: Bool) throws -> String {
        
        guard !version.isEmpty else {
            return ""
        }
        
        let fileName: String
        
        let fileSuffix: String = (deploymentType == .dmg) ? "dmg" : "pkg"
        let fileArch: String
        
        switch deploymentArch {
        case .arm64:
            switch isDualArch {
                case true:
                fileArch = "arm64"
            default:
                fileArch = "universal"
            }
        case .x86_64:
            fileArch = "x86_64"
        case .universal:
            fileArch = "universal"
        }
        
        fileName = "\(title)-\(version)-\(fileArch).\(fileSuffix)"

        return fileName
    }
}
