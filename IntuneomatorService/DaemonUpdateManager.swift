//
//  DaemonUpdateManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/20/25.
//

import Foundation

class DaemonUpdateManager {
 
    static let remoteVersionURL = URL(string: "https://intuneomator.org/downloads/latest-version.txt")!
    static let updatePkgURL = URL(string: "https://intuneomator.org/downloads/Intuneomator.pkg")!
    static let guiAppBundlePath = "/Applications/Intuneomator.app"
    static let updaterPath = "/Library/Application Support/Intuneomator/IntuneomatorUpdater"
    static let tempUpdaterPath = "/tmp/IntuneomatorUpdater"
    static let destinationPkgPath = "/Library/Application Support/Intuneomator/IntuneomatorUpdate.pkg"
    static let expectedTeamID = "G4MQ57TVLE"

    
    static var localVersion: String {
        let infoPlistPath = "\(guiAppBundlePath)/Contents/Info.plist"
        guard let plist = NSDictionary(contentsOfFile: infoPlistPath),
              let version = plist["CFBundleShortVersionString"] as? String else {
            return "0.0.0"
        }
        return version
    }
    
    static func checkAndPerformUpdateIfNeeded() {
        fetchRemoteVersion { remoteVersion in
            guard let remoteVersion = remoteVersion else {
                Logger.log("❌ Failed to fetch remote version.", logType: "UpdateManager")
                exit(EXIT_FAILURE)
            }

            if remoteVersion.compare(localVersion, options: .numeric) == .orderedDescending {
                Logger.log("⬇️ New version available: \(remoteVersion)", logType: "UpdateManager")
                downloadPkg { success in
                    if success {
                        validatePkgDownload { isValid in
                            if isValid {
                                runUpdater()
                            } else {
                                Logger.log("❌ Package signature validation failed.", logType: "UpdateManager")
                                exit(EXIT_FAILURE)
                            }
                        }
                    } else {
                        Logger.log("❌ Update download failed.", logType: "UpdateManager")
                        exit(EXIT_FAILURE)
                    }
                }
            } else {
                Logger.log("✅ Already up-to-date.", logType: "UpdateManager")
                exit(EXIT_SUCCESS)
            }
        }
    }

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

        Logger.log("Validated Result: \(resultAccepted)", logType: "UpdateManager")
        Logger.log("Validated Team ID: \(resultTeamID)", logType: "UpdateManager")
        Logger.log("Validated Developer ID: \(resultDeveloperID)", logType: "UpdateManager")

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
    
    static func fetchRemoteVersion(completion: @escaping (String?) -> Void) {
        URLSession.shared.dataTask(with: remoteVersionURL) { data, _, _ in
            let version = data.flatMap { String(data: $0, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            completion(version)
        }.resume()
    }

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
                Logger.log("❌ Move error: \(error)", logType: "UpdateManager")
                completion(false)
            }
        }
        task.resume()
    }

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
            Logger.log("🚀 Updater launched successfully.", logType: "UpdateManager")

            sleep(4)
            exit(EXIT_SUCCESS)
        } catch {
            Logger.log("❌ Failed to run updater: \(error)", logType: "UpdateManager")
            exit(EXIT_FAILURE)
        }
    }
}
