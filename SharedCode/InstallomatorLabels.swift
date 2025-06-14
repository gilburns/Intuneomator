//
//  InstallomatorLabels.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/5/25.
//

import Foundation

// MARK: - Installomator Label Management

/// Manages Installomator label installation, updates, and version checking
/// Handles the 900+ application labels from the Installomator GitHub repository
class InstallomatorLabels {
    
    // MARK: - Version Management
    
    /// Compares local Installomator version with remote repository version (async)
    /// - Returns: Tuple indicating if local is current and version string or error message
    static func compareInstallomatorVersionAsync() async -> (Bool, String) {
        do {
            let installomatorCurrentVersionURL = URL(string: "https://raw.githubusercontent.com/Installomator/Installomator/refs/heads/main/Installomator.sh")!
            let installomatorLocalVersionPath = AppConstants.installomatorVersionFileURL.path

            // Fetch current version from GitHub
            let (data, _) = try await URLSession.shared.data(from: installomatorCurrentVersionURL)
            guard let content = String(data: data, encoding: .utf8) else {
                return (false, "Failed to decode web content")
            }

            // Extract VERSIONDATE from Installomator.sh script
            let regex = try NSRegularExpression(pattern: #"VERSIONDATE="([^"]*)"#)
            guard let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..<content.endIndex, in: content)),
                  let versionRange = Range(match.range(at: 1), in: content) else {
                return (false, "Failed to extract VERSIONDATE")
            }

            let installomatorCurrentVersion = content[versionRange]

            // Read local version file or use default
            let installomatorLocalVersion: String
            if FileManager.default.fileExists(atPath: installomatorLocalVersionPath) {
                installomatorLocalVersion = try String(contentsOfFile: installomatorLocalVersionPath).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                installomatorLocalVersion = "1990-01-01"
            }

            // Compare version dates
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            guard let currentVersionDate = dateFormatter.date(from: String(installomatorCurrentVersion)),
                  let localVersionDate = dateFormatter.date(from: installomatorLocalVersion) else {
                return (false, "Failed to parse version dates")
            }

            if currentVersionDate > localVersionDate {
                return (false, "New version available: \(installomatorCurrentVersion)")
            } else {
                return (true, "\(installomatorLocalVersion)")
            }
        } catch {
            return (false, "Error: \(error.localizedDescription)")
        }
    }

    /// Gets the locally installed Installomator version
    /// - Returns: Version string or fallback date if file doesn't exist
    static func getInstallomatorLocalVersion() -> String {
        do {
            let installomatorLocalVersionPath = AppConstants.installomatorVersionFileURL.path

            let installomatorLocalVersion: String
            if FileManager.default.fileExists(atPath: installomatorLocalVersionPath) {
                installomatorLocalVersion = try String(contentsOfFile: installomatorLocalVersionPath).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                installomatorLocalVersion = "1990-01-01"
            }

            return installomatorLocalVersion
        } catch {
            return "Failed to read version file"
        }
    }
    
    /// Compares Installomator versions using completion handler pattern
    /// - Parameter completion: Callback with (isUpToDate, versionOrError)
    static func compareInstallomatorVersion(completion: @escaping (Bool, String) -> Void) {
        Task {
            let result = await compareInstallomatorVersionAsync()
            completion(result.0, result.1)
        }
    }

    // MARK: - Label Installation and Updates
    
    /// Installs Installomator labels using completion handler pattern
    /// - Parameter completion: Callback with (success, versionOrError)
    static func installInstallomatorLabels(completion: @escaping (Bool, String) -> Void) {
        Task {
            let result = await installInstallomatorLabelsAsync()
            completion(result.0, result.1)
        }
    }

    /// Downloads and installs latest Installomator labels from GitHub (async)
    /// - Parameter withUpdatingLabels: Whether to update existing managed app labels
    /// - Returns: Tuple indicating success and version string or error message
    static func installInstallomatorLabelsAsync(withUpdatingLabels: Bool = true) async -> (Bool, String) {
        let tempDir = AppConstants.intuneomatorTempFolderURL
            .appendingPathComponent("\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(atPath: tempDir.path, withIntermediateDirectories: true, attributes: nil)

            // Get current main branch SHA for stable download
            let installomatorBranchURL = URL(string: "https://api.github.com/repos/Installomator/Installomator/branches/main")!
            let (data, _) = try await URLSession.shared.data(from: installomatorBranchURL)
            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let commit = json["commit"] as? [String: Any],
                  let sha = commit["sha"] as? String else {
                return (false, "Failed to fetch branch SHA")
            }

            // Download repository archive
            let installomatorURL = URL(string: "https://codeload.github.com/Installomator/Installomator/legacy.tar.gz/\(sha)")!
            let installomatorTarGz = tempDir.appendingPathComponent("Installomator.tar.gz")
            let (tarGzData, _) = try await URLSession.shared.data(from: installomatorURL)
            try tarGzData.write(to: installomatorTarGz)

            // Extract archive
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xzf", installomatorTarGz.path, "-C", tempDir.path]
            try process.run()
            process.waitUntilExit()

            // Find extracted directory
            guard let extractedDirName = try FileManager.default.contentsOfDirectory(atPath: tempDir.path).first(where: { $0.contains(sha.prefix(7)) }) else {
                return (false, "Failed to locate extracted directory")
            }

            // Copy labels from fragments/labels to local storage
            let extractedDirURL = tempDir.appendingPathComponent(extractedDirName)
            let sourceDirectory = extractedDirURL.appendingPathComponent("fragments").appendingPathComponent("labels")
            let destinationDirectory = AppConstants.installomatorLabelsFolderURL.path

            if FileManager.default.fileExists(atPath: destinationDirectory) {
                try FileManager.default.removeItem(atPath: destinationDirectory)
            }

            try FileManager.default.copyItem(atPath: sourceDirectory.path, toPath: destinationDirectory)

            // Extract and save version information
            let installomatorShPath = extractedDirURL.appendingPathComponent("Installomator.sh")
            
            let versionContent: String
            if FileManager.default.fileExists(atPath: installomatorShPath.path) {
                let shContent = try String(contentsOf: installomatorShPath)
                let regex = try NSRegularExpression(pattern: #"VERSIONDATE="([^"]*)"#)
                if let match = regex.firstMatch(in: shContent, options: [], range: NSRange(shContent.startIndex..<shContent.endIndex, in: shContent)),
                   let versionRange = Range(match.range(at: 1), in: shContent) {
                    versionContent = String(shContent[versionRange])
                } else {
                    versionContent = "1990-01-01"
                }
            } else {
                versionContent = "1990-01-01"
            }

            let versionFilePath = AppConstants.installomatorVersionFileURL.path
            try versionContent.write(toFile: versionFilePath, atomically: true, encoding: .utf8)

            // Clean up temporary files
            try FileManager.default.removeItem(atPath: tempDir.path)

            // Update labels for existing managed applications
            if withUpdatingLabels {
                _ = try await updateInUseLabels()
            }

            return (true, "\(versionContent)")
        } catch {
            return (false, "Error: \(error.localizedDescription)")
        }
    }

    /// Updates Installomator labels for currently managed applications
    /// Checks each managed app folder and updates its label script if newer version available
    /// - Returns: Array of label names that were updated
    /// - Throws: File system errors during update process
    static func updateInUseLabels() async throws -> [String] {
        let directoryContents = try FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: AppConstants.intuneomatorManagedTitlesFolderURL.path),
            includingPropertiesForKeys: nil
        )
        let subdirectories = directoryContents.filter { $0.hasDirectoryPath }

        var updatedLabels: [String] = []
        
        for subdir in subdirectories {
            let folderName = subdir.lastPathComponent

            // Skip folders that don't follow labelname_GUID pattern
            guard folderName.components(separatedBy: "_").count == 2 else {
                Logger.error("  Skipping folder: \(folderName)", category: .core)
                continue
            }
            
            let fileManager = FileManager.default
            let labelName = folderName.components(separatedBy: "_").first ?? "Unknown"
            
            // Check if using custom label (marked with .custom file)
            let labelCustomCheckURL = subdir.appendingPathComponent(".custom")
            
            let labelSourceFileURL: URL
            if fileManager.fileExists(atPath: labelCustomCheckURL.path) {
                // Use custom label from custom labels folder
                labelSourceFileURL = AppConstants.installomatorCustomLabelsFolderURL
                    .appendingPathComponent("\(labelName).sh")
            } else {
                // Use standard label from labels folder
                labelSourceFileURL = AppConstants.installomatorLabelsFolderURL
                    .appendingPathComponent("\(labelName).sh")
            }
            
            let labelDestinationFileURL = subdir.appendingPathComponent("\(labelName).sh")
            
            let sourceExists = fileManager.fileExists(atPath: labelSourceFileURL.path)
            let destinationExists = fileManager.fileExists(atPath: labelDestinationFileURL.path)

            // Update label if source and destination exist and content differs
            if sourceExists && destinationExists {
                let sourceContents = try String(contentsOfFile: labelSourceFileURL.path)
                let destinationContents = try String(contentsOfFile: labelDestinationFileURL.path)

                if sourceContents != destinationContents {
                    try fileManager.removeItem(atPath: labelDestinationFileURL.path)
                    try sourceContents.write(toFile: labelDestinationFileURL.path, atomically: true, encoding: .utf8)
                    updatedLabels += [labelName]
                }
            }
        }
        return updatedLabels
    }
}
