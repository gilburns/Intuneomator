//
//  main.swift
//  IntuneomatorUpdater
//
//  Created by Gil Burns on 5/20/25.
//

import Foundation
import Security
import Darwin

let expectedTeamID = "G4MQ57TVLE"
let expectedParentPath = "/Library/Application Support/Intuneomator/IntuneomatorService"
let pkgPath = "/Library/Application Support/Intuneomator/IntuneomatorUpdate.pkg"
let targetVolume = "/"

// Define the constant manually
let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096

let kSecCSDefaultFlags = SecCSFlags(rawValue: 0)

func log(_ message: String) {
    print("[IntuneomatorUpdater] \(message)")
    Logger.log("\(message)", logType: "UpdateManager")
}

// MARK: - Parent Process Path Check
func verifyParentProcessPath(expectedPath: String) -> Bool {
    let parentPID = getppid()

    var buffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
    let result = proc_pidpath(parentPID, &buffer, UInt32(buffer.count))
    
    guard result > 0 else { return false }

    let parentPath = String(cString: buffer)
    log("Parent path: \(parentPath)")
    return parentPath == expectedPath
}

// MARK: - Code Signature Check
func verifySignature(ofPID pid: Int32, expectedTeamID: String) -> Bool {
    log("Verifying signature for PID: \(pid)")

    var targetCode: SecCode?
    let attributes: [String: Any] = [kSecGuestAttributePid as String: pid]

    let status = SecCodeCopyGuestWithAttributes(nil, attributes as CFDictionary, [], &targetCode)
    guard status == errSecSuccess, let code = targetCode else {
        log("❌ Could not obtain code object for PID \(pid): \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")")
        return false
    }

    var staticCode: SecStaticCode?
    let staticStatus = SecCodeCopyStaticCode(code, [], &staticCode)

    guard staticStatus == errSecSuccess, let finalCode = staticCode else {
        log("❌ Failed to convert to static code for PID \(pid): \(SecCopyErrorMessageString(staticStatus, nil) as String? ?? "Unknown error")")
        return false
    }

    var signingInfo: CFDictionary?
    // Use kSecCSSigningInformation instead
    let signingFlags = SecCSFlags(rawValue: kSecCSSigningInformation)

    let infoStatus = SecCodeCopySigningInformation(finalCode, signingFlags, &signingInfo)

    guard infoStatus == errSecSuccess else {
        log("❌ Could not obtain signing information for PID \(pid): \(SecCopyErrorMessageString(infoStatus, nil) as String? ?? "Unknown error")")
        return false
    }
    
    guard let info = signingInfo as? [String: Any] else {
        log("❌ Signing information dictionary is nil or invalid format for PID \(pid)")
        return false
    }
    
    guard let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String else {
        log("❌ Team ID not found in signing information for PID \(pid)")
        return false
    }

    log("✅ Team ID for PID \(pid): \(teamID)")
    return teamID == expectedTeamID
}


// MARK: - Install Package
func installPackage(at path: String, target: String) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/installer")
    process.arguments = ["-pkg", path, "-target", target]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        pipe.fileHandleForReading.closeFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        log("Installer output:\n\(output)")
        return process.terminationStatus == 0
    } catch {
        log("Failed to launch installer: \(error.localizedDescription)")
        return false
    }
}

// MARK: - Check Daemon Loaded
func checkDaemonLoaded(_ launchDaemonLabel: String) -> DaemonLoadStatus {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    task.arguments = ["list", launchDaemonLabel]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    
    do {
        try task.run()
        task.waitUntilExit()
        
        _ = pipe.fileHandleForReading.readDataToEndOfFile()
        pipe.fileHandleForReading.closeFile()
        
        // If exit code is 0, the daemon is loaded (whether running or not)
        if task.terminationStatus == 0 {
            return .loaded
        } else {
            return .notLoaded
        }
        
    } catch {
        return .error(error.localizedDescription)
    }
}

// check both main daemons
func checkIntuneomatorDaemons() -> (ondemand: DaemonLoadStatus, service: DaemonLoadStatus) {
    let ondemandStatus = checkDaemonLoaded("com.gilburns.intuneomator.ondemand")
    let serviceStatus = checkDaemonLoaded("com.gilburns.intuneomator.service")
    
    return (ondemand: ondemandStatus, service: serviceStatus)
}

// Helper function to get a simple boolean
func isDaemonLoaded(_ label: String) -> Bool {
    return checkDaemonLoaded(label) == .loaded
}


func checkAllDaemons() -> [String: String] {
    let daemonList = [
        "com.gilburns.intuneomator.automation",
        "com.gilburns.intuneomator.cachecleaner",
        "com.gilburns.intuneomator.labelupdater",
        "com.gilburns.intuneomator.ondemand",
        "com.gilburns.intuneomator.service",
        "com.gilburns.intuneomator.updatecheck"
    ]

    let daemonFolderURL = URL(fileURLWithPath: "/Library/LaunchDaemons")
    var fullDaemonStatus: [String: String] = [:]

    for daemon in daemonList {
        let daemonURL = daemonFolderURL.appendingPathComponent("\(daemon).plist")
        if FileManager.default.fileExists(atPath: daemonURL.path) {
            let daemonStatus = checkDaemonLoaded(daemon)
            fullDaemonStatus[daemon] = daemonStatus.description
        } else {
            fullDaemonStatus[daemon] = "Not Configured"
        }
    }
    return fullDaemonStatus
}


