//
//  Constants.swift
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

enum DeploymentArchTag: Int, Codable {
    case arm64 = 0
    case x86_64 = 1
    case universal = 2
}

enum DeploymentTypeTag: Int, Codable {
    case dmg = 0
    case pkg = 1
    case lob = 2
}


struct ProcessedAppResults {
    var appAssignments: [[String : Any]]
    var appBundleIdActual: String
    var appBundleIdExpected: String
    var appCategories: [Category]
    var appDeploymentArch: Int
    var appDeploymentType: Int
    var appDescription: String
    var appDeveloper: String
    var appDisplayName: String
    var appDownloadURL: String
    var appDownloadURLx86: String
    var appIconURL: String
    var appIgnoreVersion: Bool
    var appInfoURL: String
    var appIsDualArchCapable: Bool
    var appIsFeatured: Bool
    var appIsManaged: Bool
    var appLabelName: String
    var appLabelType: String
    var appLocalURL: String
    var appLocalURLx86: String
    var appMinimumOS: String
    var appNotes: String
    var appOwner: String
    var appPlatform: String
    var appPrivacyPolicyURL: String
    var appPublisherName: String
    var appScriptPreInstall: String
    var appScriptPostInstall: String
    var appTeamID: String
    var appTrackingID: String
    var appVersionActual: String
    var appVersionExpected: String
    var appUploadFilename: String
}

extension ProcessedAppResults {
  static let empty = ProcessedAppResults(
    appAssignments: [],
    appBundleIdActual: "",
    appBundleIdExpected: "",
    appCategories: [],
    appDeploymentArch: 3,
    appDeploymentType: 3,
    appDescription: "",
    appDeveloper: "",
    appDisplayName: "",
    appDownloadURL: "",
    appDownloadURLx86: "",
    appIconURL: "",
    appIgnoreVersion: false,
    appInfoURL: "",
    appIsDualArchCapable: false,
    appIsFeatured: false,
    appIsManaged: false,
    appLabelName: "",
    appLabelType: "",
    appLocalURL: "",
    appLocalURLx86: "",
    appMinimumOS: "",
    appNotes: "",
    appOwner: "",
    appPlatform: "",
    appPrivacyPolicyURL: "",
    appPublisherName: "",
    appScriptPreInstall: "",
    appScriptPostInstall: "",
    appTeamID: "",
    appTrackingID: "",
    appVersionActual: "",
    appVersionExpected: "",
    appUploadFilename: ""
  )
}

extension ProcessedAppResults {
    
    /// Emoji + label for architecture
    var architectureEmoji: String {
        switch appDeploymentArch {
        case 0: return "🌍 Arm64"
        case 1: return "🌍 x86_64"
        case 2: return "🌍 Universal"
        default: return "❓ Unknown"
        }
    }

    /// Emoji + label for deployment type (DMG, PKG, LOB)
    var deploymentTypeEmoji: String {
        switch appDeploymentType {
        case 0: return "💾 DMG"
        case 1: return "📦 PKG"
        case 2: return "🏢 LOB"
        default: return "❓ Unknown"
        }
    }
}

struct ProcessedFileResult {
  let url: URL
  let name: String
  let bundleID: String
  let version: String
}

struct Category: Codable, Equatable {
    var displayName: String
    var id: String
}


struct CertificateInfo {
    let subjectName: String
    let serialNumber: String
    let issuerName: String
    let thumbprint: String
    let expirationDate: Date?
    let keyUsage: Int?
    let dnsNames: [String]?
    let algorithm: String?
    let keySize: Int?
}

// Struct to store downloaded file info
struct DownloadedFile {
    let filePath: String
    let fileName: String
    let fileSize: Int64
}

// MARK: - Intune Device Filters
struct AssignmentFilter: Decodable {
    let id: String
    let displayName: String
    let description: String?
}


// MARK: - Intune App Check
struct FilteredIntuneAppInfo: Codable {
    let id: String
    let displayName: String
    let isAssigned: Bool
    let primaryBundleId: String
    let primaryBundleVersion: String
}


