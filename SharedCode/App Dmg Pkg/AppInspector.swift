//
//  AppInspector.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/8/25.
//

import Foundation

class AppInspector {
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
            
//            Logger.log("Bundle ID found: \(bundleID)", logType: "AppInspector")
//            Logger.log(String(format: "Version found: %@ (minimum OS: %@)", version, minOSVersion), logType: "AppInspector")
            
            completion(.success((bundleID, version, minOSVersion)))
        } catch {
            completion(.failure(error))
        }
    }
    
    
    /// Inspects a `.app` file to extract the version for a specific package ID.
    /// - Parameters:
    ///   - forBundleID: Expected ID of the `.app` file to inspect.
    ///   - inAppAt: URL of the app bundle.
    ///   - completion: A closure that returns the result containing the version string or an error.
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
