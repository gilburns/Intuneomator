//
//  LabelAutomation+Download.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

/// Extension providing download functionality for the LabelAutomation system
/// Handles downloading application files from remote URLs with retry logic,
/// proper error handling, and filename extraction from various sources
extension LabelAutomation {
    
    // MARK: - Constants
    
    /// Maximum number of retry attempts for failed downloads
    private static let maxDownloadRetries = 3
    
    /// Base delay in seconds for exponential backoff between retries
    private static let baseRetryDelay: UInt64 = 1
    
    /// Default file extension for downloads when none can be determined
    private static let defaultFileExtension = "dmg"
    
    // MARK: - Download Errors
    
    /// Errors that can occur during the download process
    enum DownloadError: LocalizedError {
        case invalidURL(String)
        case networkError(Int, String)
        case invalidResponse
        case fileSystemError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL(let url):
                return "Invalid download URL: \(url)"
            case .networkError(let code, let message):
                return "Network error (\(code)): \(message)"
            case .invalidResponse:
                return "Invalid response from server"
            case .fileSystemError(let message):
                return "File system error: \(message)"
            }
        }
    }
    
    // MARK: - Download File
    
    /// Downloads an application file from a remote URL with retry logic and proper error handling
    /// 
    /// This function handles the complete download process including:
    /// - URL validation and architecture-specific selection
    /// - Retry logic with exponential backoff for failed downloads
    /// - HTTP response validation
    /// - Filename extraction from Content-Disposition headers or URL paths
    /// - Temporary file management and cleanup
    /// - Real-time progress tracking via StatusNotificationManager
    /// 
    /// - Parameters:
    ///   - folderName: The folder name containing the GUID suffix for the managed app
    ///   - processedAppResults: Contains app metadata including download URLs and version info
    ///   - downloadArch: Target architecture ("Arm" for ARM64, "Intel" for x86_64)
    ///   - operationId: Optional operation ID for status tracking
    /// - Returns: URL pointing to the downloaded file in the temporary cache directory
    /// - Throws: DownloadError for various failure scenarios including invalid URLs, network errors, and file system issues
    static func downloadFile(for folderName: String, processedAppResults: ProcessedAppResults, downloadArch: String = "Arm", operationId: String? = nil) async throws -> URL {
        
        // Select appropriate download URL based on architecture
        let urlString = downloadArch == "Arm" ? processedAppResults.appDownloadURL : processedAppResults.appDownloadURLx86
        
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL(urlString)
        }
        
        Logger.info("  Starting download from \(url.absoluteString)", category: .automation)
        
        let labelName = folderName.components(separatedBy: "_").first ?? folderName
        
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(labelName)
            .appendingPathComponent("tmp")
        
        
        // Create a temporary directory for the download
        let downloadsDir = downloadFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        } catch {
            throw DownloadError.fileSystemError("Failed to create download directory: \(error.localizedDescription)")
        }
        
        // Download the file with retry logic and exponential backoff
        var tempLocation: URL
        var response: URLResponse
        var attempt = 0
        
        while true {
            do {
                // Use custom download with progress tracking if operation ID is provided
                if let operationId = operationId {
                    let progressDelegate = DownloadProgressDelegate(operationId: operationId, downloadURL: url.absoluteString)
                    let session = URLSession(configuration: .default, delegate: progressDelegate, delegateQueue: nil)
                    (tempLocation, response) = try await session.download(from: url)
                } else {
                    (tempLocation, response) = try await URLSession.shared.download(from: url)
                }
                break
            } catch {
                attempt += 1
                if attempt > maxDownloadRetries {
                    // Clean up temporary directory on final failure
                    try? FileManager.default.removeItem(at: downloadsDir)
                    throw error
                }
                Logger.warning("Download failed (attempt \(attempt)/\(maxDownloadRetries)), retrying...", category: .automation)
                // Exponential backoff: wait 2^(attempt-1) * baseRetryDelay seconds
                let delayNanoseconds = UInt64(pow(2.0, Double(attempt - 1))) * baseRetryDelay * 1_000_000_000
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }
        }
        
        // Validate the HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            try? FileManager.default.removeItem(at: downloadsDir)
            throw DownloadError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            try? FileManager.default.removeItem(at: downloadsDir)
            throw DownloadError.networkError(httpResponse.statusCode, "Server returned status code \(httpResponse.statusCode)")
        }
        
        // Extract filename from various sources with fallback logic
        let finalFilename = extractDownloadFilename(
            from: response,
            fallbackURL: url,
            appDisplayName: processedAppResults.appDisplayName,
            appVersion: processedAppResults.appVersionExpected
        )
        
        let destinationURL = downloadsDir
            .appendingPathComponent(finalFilename)
        
        // Remove existing file if present and move downloaded file to destination
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
                Logger.info("🗑️ Removed existing file: \(destinationURL.path)", category: .automation)
            }
            
            try FileManager.default.moveItem(at: tempLocation, to: destinationURL)
        } catch {
            try? FileManager.default.removeItem(at: downloadsDir)
            throw DownloadError.fileSystemError("Failed to move downloaded file: \(error.localizedDescription)")
        }
        
        // Log download completion details
        logDownloadFileInfo(forLabel: labelName, destinationURL: destinationURL, finalFilename: finalFilename, finalURL: response.url ?? url)
        
        Logger.info("  Download complete: \(finalFilename)", category: .automation)
        Logger.info("  Downloaded to: \(destinationURL.path)", category: .automation)
        
        
        return destinationURL
    }
    
    // MARK: - Private Helper Methods
    
    /// Extracts the filename for a downloaded file using multiple fallback strategies
    /// 
    /// Attempts to determine the filename in the following order:
    /// 1. URL path component (with percent encoding removed)
    /// 2. Content-Disposition header from HTTP response
    /// 3. Constructed filename using app display name and version
    /// 
    /// - Parameters:
    ///   - response: The URLResponse from the download request
    ///   - fallbackURL: The original download URL to use as fallback
    ///   - appDisplayName: The application display name for constructed filenames
    ///   - appVersion: The application version for constructed filenames
    /// - Returns: A valid filename string for the downloaded file
    private static func extractDownloadFilename(from response: URLResponse, fallbackURL: URL, appDisplayName: String, appVersion: String) -> String {
        let finalURL = response.url ?? fallbackURL
        
        // Try to get filename from URL path
        if let lastComponent = finalURL.lastPathComponent.removingPercentEncoding,
           !lastComponent.isEmpty && lastComponent != "/" {
            return lastComponent
        }
        
        // Try to extract from Content-Disposition header
        if let httpResponse = response as? HTTPURLResponse,
           let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition"),
           let filename = extractFilename(from: contentDisposition) {
            return filename
        }
        
        // Fallback: construct filename from app metadata
        let fileExtension = finalURL.pathExtension.isEmpty ? defaultFileExtension : finalURL.pathExtension
        return "\(appDisplayName)_\(appVersion).\(fileExtension)"
    }
    
    /// Extracts filename from HTTP Content-Disposition header
    /// 
    /// Supports various Content-Disposition formats including:
    /// - attachment; filename="example.pkg"
    /// - attachment; filename=example.pkg
    /// - attachment; filename*=UTF-8''example.pkg
    /// 
    /// - Parameter contentDisposition: The Content-Disposition header value
    /// - Returns: The extracted filename, or nil if extraction fails
    private static func extractFilename(from contentDisposition: String) -> String? {
        // Look for format: filename="example.pkg" or filename=example.pkg
        let pattern = #"filename\*?=(?:UTF-8'')?"?([^"\s;]+)"?"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: contentDisposition, options: [], range: NSRange(contentDisposition.startIndex..., in: contentDisposition)),
           let range = Range(match.range(at: 1), in: contentDisposition) {
            let filename = String(contentDisposition[range])
            // Decode percent-encoded characters if present
            return filename.removingPercentEncoding ?? filename
        }
        
        return nil
    }
    

}

// MARK: - Download Progress Tracking

/// Custom URLSessionDownloadDelegate for tracking download progress
/// Provides real-time progress updates via StatusNotificationManager
class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let operationId: String
    private let downloadURL: String
    private let statusManager = StatusNotificationManager.shared
    
    init(operationId: String, downloadURL: String) {
        self.operationId = operationId
        self.downloadURL = downloadURL
        super.init()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // Update download progress via StatusNotificationManager
        if totalBytesExpectedToWrite > 0 {
            statusManager.updateDownloadProgress(
                operationId: operationId,
                downloadedBytes: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite,
                downloadURL: downloadURL
            )
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Download completed - the file handling is done in the main function
        Logger.debug("Download completed for operation \(operationId)", category: .automation)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Logger.error("Download failed for operation \(operationId): \(error.localizedDescription)", category: .automation)
        }
    }
}