// MARK: - Struct for Label Data
struct LabelInfo: Codable {
    let label: String
    let labelContents: String
    let labelFileURL: String
    let labelSource: String
}


struct LabelPlistInfo: Decodable {
    let appID: String
    let description: String
    let documentation: String
    let publisher: String
    let privacy: String
    
    enum CodingKeys: String, CodingKey {
        case appID = "AppID"
        case description = "Description"
        case documentation = "Documentation"
        case publisher = "Publisher"
        case privacy = "Privacy"
    }
}


// MARK: - Metadata.json file
struct Metadata: Codable, Equatable {
    var categories: [Category]
    var description: String
    var deployAsArchTag: Int = 0
    var deploymentTypeTag: Int = 0
    var developer: String?
    var informationUrl: String?
    var ignoreVersionDetection: Bool
    var isFeatured: Bool
    var isManaged: Bool
    var minimumOS: String
    var minimumOSDisplay: String
    var notes: String?
    var owner: String?
    var privacyInformationUrl: String?
    var publisher: String
    var CFBundleIdentifier: String
}

struct MetadataPartial: Codable, Equatable {
    var developer: String?
    var informationUrl: String?
    var notes: String?
    var owner: String?
    var privacyInformationUrl: String?
        
    init(developer: String?,
         informationUrl: String?,
         notes: String?,
         owner: String?,
         privacyInformationUrl: String?) {
        self.developer = developer
        self.informationUrl = informationUrl
        self.notes = notes
        self.owner = owner
        self.privacyInformationUrl = privacyInformationUrl
    }

}


// Define a struct to store extracted plist data
struct PlistData {
    let appNewVersion: String?
    let downloadURL: String
    let expectedTeamID: String
    let name: String
    let type: String
}

// MARK: - Struct for Settings
struct Settings: Codable {
    var tenantid: String = ""
    var appid: String = ""
    var certThumbprint: String = ""
    var secret: String = ""
    var appsToKeep: String = ""
    var connectMethod: String = ""
    var privateKeyFile: String = ""
    var sendTeamsNotifications: Bool = false
    var teamsWebhookURL: String = ""
    var logAgeMax: String = ""
    var logSizeMax: String = ""

    init() {}

    // Provide defaults during decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tenantid = try container.decodeIfPresent(String.self, forKey: .tenantid) ?? ""
        appid = try container.decodeIfPresent(String.self, forKey: .appid) ?? ""
        certThumbprint = try container.decodeIfPresent(String.self, forKey: .certThumbprint) ?? ""
        secret = try container.decodeIfPresent(String.self, forKey: .secret) ?? ""
        appsToKeep = try container.decodeIfPresent(String.self, forKey: .appsToKeep) ?? "2"
        connectMethod = try container.decodeIfPresent(String.self, forKey: .connectMethod) ?? "certificate"
        privateKeyFile = try container.decodeIfPresent(String.self, forKey: .privateKeyFile) ?? ""
        sendTeamsNotifications = try container.decodeIfPresent(Bool.self, forKey: .sendTeamsNotifications) ?? false
        teamsWebhookURL = try container.decodeIfPresent(String.self, forKey: .teamsWebhookURL) ?? ""
        logAgeMax = try container.decodeIfPresent(String.self, forKey: .logAgeMax) ?? ""
        logSizeMax = try container.decodeIfPresent(String.self, forKey: .logSizeMax) ?? ""

    }
}

// MARK: - Error Types
enum IntuneServiceError: Int, Error, Codable {
    case invalidURL = 1000
    case networkError = 1001
    case authenticationError = 1002
    case permissionDenied = 1003
    case decodingError = 1004
    case tokenError = 1005
    case serverError = 1006
    
