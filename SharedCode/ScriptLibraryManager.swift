//
//  ScriptLibraryManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/21/25.
//

import Foundation

// MARK: - Intuneomator PKG Script Library Management

/// Manages Intuneomator Script Library installation, updates, and version checking
/// Handles the scripts from the Intuneomator-PKGDeploymentScriptLibrary GitHub repository
class ScriptLibraryManager {
    
    // MARK: - Version Management
    
    /// Compares local Intuneomator Script Library version with remote repository version (async)
    /// - Returns: Tuple indicating if local is current, version string or error message, and SHA
    static func compareIntuneomatorScriptsVersionAsync() async -> (Bool, String, String) {
        do {
            let intuneomatorScriptsBranchURL = URL(string: "https://api.github.com/repos/gilburns/Intuneomator-PKGDeploymentScriptLibrary/branches/main")!
            let intuneomatorScriptsLocalVersionPath = AppConstants.intuneomatorScriptsVersionFileURL.path

            // Fetch current commit info from GitHub API
            let (data, _) = try await URLSession.shared.data(from: intuneomatorScriptsBranchURL)
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
            let intuneomatorScriptsLocalVersion: String
            let intuneomatorScriptsLocalSHA: String
            if FileManager.default.fileExists(atPath: intuneomatorScriptsLocalVersionPath) {
                let jsonData = try Data(contentsOf: URL(fileURLWithPath: intuneomatorScriptsLocalVersionPath))
                if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String],
                   let date = json["date"],
                   let sha = json["sha"] {
                    // Extract just the date part from ISO 8601 format
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    if let parsedDate = dateFormatter.date(from: date) {
                        let outputFormatter = DateFormatter()
                        outputFormatter.dateFormat = "yyyy-MM-dd"
                        intuneomatorScriptsLocalVersion = outputFormatter.string(from: parsedDate)
                    } else {
                        intuneomatorScriptsLocalVersion = date.components(separatedBy: "T").first ?? "1990-01-01"
                    }
                    intuneomatorScriptsLocalSHA = sha
                } else {
                    intuneomatorScriptsLocalVersion = "1990-01-01"
                    intuneomatorScriptsLocalSHA = "unknown"
                }
            } else {
                intuneomatorScriptsLocalVersion = "1990-01-01"
                intuneomatorScriptsLocalSHA = "unknown"
            }

            // Compare SHA values directly
            if remoteSHA != intuneomatorScriptsLocalSHA {
                return (false, "New version available: \(remoteDisplayDate)", remoteSHA)
            } else {
                return (true, "\(intuneomatorScriptsLocalVersion)", intuneomatorScriptsLocalSHA)
            }
        } catch {
            return (false, "Error: \(error.localizedDescription)", "unknown")
        }
    }

    /// Gets the locally installed Intuneomator Script Library version
    /// - Returns: Version string or fallback date if file doesn't exist
    static func getIntuneomatorScriptsLocalVersion() -> (String, String) {
        let (version, sha) = getIntuneomatorScriptsLocalVersionWithSHA()
        return (version, sha)
    }
    
    /// Gets the locally installed Intuneomator Script Library version and SHA
    /// - Returns: Tuple with (version string, SHA) or fallback values if file doesn't exist
    static func getIntuneomatorScriptsLocalVersionWithSHA() -> (String, String) {
        do {
            let intuneomatorScriptsLocalVersionPath = AppConstants.intuneomatorScriptsVersionFileURL.path

            let intuneomatorScriptsLocalVersion: String
            let intuneomatorScriptsLocalSHA: String
            if FileManager.default.fileExists(atPath: intuneomatorScriptsLocalVersionPath) {
                let jsonData = try Data(contentsOf: URL(fileURLWithPath: intuneomatorScriptsLocalVersionPath))
                if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String],
                   let date = json["date"],
                   let sha = json["sha"] {
                    // Extract just the date part from ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ -> YYYY-MM-DD)
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    if let parsedDate = dateFormatter.date(from: date) {
                        let outputFormatter = DateFormatter()
                        outputFormatter.dateFormat = "yyyy-MM-dd"
                        intuneomatorScriptsLocalVersion = outputFormatter.string(from: parsedDate)
                    } else {
                        intuneomatorScriptsLocalVersion = date.components(separatedBy: "T").first ?? "1990-01-01"
                    }
                    intuneomatorScriptsLocalSHA = sha
                } else {
                    intuneomatorScriptsLocalVersion = "1990-01-01"
                    intuneomatorScriptsLocalSHA = "unknown"
                }
            } else {
                intuneomatorScriptsLocalVersion = "1990-01-01"
                intuneomatorScriptsLocalSHA = "unknown"
            }

            return (intuneomatorScriptsLocalVersion, intuneomatorScriptsLocalSHA)
        } catch {
            return ("Failed to read version file", "unknown")
        }
    }
    
    /// Compares Intuneomator Script Library versions using completion handler pattern
    /// - Parameter completion: Callback with (isUpToDate, versionOrError, sha)
    static func compareIntuneomatorScriptVersion(completion: @escaping (Bool, String, String) -> Void) {
        Task {
            let result = await compareIntuneomatorScriptsVersionAsync()
            completion(result.0, result.1, result.2)
        }
    }

    // MARK: - Script Library Installation and Updates
    
    /// Installs Intuneomator Script Library using completion handler pattern
    /// - Parameter completion: Callback with (success, versionOrError)
    static func installIntuneomatorScripts(completion: @escaping (Bool, String) -> Void) {
        Task {
            let result = await installIntuneomatorScriptsAsync()
            completion(result.0, result.1)
        }
    }

    /// Downloads and installs latest Intuneomator Script Library from GitHub (async)
    /// - Parameter withUpdatingLabels: Whether to update existing managed app labels
    /// - Returns: Tuple indicating success and version string or error message
    static func installIntuneomatorScriptsAsync(withUpdatingLabels: Bool = true) async -> (Bool, String) {
        let tempDir = AppConstants.intuneomatorTempFolderURL
            .appendingPathComponent("\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(atPath: tempDir.path, withIntermediateDirectories: true, attributes: nil)

            // Get current main branch SHA for stable download
            let intuneomatorBranchURL = URL(string: "https://api.github.com/repos/gilburns/Intuneomator-PKGDeploymentScriptLibrary/branches/main")!
            let (data, _) = try await URLSession.shared.data(from: intuneomatorBranchURL)
            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let commit = json["commit"] as? [String: Any],
                  let sha = commit["sha"] as? String,
                  let commitInfo = commit["commit"] as? [String: Any],
                  let author = commitInfo["author"] as? [String: Any],
                  let commitDate = author["date"] as? String else {
                return (false, "Failed to fetch branch SHA and commit info")
            }

            // Download repository archive
            let intuneomatorURL = URL(string: "https://codeload.github.com/gilburns/Intuneomator-PKGDeploymentScriptLibrary/legacy.tar.gz/\(sha)")!
            let intuneomatorTarGz = tempDir.appendingPathComponent("Intuneomator-PKGDeploymentScriptLibrary.tar.gz")
            let (tarGzData, _) = try await URLSession.shared.data(from: intuneomatorURL)
            try tarGzData.write(to: intuneomatorTarGz)

            // Extract archive
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xzf", intuneomatorTarGz.path, "-C", tempDir.path]
            try process.run()
            process.waitUntilExit()

            // Find extracted directory
            guard let extractedDirName = try FileManager.default.contentsOfDirectory(atPath: tempDir.path).first(where: { $0.contains(sha.prefix(7)) }) else {
                return (false, "Failed to locate extracted directory")
            }

            // Copy labels from fragments/labels to local storage
            let extractedDirURL = tempDir.appendingPathComponent(extractedDirName)
            let sourcePreinstallDirectory = extractedDirURL.appendingPathComponent("Preinstall")
            let destinationPreDirectory = AppConstants.intuneomatorScriptsURL.appending(component: "Pre").path

            if FileManager.default.fileExists(atPath: destinationPreDirectory) {
                try FileManager.default.removeItem(atPath: destinationPreDirectory)
            }
            try FileManager.default.copyItem(atPath: sourcePreinstallDirectory.path, toPath: destinationPreDirectory)

            let sourcePostinstallDirectory = extractedDirURL.appendingPathComponent("Postinstall")
            let destinationPostDirectory = AppConstants.intuneomatorScriptsURL.appending(component: "Post").path

            if FileManager.default.fileExists(atPath: destinationPostDirectory) {
                try FileManager.default.removeItem(atPath: destinationPostDirectory)
            }
            try FileManager.default.copyItem(atPath: sourcePostinstallDirectory.path, toPath: destinationPostDirectory)

            // Create version JSON with commit information
            let versionInfo: [String: String] = [
                "date": commitDate,
                "sha": sha
            ]
            
            let versionJsonData = try JSONSerialization.data(withJSONObject: versionInfo, options: .prettyPrinted)
            let versionFilePath = AppConstants.intuneomatorScriptsVersionFileURL.path
            try versionJsonData.write(to: URL(fileURLWithPath: versionFilePath))

            // Clean up temporary files
            try FileManager.default.removeItem(atPath: tempDir.path)

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
}
