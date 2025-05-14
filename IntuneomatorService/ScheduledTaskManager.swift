//
//  ScheduledTaskManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

class ScheduledTaskManager {

    static func configureScheduledTask(
        label: String,
        argument: String,
        schedules: [(weekday: Int?, hour: Int, minute: Int)],
        associatedBundleID: String = "com.gilburns.Intuneomator",
        completion: @escaping (Bool, String?) -> Void
    ) {
        let fileManager = FileManager.default
        let daemonPath = "/Library/LaunchDaemons/\(label).plist"
        let binaryPath = "/Library/Application Support/Intuneomator/IntuneomatorService"

        var plistDict: [String: Any] = [
            "Label": label,
            "ProgramArguments": [binaryPath, argument],
            "RunAtLoad": true,
            "StandardOutPath": "/var/log/\(label).out.log",
            "StandardErrorPath": "/var/log/\(label).err.log",
            "AssociatedBundleIdentifiers": associatedBundleID
        ]

        // Build StartCalendarInterval
        let scheduleArray: [[String: Int]] = schedules.map { entry in
            var dict: [String: Int] = ["Hour": entry.hour, "Minute": entry.minute]
            if let weekday = entry.weekday {
                dict["Weekday"] = weekday
            }
            return dict
        }
        plistDict["StartCalendarInterval"] = scheduleArray

        // Serialize the plist
        do {
            let plistData = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
            let plistURL = URL(fileURLWithPath: daemonPath)

            // If already exists, unload it first
            if fileManager.fileExists(atPath: daemonPath) {
                _ = try? runShellCommand(["launchctl", "unload", daemonPath])
            }

            try plistData.write(to: plistURL)
            try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: daemonPath)
            try fileManager.setAttributes([.ownerAccountID: 0, .groupOwnerAccountID: 0], ofItemAtPath: daemonPath)

            // Load the new daemon
            let result = try runShellCommand(["launchctl", "load", daemonPath])
            completion(true, result)
        } catch {
            completion(false, "Failed to configure task: \(error.localizedDescription)")
        }
    }
    
    static func removeScheduledTask(
        label: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let daemonPath = "/Library/LaunchDaemons/\(label).plist"
        let fileManager = FileManager.default

        do {
            if fileManager.fileExists(atPath: daemonPath) {
                _ = try? runShellCommand(["launchctl", "unload", daemonPath])
                try fileManager.removeItem(atPath: daemonPath)
                completion(true, "Task \(label) removed successfully.")
            } else {
                completion(false, "Task plist not found.")
            }
        } catch {
            completion(false, "Failed to remove task: \(error.localizedDescription)")
        }
    }
    
    static func taskExists(label: String) -> Bool {
        let daemonPath = "/Library/LaunchDaemons/\(label).plist"
        return FileManager.default.fileExists(atPath: daemonPath)
    }
    

    @discardableResult
    private static func runShellCommand(_ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
