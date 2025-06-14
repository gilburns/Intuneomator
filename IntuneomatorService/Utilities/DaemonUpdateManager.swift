//
//  DaemonUpdateManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/20/25.
//

import Foundation

/// Manages automatic updates for the Intuneomator daemon service
/// Handles version checking, package download, signature validation, and update installation
class DaemonUpdateManager {
 
    /// URL to fetch the latest version number from the server
    static let remoteVersionURL = URL(string: "https://intuneomator.org/downloads/latest-version.txt")!
    
    /// URL to download the update package from
    static let updatePkgURL = URL(string: "https://intuneomator.org/downloads/Intuneomator.pkg")!
    
    /// Path to the main Intuneomator application bundle
    static let guiAppBundlePath = "/Applications/Intuneomator.app"
    
    /// Path to the updater executable in the Application Support directory
    static let updaterPath = "/Library/Application Support/Intuneomator/IntuneomatorUpdater"
    
    /// Temporary path for the updater executable during update process
    static let tempUpdaterPath = "/tmp/IntuneomatorUpdater"
    
    /// Path where the downloaded update package is stored
    static let destinationPkgPath = "/Library/Application Support/Intuneomator/IntuneomatorUpdate.pkg"
    
    /// Expected Apple Developer Team ID for signature validation
    static let expectedTeamID = "G4MQ57TVLE"
    

    /// Gets the combined local version (CFBundleShortVersionString.CFBundleVersion)
    /// - Returns: Version string from the app's Info.plist, or "0.0.0.0" if not found
    static var localCombinedVersion: String {
        let infoPlistPath = "\(guiAppBundlePath)/Contents/Info.plist"
        guard let plist = NSDictionary(contentsOfFile: infoPlistPath),
              let version = plist["CFBundleShortVersionString"] as? String,
              let build = plist["CFBundleVersion"] as? String else {
            return "0.0.0.0"
        }
        return "\(version).\(build)"
    }
    
    /// Checks for available updates and performs the update if a newer version is found
    /// Handles both automatic updates and Teams notification modes based on configuration
    static func checkAndPerformUpdateIfNeeded() {
        fetchRemoteVersion { remoteVersion in
            guard let remoteVersion = remoteVersion else {
                Logger.error("❌ Failed to fetch remote version.", category: .core)
                exit(EXIT_FAILURE)
            }

            if remoteVersion.compare(localCombinedVersion, options: .numeric) == .orderedDescending {
                Logger.info("⬇️ New version available: \(remoteVersion)", category: .core)
                
                // Check if we should self update or just send a teams notification
                // 🔔 Teams Notification
                let sendTeamNotification = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false
                let sendForUpdates = ConfigManager.readPlistValue(key: "TeamsNotificationsForUpdates") ?? false

                let updateMode = ConfigManager.readPlistValue(key: "UpdateMode") ?? 0

                if sendTeamNotification && sendForUpdates && updateMode == 1 {
                    let url = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""

                    if url.isEmpty {
                        Logger.info("No Teams Webhook URL set in Config. Not sending notification.", category: .core)
                    } else {
                        let version = "unknown"
                        if let plist = NSDictionary(contentsOfFile: "/Applications/Intuneomator.app/Contents/Info.plist"),
                           let bundleVersion = plist["CFBundleShortVersionString"] as? String {
                            Logger.info("Detected Intuneomator version: \(bundleVersion)", category: .core)
                            let teamsNotifier = TeamsNotifier(webhookURL: url)
                            teamsNotifier.sendUpdateAvailableNotification(initialVersion: bundleVersion, updatedVersion: bundleVersion)
                        } else {
                            Logger.info("⚠️ Could not determine Intuneomator version.", category: .core)
                            let teamsNotifier = TeamsNotifier(webhookURL: url)
                            teamsNotifier.sendUpdateAvailableNotification(initialVersion: "Unknown version", updatedVersion: version, errorMessage: "Unable to determine updated version.")
                        }
                    }
                    exit(EXIT_SUCCESS)
                }
                
                
                downloadPkg { success in
                    if success {
                        validatePkgDownload { isValid in
                            if isValid {
                                runUpdater()
                            } else {
                                Logger.error("❌ Package signature validation failed.", category: .core)
                                exit(EXIT_FAILURE)
                            }
                        }
                    } else {
                        Logger.error("❌ Update download failed.", category: .core)
                        exit(EXIT_FAILURE)
                    }
                }
            } else {
                Logger.info("✅ Already up-to-date.", category: .core)
                exit(EXIT_SUCCESS)
            }
        }
    }

    /// Validates the downloaded package signature against the expected Team ID
    /// - Parameter completion: Callback with validation result (true if valid, false otherwise)
    static func validatePkgDownload(completion: @escaping (Bool) -> Void) {
        let pkgURL = destinationPkgPath
        var signatureResult: [String: Any] = [:]

        do {
            signatureResult = try SignatureInspector.inspectPackageSignature(pkgPath: pkgURL)
            print("Package Signature Inspection Result: \(signatureResult)")
        } catch {
            print("Error inspecting package signature: \(error)")
        }

        let resultAccepted = signatureResult["Accepted"] as? Bool ?? false
        let resultTeamID = signatureResult["DeveloperTeam"] as? String ?? ""
        let resultDeveloperID = signatureResult["DeveloperID"] as? String ?? ""

        Logger.info("Validated Result: \(resultAccepted)", category: .core)
        Logger.info("Validated Team ID: \(resultTeamID)", category: .core)
        Logger.info("Validated Developer ID: \(resultDeveloperID)", category: .core)

        #if DEBUG
        if resultTeamID == expectedTeamID {
            completion(true)
            return
        }
        #endif
        
        if resultAccepted && resultTeamID == expectedTeamID {
            completion(true)
            return
        }
        
        completion(false)
        return
    }
    
    /// Fetches the latest version number from the remote server
    /// - Parameter completion: Callback with the version string, or nil if fetch failed
    static func fetchRemoteVersion(completion: @escaping (String?) -> Void) {
        URLSession.shared.dataTask(with: remoteVersionURL) { data, _, _ in
            let version = data.flatMap { String(data: $0, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            completion(version)
        }.resume()
    }

    /// Downloads the update package from the remote server
    /// - Parameter completion: Callback indicating download success (true) or failure (false)
    static func downloadPkg(completion: @escaping (Bool) -> Void) {
        let task = URLSession.shared.downloadTask(with: updatePkgURL) { tempURL, _, error in
            guard let tempURL = tempURL, error == nil else {
                completion(false)
                return
            }

            do {
                let destURL = URL(fileURLWithPath: destinationPkgPath)
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                completion(true)
            } catch {
                Logger.error("❌ Move error: \(error)", category: .core)
                completion(false)
            }
        }
        task.resume()
    }

    /// Executes the updater process to install the downloaded package
    /// Copies the updater to a temporary location and launches it with the current process ID
    static func runUpdater() {
        do {
            if FileManager.default.fileExists(atPath: tempUpdaterPath) {
                try FileManager.default.removeItem(atPath: tempUpdaterPath)
            }
            
            try FileManager.default.copyItem(
                atPath: updaterPath,
                toPath: tempUpdaterPath
            )
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempUpdaterPath)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/tmp/IntuneomatorUpdater")
            process.arguments = ["--caller-pid", "\(getpid())"]
            try process.run()
            Logger.info("🚀 Updater launched successfully.", category: .core)

            sleep(4)
            exit(EXIT_SUCCESS)
        } catch {
            Logger.error("❌ Failed to run updater: \(error)", category: .core)
            exit(EXIT_FAILURE)
        }
    }
}
