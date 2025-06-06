//
//  Constants+AppInfo.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

// MARK: - Application Information Structure

/// Complete application information structure for Installomator integration
/// Contains all metadata and configuration needed for automated app processing
struct AppInfo: Codable {
    
    /// Command-line arguments for installer execution
    var CLIArguments: String
    
    /// Command-line installer tool path or name
    var CLIInstaller: String
    
    /// Display name of the application
    var appName: String

    /// Latest available version of the application
    var appNewVersion: String

    /// Archive name after extraction (if applicable)
    var archiveName: String

    /// Comma-separated list of processes to quit before installation
    var blockingProcesses: String

    /// Additional curl options for download customization
    var curlOptions: String
    
    /// Filename of the downloaded file
    var downloadFile: String

    /// Direct download URL for the application
    var downloadURL: String

    /// Expected Apple Developer Team ID for code signature verification
    var expectedTeamID: String

    /// Unique identifier for tracking in Intune
    var guid: String

    /// Installation tool to use (e.g., "installer", "ditto", "unzip")
    var installerTool: String

    /// Installomator label identifier
    var label: String
    
    /// Icon filename or identifier for the application
    var labelIcon: String

    /// Internal name identifier
    var name: String
    
    /// Application bundle identifier (e.g., com.company.app)
    var packageID: String

    /// PKG filename for installer packages
    var pkgName: String

    /// Target directory for application installation
    var targetDir: String
    
    /// Whether to convert DMG to PKG format for deployment
    var transformToPkg: Bool
    
    /// Application type (e.g., "dmg", "pkg", "zip")
    var type: String
    
    /// Property list key used for version detection
    var versionKey: String
    
}

// MARK: - AppInfo Extensions

extension AppInfo {
    /// Loads AppInfo from a plist file in the specified directory
    /// Used for reading cached application information during processing
    /// - Parameter directory: Directory containing the info.plist file
    /// - Returns: Populated AppInfo structure
    /// - Throws: File I/O or property list parsing errors
    static func load(from directory: URL) throws -> AppInfo {
        let plistPath = directory.appendingPathComponent("info.plist")
        let plistData = try Data(contentsOf: plistPath)
        let plistDictionary = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as! [String: Any]

        return AppInfo(
            CLIArguments: plistDictionary["CLIArguments"] as? String ?? "",
            CLIInstaller: plistDictionary["CLIInstaller"] as? String ?? "",
            appName: plistDictionary["appName"] as? String ?? "",
            appNewVersion: plistDictionary["appNewVersion"] as? String ?? "",
            archiveName: plistDictionary["archiveName"] as? String ?? "",
            blockingProcesses: plistDictionary["blockingProcesses"] as? String ?? "",
            curlOptions: plistDictionary["curlOptions"] as? String ?? "",
            downloadFile: plistDictionary["downloadFile"] as? String ?? "",
            downloadURL: plistDictionary["downloadURL"] as? String ?? "",
            expectedTeamID: plistDictionary["expectedTeamID"] as? String ?? "",
            guid: plistDictionary["guid"] as? String ?? "",
            installerTool: plistDictionary["installerTool"] as? String ?? "",
            label: plistDictionary["label"] as? String ?? "",
            labelIcon: plistDictionary["labelIcon"] as? String ?? "",
            name: plistDictionary["name"] as? String ?? "",
            packageID: plistDictionary["packageID"] as? String ?? "",
            pkgName: plistDictionary["pkgName"] as? String ?? "",
            targetDir: plistDictionary["targetDir"] as? String ?? "",
            transformToPkg: plistDictionary["asPkg"] as? Bool ?? false,
            type: plistDictionary["type"] as? String ?? "",
            versionKey: plistDictionary["versionKey"] as? String ?? ""
        )
    }
}
