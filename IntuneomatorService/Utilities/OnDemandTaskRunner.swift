//
//  OnDemandTaskRunner.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/18/25.
//

import Foundation

/// Monitors and processes on-demand automation tasks triggered by file creation
/// Watches for .trigger files in the queue directory and processes corresponding managed title folders
class OnDemandTaskRunner {
    /// Time to wait between queue checks when no tasks are found
    static let idleWaitTime: TimeInterval = 5.0
    
    /// Maximum number of idle iterations before terminating (25 seconds total)
    static let maxIdleIterations = 5 // 5 * 5 = 25 seconds idle
    

    /// Starts the on-demand task runner that monitors for trigger files and processes automation tasks
    /// Runs continuously until no tasks are found for the maximum idle period
    /// Processes .trigger files by running LabelAutomation on corresponding managed title folders
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
                    Logger.info("Removing unexpected file: \(name)", category: .core)
                    try? FileManager.default.removeItem(at: file)
                }
            }

            if triggerFiles.isEmpty {
                idleCount += 1
                Logger.info("Idle count: \(idleCount)", category: .core)
                try? await Task.sleep(nanoseconds: UInt64(idleWaitTime * 1_000_000_000))
                continue
            }

            idleCount = 0

            for file in triggerFiles {
                let folderName = file.deletingPathExtension().lastPathComponent
                Logger.info("Processing touch file: \(folderName)", category: .core)
                let folderPath = managedTitlesDirectory.appendingPathComponent(folderName)

                guard FileManager.default.fileExists(atPath: folderPath.path, isDirectory: nil) else {
                    Logger.info("Skipping nonexistent folder: \(folderName)", category: .core)
                    try? FileManager.default.removeItem(at: file)
                    continue
                }

                do {
                    Logger.info("Processing: \(folderName)", category: .core)
                    let processingResult = await LabelAutomation.processFolder(named: folderName)
                    Logger.info("Finished: \(folderName): \(processingResult)", category: .core)
                    try FileManager.default.removeItem(at: file)
                } catch {
                    Logger.error("Error processing \(folderName): \(error.localizedDescription)", category: .core)
                }
            }
        }

        Logger.info("No more files to process. Exiting.", category: .core)
    }
}