    var localizedDescription: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError: return "Network connection error"
        case .authenticationError: return "Authentication failed"
        case .permissionDenied: return "Missing permissions in Enterprise App settings"
        case .decodingError: return "Failed to decode server response"
        case .tokenError: return "Failed to obtain valid token"
        case .serverError: return "Server returned an error"
        }
    }
}



/// Model for a detected app
struct DetectedApp: Codable {
    let displayName: String?
    let id: String?
    let platform: String?
    let version: String?
    let publisher: String?
    let deviceCount: Int?
    var installomatorLabel: String // This is manually assigned, not from JSON
    
    enum CodingKeys: String, CodingKey {
        case displayName, id, platform, version, publisher, deviceCount
    }
    
    // Custom decoder for JSON
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.platform = try container.decodeIfPresent(String.self, forKey: .platform)
        self.version = try container.decodeIfPresent(String.self, forKey: .version)
        self.publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
        self.deviceCount = try container.decodeIfPresent(Int.self, forKey: .deviceCount)
        self.installomatorLabel = "No match detected"
    }
    
    // ✅ Manual initializer to allow object duplication
    init(displayName: String?, id: String?, platform: String?, version: String?, publisher: String?, deviceCount: Int?, installomatorLabel: String) {
        self.displayName = displayName
        self.id = id
        self.platform = platform
        self.version = version
        self.publisher = publisher
        self.deviceCount = deviceCount
        self.installomatorLabel = installomatorLabel
    }
    
    // ✅ Fix for the error: Explicitly create a copy with a new label
    func withLabel(_ label: String) -> DetectedApp {
        return DetectedApp(
            displayName: self.displayName,
            id: self.id,
            platform: self.platform,
            version: self.version,
            publisher: self.publisher,
            deviceCount: self.deviceCount,
            installomatorLabel: label  // Assign a unique label per row
        )
    }
}

struct DeviceInfo: Codable {
    let deviceName: String
    let id: String
    let emailAddress: String
}


/// Model for Graph API response
struct GraphResponseDetectedApp: Decodable {
    let value: [DetectedApp]
    let nextLink: String?
    
    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}



struct AppConstants {
    
    static let currentPid: Int32 = ProcessInfo.processInfo.processIdentifier
    static let randomGUID = UUID().uuidString

    static let intuneomatorFolderURL = URL(fileURLWithPath: "/Library")
        .appendingPathComponent("Application Support")
        .appendingPathComponent("Intuneomator")
    
    static let intuneomatorCacheFolderURL = intuneomatorFolderURL
        .appendingPathComponent("Cache")

    static let installomatorFolderURL = intuneomatorFolderURL
        .appendingPathComponent("Installomator")

    static let installomatorLabelsFolderURL = intuneomatorFolderURL
        .appendingPathComponent("Installomator")
        .appendingPathComponent("Labels")

    static let installomatorCustomLabelsFolderURL = intuneomatorFolderURL
        .appendingPathComponent("Installomator")
        .appendingPathComponent("Custom")

    static let intuneomatorManagedTitlesFolderURL = intuneomatorFolderURL
        .appendingPathComponent("ManagedTitles")

    static let intuneomatorOndemandTriggerURL = intuneomatorFolderURL
        .appendingPathComponent("ondemandQueue")

    static let intuneomatorServiceFileURL = intuneomatorFolderURL
        .appendingPathComponent("IntuneomatorService.plist")

    static let installomatorVersionFileURL = intuneomatorFolderURL
        .appendingPathComponent("Installomator")
        .appendingPathComponent("Version.txt")
    
    static let intuneomatorTempFolderURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("Intuneomator_\(currentPid)_\((randomGUID)[(randomGUID).startIndex..<(randomGUID).index((randomGUID).startIndex, offsetBy: 8)])")
    
    static let intuneomatorLogSystemURL = URL(fileURLWithPath: "/Library")
        .appendingPathComponent("Logs")
        .appendingPathComponent("Intuneomator")

    static let intuneomatorLogApplicationURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library")
        .appendingPathComponent("Logs")
        .appendingPathComponent("Intuneomator")

}
