//
//  LogManagerUtil.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/6/25.
//

import Foundation

class LogManagerUtil {
    
    static func logFolderSizeInBytes(forLogFolder logType: String = "system") -> Int64 {
        let fileManager = FileManager.default
        let folderURL: URL
        switch logType {
        case "user":
            folderURL = AppConstants.intuneomatorLogApplicationURL
        default:
            folderURL = AppConstants.intuneomatorLogSystemURL
        }
        
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: nil) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if resourceValues.isRegularFile == true, let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            } catch {
                continue // Skip unreadable files
            }
        }

        return totalSize
    }

}



// Usage example:

/*
 
 Call:
 
 CacheCleaner.runCleanup()
 
 to perform both orphan cleanup and version trimming in sequence.

 */
