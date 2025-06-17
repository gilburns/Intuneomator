//
//  VersionInfo.swift
//  IntuneomatorServices
//
//  Provides version information for the daemon services
//

import Foundation

/// Utility class for accessing daemon version information
struct VersionInfo {
    
    // MARK: - Version Constants (Update when preparing a release)
    private static let DAEMON_VERSION = "1.0.0"
    private static let DAEMON_BUILD = "164"
    
    /// Gets the current daemon version information
    /// - Returns: Tuple containing version and build strings
    static func getVersionInfo() -> (version: String, build: String) {
        // Try to read from Bundle first (works for GUI apps)
        let bundleVersion = Bundle.main.appVersion
        let bundleBuild = Bundle.main.buildNumber
        
        // If Bundle has the actual values (not defaults), use them
        if !bundleVersion.isEmpty && bundleVersion != "Unknown" {
            return (bundleVersion, bundleBuild != "Unknown" ? bundleBuild : DAEMON_BUILD)
        }
        
        // Use version constants for command-line tools
        return (DAEMON_VERSION, DAEMON_BUILD)
    }
    
    /// Gets the full version string in format "version.build"
    /// - Returns: Formatted version string (e.g., "1.0.0.173")
    static func getVersionString() -> String {
        let (version, build) = getVersionInfo()
        return "\(version).\(build)"
    }
    
    /// Gets the application name
    /// - Returns: Application name or "IntuneomatorService" if bundle name is empty
    static func getAppName() -> String {
        return Bundle.main.appName.isEmpty ? "IntuneomatorService" : Bundle.main.appName
    }
    
    /// Gets a formatted display string with app name and version
    /// - Returns: Formatted string (e.g., "IntuneomatorService v1.0.0.173")
    static func getDisplayString() -> String {
        let name = getAppName()
        let versionString = getVersionString()
        return "\(name) v\(versionString)"
    }
}
