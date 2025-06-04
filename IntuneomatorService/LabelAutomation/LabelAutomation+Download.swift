//
//  LabelAutomation+Download.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

extension LabelAutomation {
    
    // MARK: - Download File
    static func downloadFile(for folderName: String, processedAppResults: ProcessedAppResults, downloadArch: String = "Arm") async throws -> URL {
        
        var url: URL
        
        if downloadArch == "Arm" {
            guard let urlForArch = URL(string: processedAppResults.appDownloadURL) else {
                throw NSError(domain: "InvalidURL", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL provided"])
            }
            url = urlForArch
        } else {
            guard let urlForArch = URL(string: processedAppResults.appDownloadURLx86) else {
                throw NSError(domain: "InvalidURL", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL provided"])
            }
            url = urlForArch
        }
        
        Logger.log("  Starting download from \(String(describing: url))", logType: logType)
        
        let labelName = folderName.components(separatedBy: "_").first ?? folderName
        
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(labelName)
            .appendingPathComponent("tmp")
        
        
        // Create a temporary directory for the download
        let downloadsDir = downloadFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        
        // Download the file
        let (tempLocation, response) = try await URLSession.shared.download(from: url)
        
        // Validate the response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NetworkError", code: 101, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
        }
        
        // Try to extract filename from Content-Disposition header
        var finalFilename: String
        let finalURL = response.url ?? url
        if let lastComponent = finalURL.lastPathComponent.removingPercentEncoding,
           !lastComponent.isEmpty {
            finalFilename = lastComponent
        } else if let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition"),
                  let filename = extractFilename(from: contentDisposition) {
            finalFilename = filename
        } else {
            // Fallback if both URL and Content-Disposition failed
            let ext = finalURL.pathExtension.isEmpty ? "dmg" : finalURL.pathExtension
            finalFilename = "\(processedAppResults.appDisplayName)_\(processedAppResults.appVersionExpected).\(ext)"
        }
        
        let destinationURL = downloadsDir
            .appendingPathComponent(finalFilename)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
            Logger.log("🗑️ Removed existing file: \(destinationURL.path)", logType: logType)
        }
        
        // Move the file to temp destination
        try FileManager.default.moveItem(at: tempLocation, to: destinationURL)
        
        // Log Download
        logDownloadFileInfo(forLabel: labelName, destinationURL: destinationURL, finalFilename: finalFilename, finalURL: finalURL)
        
        Logger.log("  Download complete: \(finalFilename)", logType: logType)
        Logger.log("  Downloaded to: \(destinationURL.path)", logType: logType)
        
        
        return destinationURL
    }
    
    // file name from the Content Disposition
    private static func extractFilename(from contentDisposition: String) -> String? {
        // Look for format: attachment; filename="example.pkg"
        let pattern = #"filename="?([^"]+)"?"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: contentDisposition, options: [], range: NSRange(contentDisposition.startIndex..., in: contentDisposition)),
           let range = Range(match.range(at: 1), in: contentDisposition) {
            return String(contentDisposition[range])
        }
        return nil
    }
    

}