// MARK: - Main Execution

log("Starting update process")

//guard verifyParentProcessPath(expectedPath: expectedParentPath) else {
//    log("❌ Unauthorized caller: unexpected parent path.")
//    exit(EXIT_FAILURE)
//}

var callerPID: Int32 = -1

if let idx = CommandLine.arguments.firstIndex(of: "--caller-pid"),
   CommandLine.arguments.count > idx + 1,
   let pid = Int32(CommandLine.arguments[idx + 1]) {
    callerPID = pid
}

guard callerPID > 0, verifySignature(ofPID: callerPID, expectedTeamID: expectedTeamID) else {
    log("❌ Unauthorized caller or invalid Team ID.")
    exit(EXIT_FAILURE)
}

guard FileManager.default.fileExists(atPath: pkgPath) else {
    log("❌ Package not found at path: \(pkgPath)")
    exit(EXIT_FAILURE)
}

log("✅ Caller verified, proceeding with installation.")


var initialVersion: String = "unknown"
if let plist = NSDictionary(contentsOfFile: "/Applications/Intuneomator.app/Contents/Info.plist") {
   let bundleVersion = plist["CFBundleShortVersionString"] as? String
    initialVersion = bundleVersion ?? "unknown"
    log("Installed Intuneomator inital version: \(initialVersion)")
} else {
    log("⚠️ Could not determine installed Intuneomator version.")
}

// Install the already downloaded pkg file
let success = installPackage(at: pkgPath, target: targetVolume)

// 🧹 Cleanup
do {
    try FileManager.default.removeItem(atPath: pkgPath)
    log("🧹 Removed installer package at: \(pkgPath)")
} catch {
    log("⚠️ Failed to delete installer package: \(error.localizedDescription)")
}

if success {
    // 🔍 Check daemon status
    let allDaemons = checkAllDaemons()

    // 🔔 Teams Notification
    let sendTeamNotification = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false
    let sendForUpdates = ConfigManager.readPlistValue(key: "TeamsNotificationsForUpdates") == false

    if sendTeamNotification && sendForUpdates {
        let url = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""

        if url.isEmpty {
            log("No Teams Webhook URL set in Config. Not sending notification.")
        } else {
            let version = "unknown"
            if let plist = NSDictionary(contentsOfFile: "/Applications/Intuneomator.app/Contents/Info.plist"),
               let bundleVersion = plist["CFBundleShortVersionString"] as? String {
                log("Detected Intuneomator version: \(bundleVersion)")
                let teamsNotifier = TeamsNotifier(webhookURL: url)
                teamsNotifier.sendUpdateNotification(initialVersion: initialVersion, updatedVersion: bundleVersion, daemonStatus: allDaemons, isSuccess: success)
            } else {
                log("⚠️ Could not determine Intuneomator version.")
                let teamsNotifier = TeamsNotifier(webhookURL: url)
                teamsNotifier.sendUpdateNotification(initialVersion: initialVersion, updatedVersion: version, daemonStatus: allDaemons, isSuccess: success, errorMessage: "Unable to determine updated version.")
            }
        }
    }

    log("✅ Update installed successfully.")
    exit(EXIT_SUCCESS)
} else {
    log("❌ Update installation failed.")
    // 🔔 Teams Notification for failure
    let sendTeamNotification = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false

    if sendTeamNotification {
        let url = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""

        if url.isEmpty {
            log("No Teams Webhook URL set in Config. Not sending failure notification.")
        } else {
            let version = "unknown"
            if let plist = NSDictionary(contentsOfFile: "/Applications/Intuneomator.app/Contents/Info.plist"),
               let bundleVersion = plist["CFBundleShortVersionString"] as? String {
                log("Detected Intuneomator version: \(bundleVersion)")
                let teamsNotifier = TeamsNotifier(webhookURL: url)
                teamsNotifier.sendUpdateNotification(
                    initialVersion: initialVersion,
                    updatedVersion: bundleVersion,
                    daemonStatus: ["Daemons": "Unknown"],
                    isSuccess: false,
                    errorMessage: "Update installation failed unexpectedly."
                )
            } else {
                let teamsNotifier = TeamsNotifier(webhookURL: url)
                teamsNotifier.sendUpdateNotification(
                    initialVersion: initialVersion,
                    updatedVersion: version,
                    daemonStatus: ["Daemons": "Unknown"],
                    isSuccess: false,
                    errorMessage: "Update installation failed and version could not be determined."
                )
            }
        }
    }
    exit(EXIT_FAILURE)
}


enum DaemonLoadStatus: Equatable {
    case loaded
    case notLoaded
    case error(String)
    
    var description: String {
        switch self {
        case .loaded:
            return "Loaded"
        case .notLoaded:
            return "Not Loaded"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}
