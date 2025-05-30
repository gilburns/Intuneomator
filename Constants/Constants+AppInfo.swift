//
//  Constants+AppInfo.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

struct AppInfo: Codable {
    var CLIArguments: String
    var CLIInstaller: String
    var appName: String
    var appNewVersion: String
    var archiveName: String
    var blockingProcesses: String
    var curlOptions: String
    var downloadFile: String
    var downloadURL: String
    var expectedTeamID: String
    var guid: String
    var installerTool: String
    var label: String
    var labelIcon: String
    var name: String
    var packageID: String
    var pkgName: String
    var targetDir: String
    var transformToPkg: Bool
    var type: String
    var versionKey: String
}

extension AppInfo {
    // Add methods or computed properties here if needed
    static func load(from directory: URL) throws -> AppInfo {
        // Example logic to load `AppInfo` from a directory
        // Update this based on your specific file structure
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
