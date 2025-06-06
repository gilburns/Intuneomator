//
//  AppInspector.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/8/25.
//

import Foundation

/// Inspects macOS application bundles to extract metadata from Info.plist files
/// Provides methods for extracting bundle identifiers, versions, and system requirements
class AppInspector {
    
    /// Inspects an application bundle and extracts essential metadata
    /// - Parameters:
    ///   - location: URL path to the .app bundle to inspect
    ///   - completion: Callback with result containing (bundleID, version, minOSVersion) or error
    func inspect(appAt location: URL, completion: @escaping (Result<(String, String, String), Error>) -> Void) {
        let infoPlistPath = location.appendingPathComponent("Contents/Info.plist")
        
        guard FileManager.default.fileExists(atPath: infoPlistPath.path) else {
            completion(.failure(NSError(domain: "AppInspector", code: 404, userInfo: [NSLocalizedDescriptionKey: "Info.plist not found"])))
            return
        }
        
        do {
            let plistData = try Data(contentsOf: infoPlistPath)
            let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any]
            
            guard let bundleID = plist?["CFBundleIdentifier"] as? String,
                  let version = plist?["CFBundleShortVersionString"] as? String  else {
                throw NSError(domain: "AppInspector", code: 1, userInfo: [NSLocalizedDescriptionKey: "Required keys not found in Info.plist"])
            }
            
            let minOSVersion = plist?["LSMinimumSystemVersion"] as? String ?? "Unknown"
                        
            completion(.success((bundleID, version, minOSVersion)))
        } catch {
            completion(.failure(error))
        }
    }
    
    
    /// Extracts the version string from an application bundle with bundle ID validation
    /// - Parameters:
    ///   - expectedBundleID: Expected bundle identifier to validate against
    ///   - location: URL path to the .app bundle to inspect
    ///   - completion: Callback with version string if bundle ID matches, nil if no match, or error
    func getVersion(forBundleID expectedBundleID: String, inAppAt location: URL, completion: @escaping (Result<String?, Error>) -> Void) {
        // Reuse the existing inspect function to get the bundle ID and version
        inspect(appAt: location) { result in
            switch result {
            case .success(let bundleIDVersionPair):
                let (bundleID, version, _) = bundleIDVersionPair
                
                // Check if the bundle ID matches the expected one
                if bundleID == expectedBundleID {
                    // Return the version if it matches
                    completion(.success(version))
                } else {
                    // Bundle ID doesn't match the expected one
                    completion(.success(nil))
                }
            case .failure(let error):
                // Pass through any errors from the inspect function
                completion(.failure(error))
            }
        }
    }

}
