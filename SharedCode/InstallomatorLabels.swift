//
//  InstallomatorLabels.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/5/25.
//

import Foundation

class InstallomatorLabels {
    // Async version for CLI use
    static func compareInstallomatorVersionAsync() async -> (Bool, String) {
        do {
            let installomatorCurrentVersionURL = URL(string: "https://raw.githubusercontent.com/Installomator/Installomator/refs/heads/main/Installomator.sh")!
            let installomatorLocalVersionPath = AppConstants.installomatorVersionFileURL.path

            let (data, _) = try await URLSession.shared.data(from: installomatorCurrentVersionURL)
            guard let content = String(data: data, encoding: .utf8) else {
                return (false, "Failed to decode web content")
            }

            let regex = try NSRegularExpression(pattern: #"VERSIONDATE="([^"]*)"#)
            guard let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..<content.endIndex, in: content)),
                  let versionRange = Range(match.range(at: 1), in: content) else {
                return (false, "Failed to extract VERSIONDATE")
            }

            let installomatorCurrentVersion = content[versionRange]

            let installomatorLocalVersion: String
            if FileManager.default.fileExists(atPath: installomatorLocalVersionPath) {
                installomatorLocalVersion = try String(contentsOfFile: installomatorLocalVersionPath).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                installomatorLocalVersion = "1990-01-01"
            }

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

    static func getInstallomatorLocalVersion() -> String {
        
        let installomatorLocalVersionPath = AppConstants.installomatorVersionFileURL.path

        var installomatorLocalVersion: String
        do {
            if FileManager.default.fileExists(atPath: installomatorLocalVersionPath) {
                installomatorLocalVersion = try String(contentsOfFile: installomatorLocalVersionPath).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                installomatorLocalVersion = "1990-01-01"
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            guard let localVersionDate = dateFormatter.date(from: installomatorLocalVersion) else {
                return ""
            }
            installomatorLocalVersion = "\(localVersionDate)"
        } catch {
            return ""
        }
        return installomatorLocalVersion
    }
    
    static func compareInstallomatorVersion(completion: @escaping (Bool, String) -> Void) {
        Task {
            let result = await compareInstallomatorVersionAsync()
            completion(result.0, result.1)
        }
    }

    static func installInstallomatorLabels(completion: @escaping (Bool, String) -> Void) {
        Task {
            let result = await installInstallomatorLabelsAsync()
            completion(result.0, result.1)
        }
    }

    // Async version for CLI use
    static func installInstallomatorLabelsAsync(withUpdatingLabels: Bool = true) async -> (Bool, String) {
        let tempDir = AppConstants.intuneomatorTempFolderURL
            .appendingPathComponent("\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(atPath: tempDir.path, withIntermediateDirectories: true, attributes: nil)

            let installomatorBranchURL = URL(string: "https://api.github.com/repos/Installomator/Installomator/branches/main")!
            let (data, _) = try await URLSession.shared.data(from: installomatorBranchURL)
            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let commit = json["commit"] as? [String: Any],
                  let sha = commit["sha"] as? String else {
                return (false, "Failed to fetch branch SHA")
            }

            let installomatorURL = URL(string: "https://codeload.github.com/Installomator/Installomator/legacy.tar.gz/\(sha)")!
            let installomatorTarGz = tempDir.appendingPathComponent("Installomator.tar.gz")
            let (tarGzData, _) = try await URLSession.shared.data(from: installomatorURL)
            try tarGzData.write(to: installomatorTarGz)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xzf", installomatorTarGz.path, "-C", tempDir.path]
            try process.run()
            process.waitUntilExit()

            guard let extractedDirName = try FileManager.default.contentsOfDirectory(atPath: tempDir.path).first(where: { $0.contains(sha.prefix(7)) }) else {
                return (false, "Failed to locate extracted directory")
            }

            let extractedDirURL = tempDir.appendingPathComponent(extractedDirName)
            let sourceDirectory = extractedDirURL.appendingPathComponent("fragments").appendingPathComponent("labels")
            let destinationDirectory = AppConstants.installomatorLabelsFolderURL.path

            if FileManager.default.fileExists(atPath: destinationDirectory) {
                try FileManager.default.removeItem(atPath: destinationDirectory)
            }

            try FileManager.default.copyItem(atPath: sourceDirectory.path, toPath: destinationDirectory)

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

            try FileManager.default.removeItem(atPath: tempDir.path)

            if withUpdatingLabels {
                _ = try await updateInUseLabels()
            }

            return (true, "\(versionContent)")
        } catch {
            return (false, "Error: \(error.localizedDescription)")
        }
    }

    static func updateInUseLabels() async throws -> [String] {
        let directoryContents = try FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: AppConstants.intuneomatorManagedTitlesFolderURL.path),
            includingPropertiesForKeys: nil
        )
        let subdirectories = directoryContents.filter { $0.hasDirectoryPath }

        var updatedLabels: [String] = []
        
        for subdir in subdirectories {
            
            let folderName = subdir.lastPathComponent

            guard folderName.components(separatedBy: "_").count == 2 else {
                Logger.log ("  Skipping folder: \(folderName)", logType: "info")
                return []
            }
            
            let fileManager = FileManager.default

            let labelName = folderName.components(separatedBy: "_").first ?? "Unknown"
            
            // Check to see if the label is using a custom one.
            let labelCustomCheckURL = subdir
                .appendingPathComponent(".custom")
            
            let labelSourceFileURL: URL
            
            if fileManager.fileExists(atPath: labelCustomCheckURL.path) {
                labelSourceFileURL = AppConstants.installomatorCustomLabelsFolderURL
                    .appendingPathComponent("\(labelName).sh")
            } else {
                labelSourceFileURL = AppConstants.installomatorLabelsFolderURL
                    .appendingPathComponent("\(labelName).sh")
            }
            
            let labelDestinationFileURL = subdir
                .appendingPathComponent("\(labelName).sh")
            
            let sourceExists = fileManager.fileExists(atPath: labelSourceFileURL.path)
            let destinationExists = fileManager.fileExists(atPath: labelDestinationFileURL.path)

            
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
