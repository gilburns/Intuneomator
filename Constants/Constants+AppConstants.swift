//
//  Constants+AppConstants.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

/// Constants for file paths and directories used throughout the Intuneomator application
struct AppConstants {
    
    /// Current process identifier for creating unique temporary folders
    static let currentPid: Int32 = ProcessInfo.processInfo.processIdentifier
    
    /// Random 8-character hex string for creating unique temporary folders
    static let randomGUID = String(format: "%08X", arc4random())

    /// Main Intuneomator data directory in system Application Support
    /// Location: /Library/Application Support/Intuneomator
    static let intuneomatorFolderURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .localDomainMask).first!
        .appendingPathComponent("Intuneomator")
    
    /// Cache directory for temporary files and downloads
    /// Location: /Library/Application Support/Intuneomator/Cache
    static let intuneomatorCacheFolderURL = intuneomatorFolderURL
        .appendingPathComponent("Cache")

    /// Installomator base directory
    /// Location: /Library/Application Support/Intuneomator/Installomator
    static let installomatorFolderURL = intuneomatorFolderURL
        .appendingPathComponent("Installomator")

    /// Directory containing Installomator label files
    /// Location: /Library/Application Support/Intuneomator/Installomator/Labels
    static let installomatorLabelsFolderURL = installomatorFolderURL
        .appendingPathComponent("Labels")

    /// Directory containing custom Installomator label files
    /// Location: /Library/Application Support/Intuneomator/Installomator/Custom
    static let installomatorCustomLabelsFolderURL = installomatorFolderURL
        .appendingPathComponent("Custom")

    /// Directory for managed application titles and metadata
    /// Location: /Library/Application Support/Intuneomator/ManagedTitles
    static let intuneomatorManagedTitlesFolderURL = intuneomatorFolderURL
        .appendingPathComponent("ManagedTitles")

    /// Directory used to trigger on-demand automation tasks
    /// Location: /Library/Application Support/Intuneomator/ondemandQueue
    static let intuneomatorOndemandTriggerURL = intuneomatorFolderURL
        .appendingPathComponent("ondemandQueue")

    /// Directory used to store on-going automation download and upload statistics
    /// Location: /Library/Application Support/Intuneomator/Stats
    static let intuneomatorUpDownStatsURL = intuneomatorFolderURL
        .appendingPathComponent("Stats")

    /// Configuration file for the Intuneomator service
    /// Location: /Library/Application Support/Intuneomator/IntuneomatorService.plist
    static let intuneomatorServiceFileURL = intuneomatorFolderURL
        .appendingPathComponent("IntuneomatorService.plist")

    /// File containing the current Installomator version
    /// Location: /Library/Application Support/Intuneomator/Installomator/Version.txt
    static let installomatorVersionFileURL = installomatorFolderURL
        .appendingPathComponent("Version.txt")
    
    /// Unique temporary directory for the current process
    /// Location: /tmp/Intuneomator_{pid}_{guid8}
    static let intuneomatorTempFolderURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("Intuneomator_\(currentPid)_\(randomGUID)")
    
    /// System-wide log directory for Intuneomator
    /// Location: /Library/Logs/Intuneomator
    static let intuneomatorLogSystemURL = FileManager.default.urls(for: .libraryDirectory, in: .localDomainMask).first!
        .appendingPathComponent("Logs")
        .appendingPathComponent("Intuneomator")

    /// User-specific log directory for Intuneomator
    /// Location: ~/Library/Logs/Intuneomator
    static let intuneomatorLogApplicationURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Logs")
        .appendingPathComponent("Intuneomator")

}

