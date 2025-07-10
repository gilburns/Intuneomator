//
//  PkgInspector.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/8/25.
//

import Foundation

/// Inspects macOS installer packages (.pkg) to extract metadata and bundle information
/// Supports both distribution packages and component packages with comprehensive bundle analysis
class PkgInspector {
    
    /// Inspects a package file and extracts all identifier and version pairs from metadata and bundles
    /// - Parameters:
    ///   - location: URL path to the .pkg file to inspect
    ///   - completion: Callback with array of (identifier, version) tuples or error
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
            }
            
//            else {
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
    
    /// Parses a Distribution XML file to extract package references with IDs and versions
    /// - Parameter xml: XML content of the Distribution file
    /// - Returns: Array of (identifier, version) tuples from pkg-ref elements
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
    
    /// Parses a PackageInfo XML file to extract package identifier and version
    /// - Parameter xml: XML content of the PackageInfo file
    /// - Returns: Array of (identifier, version) tuples from pkg-info elements
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
    
    /// Recursively searches for application and framework bundles within a directory
    /// - Parameter directory: Directory URL to search for bundles
    /// - Returns: Array of URLs pointing to found .app and .framework bundles
    private func findBundles(in directory: URL) -> [URL] {
        let fileManager = FileManager.default
        var bundleURLs: [URL] = []
        
        // Enhanced recursive search with more comprehensive directory traversal
        func searchDirectory(_ searchURL: URL, depth: Int = 0) {
            // Prevent infinite recursion by limiting search depth
            guard depth < 20 else { return }
            
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: searchURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                    options: [.skipsHiddenFiles]
                )
                
                for fileURL in contents {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    
                    // Check if this is a bundle we're looking for
                    if resourceValues.isDirectory == true {
                        let pathExtension = fileURL.pathExtension.lowercased()
                        if pathExtension == "app" || pathExtension == "framework" {
                            bundleURLs.append(fileURL)
                            // Don't recurse into found bundles to avoid finding nested bundles
                            continue
                        }
                    }
                    
                    // Recurse into directories (but not symbolic links to avoid loops)
                    if resourceValues.isDirectory == true && resourceValues.isSymbolicLink != true {
                        searchDirectory(fileURL, depth: depth + 1)
                    }
                }
            } catch {
                print("Error reading directory \(searchURL.path): \(error)")
            }
        }
        
        // Start the recursive search
        searchDirectory(directory)
        
        return bundleURLs
    }
    
    /// Extracts bundle identifier and version from an application or framework bundle
    /// Handles both .app bundles and .framework bundles with their different Info.plist locations
    /// - Parameter bundleURL: URL path to the bundle to inspect
    /// - Returns: Tuple of (bundleIdentifier, version) or nil if extraction fails
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
    
    /// Extracts the version for a specific package identifier from a .pkg file
    /// - Parameters:
    ///   - packageID: The specific package identifier to search for
    ///   - location: URL path to the .pkg file to inspect
    ///   - completion: Callback with version string if found, nil if not found, or error
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
