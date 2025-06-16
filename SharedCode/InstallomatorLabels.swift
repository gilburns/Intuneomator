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
    /// - Returns: Tuple indicating if local is current, version string or error message, and SHA
    static func compareInstallomatorVersionAsync() async -> (Bool, String, String) {
        do {
            let installomatorBranchURL = URL(string: "https://api.github.com/repos/Installomator/Installomator/branches/main")!
            let installomatorLocalVersionPath = AppConstants.installomatorVersionFileURL.path

            // Fetch current commit info from GitHub API
            let (data, _) = try await URLSession.shared.data(from: installomatorBranchURL)
            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let commit = json["commit"] as? [String: Any],
                  let remoteSHA = commit["sha"] as? String,
                  let commitInfo = commit["commit"] as? [String: Any],
                  let author = commitInfo["author"] as? [String: Any],
                  let remoteCommitDate = author["date"] as? String else {
                return (false, "Failed to fetch remote commit info", "unknown")
            }

            // Format the remote commit date for display
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            let remoteDisplayDate: String
            if let parsedDate = dateFormatter.date(from: remoteCommitDate) {
                let outputFormatter = DateFormatter()
                outputFormatter.dateFormat = "yyyy-MM-dd"
                remoteDisplayDate = outputFormatter.string(from: parsedDate)
            } else {
                remoteDisplayDate = remoteCommitDate.components(separatedBy: "T").first ?? remoteCommitDate
            }

            // Read local version file or use default
            let installomatorLocalVersion: String
            let installomatorLocalSHA: String
            if FileManager.default.fileExists(atPath: installomatorLocalVersionPath) {
                let jsonData = try Data(contentsOf: URL(fileURLWithPath: installomatorLocalVersionPath))
                if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String],
                   let date = json["date"],
                   let sha = json["sha"] {
                    // Extract just the date part from ISO 8601 format
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    if let parsedDate = dateFormatter.date(from: date) {
                        let outputFormatter = DateFormatter()
                        outputFormatter.dateFormat = "yyyy-MM-dd"
                        installomatorLocalVersion = outputFormatter.string(from: parsedDate)
                    } else {
                        installomatorLocalVersion = date.components(separatedBy: "T").first ?? "1990-01-01"
                    }
                    installomatorLocalSHA = sha
                } else {
                    installomatorLocalVersion = "1990-01-01"
                    installomatorLocalSHA = "unknown"
                }
            } else {
                installomatorLocalVersion = "1990-01-01"
                installomatorLocalSHA = "unknown"
            }

            // Compare SHA values directly
            if remoteSHA != installomatorLocalSHA {
                return (false, "New version available: \(remoteDisplayDate)", remoteSHA)
            } else {
                return (true, "\(installomatorLocalVersion)", installomatorLocalSHA)
            }
        } catch {
            return (false, "Error: \(error.localizedDescription)", "unknown")
        }
    }

    /// Gets the locally installed Installomator version
    /// - Returns: Version string or fallback date if file doesn't exist
    static func getInstallomatorLocalVersion() -> String {
        let (version, _) = getInstallomatorLocalVersionWithSHA()
        return version
    }
    
    /// Gets the locally installed Installomator version and SHA
    /// - Returns: Tuple with (version string, SHA) or fallback values if file doesn't exist
    static func getInstallomatorLocalVersionWithSHA() -> (String, String) {
        do {
            let installomatorLocalVersionPath = AppConstants.installomatorVersionFileURL.path

            let installomatorLocalVersion: String
            let installomatorLocalSHA: String
            if FileManager.default.fileExists(atPath: installomatorLocalVersionPath) {
                let jsonData = try Data(contentsOf: URL(fileURLWithPath: installomatorLocalVersionPath))
                if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String],
                   let date = json["date"],
                   let sha = json["sha"] {
                    // Extract just the date part from ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ -> YYYY-MM-DD)
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    if let parsedDate = dateFormatter.date(from: date) {
                        let outputFormatter = DateFormatter()
                        outputFormatter.dateFormat = "yyyy-MM-dd"
                        installomatorLocalVersion = outputFormatter.string(from: parsedDate)
                    } else {
                        installomatorLocalVersion = date.components(separatedBy: "T").first ?? "1990-01-01"
                    }
                    installomatorLocalSHA = sha
                } else {
                    installomatorLocalVersion = "1990-01-01"
                    installomatorLocalSHA = "unknown"
                }
            } else {
                installomatorLocalVersion = "1990-01-01"
                installomatorLocalSHA = "unknown"
            }

            return (installomatorLocalVersion, installomatorLocalSHA)
        } catch {
            return ("Failed to read version file", "unknown")
        }
    }
    
    /// Compares Installomator versions using completion handler pattern
    /// - Parameter completion: Callback with (isUpToDate, versionOrError, sha)
    static func compareInstallomatorVersion(completion: @escaping (Bool, String, String) -> Void) {
        Task {
            let result = await compareInstallomatorVersionAsync()
            completion(result.0, result.1, result.2)
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
                  let sha = commit["sha"] as? String,
                  let commitInfo = commit["commit"] as? [String: Any],
                  let author = commitInfo["author"] as? [String: Any],
                  let commitDate = author["date"] as? String else {
                return (false, "Failed to fetch branch SHA and commit info")
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

            // Create version JSON with commit information
            let versionInfo: [String: String] = [
                "date": commitDate,
                "sha": sha
            ]
            
            let versionJsonData = try JSONSerialization.data(withJSONObject: versionInfo, options: .prettyPrinted)
            let versionFilePath = AppConstants.installomatorVersionFileURL.path
            try versionJsonData.write(to: URL(fileURLWithPath: versionFilePath))

            // Clean up temporary files
            try FileManager.default.removeItem(atPath: tempDir.path)

            // Update labels for existing managed applications
            if withUpdatingLabels {
                _ = try await updateInUseLabels()
            }

            // Format the commit date to match expected format (YYYY-MM-DD)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            let formattedDate: String
            if let parsedDate = dateFormatter.date(from: commitDate) {
                let outputFormatter = DateFormatter()
                outputFormatter.dateFormat = "yyyy-MM-dd"
                formattedDate = outputFormatter.string(from: parsedDate)
            } else {
                formattedDate = commitDate.components(separatedBy: "T").first ?? "1990-01-01"
            }
            
            return (true, "\(formattedDate)")
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
