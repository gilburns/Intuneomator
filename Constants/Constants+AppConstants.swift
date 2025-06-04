//
//  Constants+AppConstants.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

struct AppConstants {
    
    static let currentPid: Int32 = ProcessInfo.processInfo.processIdentifier
    static let randomGUID = UUID().uuidString

    static let intuneomatorFolderURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .localDomainMask).first!
        .appendingPathComponent("Intuneomator")
    
    static let intuneomatorCacheFolderURL = intuneomatorFolderURL
        .appendingPathComponent("Cache")

    static let installomatorFolderURL = intuneomatorFolderURL
        .appendingPathComponent("Installomator")

    static let installomatorLabelsFolderURL = installomatorFolderURL
        .appendingPathComponent("Labels")

    static let installomatorCustomLabelsFolderURL = installomatorFolderURL
        .appendingPathComponent("Custom")

    static let intuneomatorManagedTitlesFolderURL = intuneomatorFolderURL
        .appendingPathComponent("ManagedTitles")

    static let intuneomatorOndemandTriggerURL = intuneomatorFolderURL
        .appendingPathComponent("ondemandQueue")

    static let intuneomatorServiceFileURL = intuneomatorFolderURL
        .appendingPathComponent("IntuneomatorService.plist")

    static let installomatorVersionFileURL = installomatorFolderURL
        .appendingPathComponent("Version.txt")
    
    static let intuneomatorTempFolderURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("Intuneomator_\(currentPid)_\((randomGUID)[(randomGUID).startIndex..<(randomGUID).index((randomGUID).startIndex, offsetBy: 8)])")
    
    static let intuneomatorLogSystemURL = FileManager.default.urls(for: .libraryDirectory, in: .localDomainMask).first!
        .appendingPathComponent("Logs")
        .appendingPathComponent("Intuneomator")

    static let intuneomatorLogApplicationURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Logs")
        .appendingPathComponent("Intuneomator")

}

