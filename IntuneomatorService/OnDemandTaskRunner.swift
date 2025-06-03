//
//  OnDemandTaskRunner.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/18/25.
//

import Foundation

class OnDemandTaskRunner {
    static let idleWaitTime: TimeInterval = 5.0
    static let maxIdleIterations = 5 // 5 * 5 = 25 seconds idle
    
    static let logType = "OnDemandTaskRunner"

    static func start() async {
        let queueDirectory = AppConstants.intuneomatorOndemandTriggerURL
        let managedTitlesDirectory = AppConstants.intuneomatorManagedTitlesFolderURL

        var idleCount = 0

        while idleCount < maxIdleIterations {
            let allFiles = (try? FileManager.default.contentsOfDirectory(at: queueDirectory, includingPropertiesForKeys: nil)) ?? []

            var triggerFiles: [URL] = []

            for file in allFiles {
                let name = file.lastPathComponent
                if name.hasSuffix(".trigger") {
                    triggerFiles.append(file)
                } else {
                    Logger.log("Removing unexpected file: \(name)", logType: logType)
                    try? FileManager.default.removeItem(at: file)
                }
            }

            if triggerFiles.isEmpty {
                idleCount += 1
                Logger.log("Idle count: \(idleCount)", logType: logType)
                try? await Task.sleep(nanoseconds: UInt64(idleWaitTime * 1_000_000_000))
                continue
            }

            idleCount = 0

            for file in triggerFiles {
                let folderName = file.deletingPathExtension().lastPathComponent
                Logger.log("Processing touch file: \(folderName)", logType: logType)
                let folderPath = managedTitlesDirectory.appendingPathComponent(folderName)

                guard FileManager.default.fileExists(atPath: folderPath.path, isDirectory: nil) else {
                    Logger.log("Skipping nonexistent folder: \(folderName)", logType: logType)
                    try? FileManager.default.removeItem(at: file)
                    continue
                }

                do {
                    Logger.log("Processing: \(folderName)", logType: logType)
                    let processingResult = await LabelAutomation.processFolder(named: folderName)
                    Logger.log("Finished: \(folderName): \(processingResult)", logType: logType)
                    try FileManager.default.removeItem(at: file)
                } catch {
                    Logger.log("Error processing \(folderName): \(error.localizedDescription)", logType: logType)
                }
            }
        }

        Logger.log("No more files to process. Exiting.", logType: logType)
    }
}
