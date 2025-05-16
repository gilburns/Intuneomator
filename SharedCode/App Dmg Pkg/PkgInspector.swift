//
//  PkgInspector.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/8/25.
//

import Foundation

class PkgInspector {
    /// Inspects a `.pkg` file to extract all `id` and `version` values from `Distribution` or `PackageInfo`.
    /// - Parameters:
    ///   - pkgAt: The URL of the `.pkg` file to inspect.
    ///   - completion: A closure that returns the result containing an array of `(id, version)` or an error.
    func inspect(pkgAt location: URL, completion: @escaping (Result<[(String, String)], Error>) -> Void) {
        let tempDir = location.deletingLastPathComponent()
        let tempExpandedDir = tempDir
            .appendingPathComponent("expanded_pkg")
        
        do {
            
            // Expand the `.pkg` file
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/pkgutil")
            process.arguments = ["--expand-full", location.path, tempExpandedDir.path]
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw NSError(domain: "PkgInspector", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to expand pkg"])
            }
            
            // Look for metadata files: Distribution or PackageInfo
            let distributionPath = tempExpandedDir.appendingPathComponent("Distribution")
            let packageInfoPath = tempExpandedDir.appendingPathComponent("PackageInfo")
            var items: [(String, String)] = []
            
            if FileManager.default.fileExists(atPath: distributionPath.path) {
                // Parse `Distribution` file
                let distributionXML = try String(contentsOf: distributionPath, encoding: .utf8)
                items = parseDistributionXML(distributionXML)
            } else if FileManager.default.fileExists(atPath: packageInfoPath.path) {
                // Parse `PackageInfo` file
                let packageInfoXML = try String(contentsOf: packageInfoPath, encoding: .utf8)
                items = parsePackageInfoXML(packageInfoXML)
            } //else {
            //                throw NSError(domain: "PkgInspector", code: 404, userInfo: [NSLocalizedDescriptionKey: "No valid metadata file found in the pkg"])
            //            }
            
            // Find and inspect all .app and .framework bundles
            let bundleURLs = findBundles(in: tempExpandedDir)
            for bundleURL in bundleURLs {
                if let bundleInfo = extractBundleInfo(from: bundleURL) {
                    items.append(bundleInfo)
                }
            }
            
            if items.isEmpty {
                throw NSError(domain: "PkgInspector", code: 404, userInfo: [NSLocalizedDescriptionKey: "No valid metadata found in the pkg"])
            }
            
            
            // Return the results
            completion(.success(items))
        } catch {
            // Cleanup on failure
            try? FileManager.default.removeItem(at: tempExpandedDir)
            completion(.failure(error))
        }
    }
    
    /// Parses a `Distribution` XML file for `id` and `version`.
    private func parseDistributionXML(_ xml: String) -> [(String, String)] {
        var items: [(String, String)] = []
        let regex = try! NSRegularExpression(pattern: #"<pkg-ref.*?id="(.*?)".*?version="(.*?)".*?>"#, options: [])
        let matches = regex.matches(in: xml, range: NSRange(location: 0, length: xml.utf16.count))
        
        for match in matches {
            if let idRange = Range(match.range(at: 1), in: xml),
               let versionRange = Range(match.range(at: 2), in: xml) {
                let id = String(xml[idRange])
                let version = String(xml[versionRange])
                items.append((id, version))
            }
        }
        return items
    }
    
    /// Parses a `PackageInfo` XML file for `id` and `version`.
    private func parsePackageInfoXML(_ xml: String) -> [(String, String)] {
        var items: [(String, String)] = []
        let regex = try! NSRegularExpression(pattern: #"<pkg-info.*?identifier="(.*?)".*?version="(.*?)".*?>"#, options: [])
        let matches = regex.matches(in: xml, range: NSRange(location: 0, length: xml.utf16.count))
        
        for match in matches {
            if let idRange = Range(match.range(at: 1), in: xml),
               let versionRange = Range(match.range(at: 2), in: xml) {
                let id = String(xml[idRange])
                let version = String(xml[versionRange])
                items.append((id, version))
            }
        }
        return items
    }
    
    /// Recursively finds all `.app` and `.framework` bundles in a directory.
    private func findBundles(in directory: URL) -> [URL] {
        let fileManager = FileManager.default
        var bundleURLs: [URL] = []
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    let pathExtension = fileURL.pathExtension.lowercased()
                    if pathExtension == "app" || pathExtension == "framework" {
                        bundleURLs.append(fileURL)
                    }
                }
            } catch {
                print("Error reading resource values: \(error)")
            }
        }
        
        print("Bundle URLs: \(bundleURLs)")
        
        return bundleURLs
    }
    
    /// Extracts bundle identifier and version from a bundle's Info.plist.
    private func extractBundleInfo(from bundleURL: URL) -> (String, String)? {
        let fileManager = FileManager.default
        var infoPlistURL: URL?
        
        // Check bundle type
        let pathExtension = bundleURL.pathExtension.lowercased()
        
        if pathExtension == "app" {
            // For .app bundles, check standard macOS location
            infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        } else if pathExtension == "framework" {
            // For .framework bundles, try the standard Resources symlink path
            let resourcesPath = bundleURL.appendingPathComponent("Resources/Info.plist")
            
            if fileManager.fileExists(atPath: resourcesPath.path) {
                infoPlistURL = resourcesPath
            } else {
                // If not in Resources, try the versioned structure
                // First check for Current version
                let currentVersionPath = bundleURL.appendingPathComponent("Versions/Current/Resources/Info.plist")
                if fileManager.fileExists(atPath: currentVersionPath.path) {
                    infoPlistURL = currentVersionPath
                } else {
                    // Try version A directly
                    let versionAPath = bundleURL.appendingPathComponent("Versions/A/Resources/Info.plist")
                    if fileManager.fileExists(atPath: versionAPath.path) {
                        infoPlistURL = versionAPath
                    }
                }
            }
        }
        
        guard let plistURL = infoPlistURL, fileManager.fileExists(atPath: plistURL.path) else {
            return nil
        }
        
        do {
            let infoPlistData = try Data(contentsOf: plistURL)
            if let plist = try PropertyListSerialization.propertyList(
                from: infoPlistData,
                options: [],
                format: nil
            ) as? [String: Any],
               let bundleID = plist["CFBundleIdentifier"] as? String,
               let version = plist["CFBundleShortVersionString"] as? String {
                return (bundleID, version)
            }
        } catch {
            print("Error reading Info.plist at \(plistURL.path): \(error)")
        }
        
        return nil
    }
}

extension PkgInspector {
    /// Inspects a `.pkg` file to extract the version for a specific package ID.
    /// - Parameters:
    ///   - pkgAt: The URL of the `.pkg` file to inspect.
    ///   - packageID: The specific package ID to find.
    ///   - completion: A closure that returns the result containing the version string or an error.
    func getVersion(forPackageID packageID: String, inPkgAt location: URL, completion: @escaping (Result<String?, Error>) -> Void) {
        // Reuse the existing inspect function to get all ID/version pairs
        inspect(pkgAt: location) { result in
            switch result {
            case .success(let idVersionPairs):
                // Find the matching package ID
                if let matchingPair = idVersionPairs.first(where: { $0.0 == packageID }) {
                    // Return the version associated with the matching ID
                    completion(.success(matchingPair.1))
                } else {
                    // Package ID not found in the pkg
                    completion(.success(nil))
                }
            case .failure(let error):
                // Pass through any errors from the inspect function
                completion(.failure(error))
            }
        }
    }
}
