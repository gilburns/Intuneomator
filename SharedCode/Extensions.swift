//
//  Extensions.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/4/25.
//

import Foundation
import AppKit
import UniformTypeIdentifiers


// MARK: - Notifications
// Extensions for improved readability
extension Notification.Name {
    static let customLabelToggled = Notification.Name("customLabelToggled")
    static let labelWindowWillClose = Notification.Name("labelWindowWillClose")
    static let mainWindowDidLoad = Notification.Name("mainWindowDidLoad")
    static let newDirectoryAdded = Notification.Name("newDirectoryAdded")
    static let labelEditCompleted = Notification.Name("labelEditCompleted")
    static let labelDeleteCompleted = Notification.Name("labelDeleteCompleted")
    static let categoryManagerDidUpdateCategories = Notification.Name("categoryManagerDidUpdateCategories")
}

// MARK: - base64URLEncodedString encoding
extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Bundle Extension
extension Bundle {
    
    var appName: String {
        if let name = self.infoDictionary?["CFBundleName"] as? String {
            return name
        } else {
            return ""
        }
    }
    
//    static var appName: String {
//        if let name = Bundle.main.infoDictionary?["CFBundleName"] as? String {
//            return name
//        } else {
//            print("Unable to determine 'appName'")
//            return ""
//        }
//    }
    
    static var appVersionMarketing: String {
        if let name = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return name
        } else {
            return ""
        }
    }
    
    static var appVersionBuild: String {
        let bundleKey = kCFBundleVersionKey as String
        if let version = Bundle.main.object(forInfoDictionaryKey: bundleKey) as? String {
            return version
        } else {
            return "0"
        }
    }
    
    static var copyrightHumanReadable: String {
        if let name = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String {
            return name
        } else {
            return ""
        }
    }
    
    var appVersion: String {
        if let version = self.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        } else {
            return ""
        }
    }

//    static var appVersion: String {
//        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
//            return version
//        } else {
//            print("Unable to determine 'appVersion'")
//            return ""
//        }
//    }
    
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

}

extension NSImage {
    /// Resize the image to the specified size
    func resized(to size: NSSize) -> NSImage? {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        defer { newImage.unlockFocus() }
        
        self.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .sourceOver,
                  fraction: 1.0)
        return newImage
    }
}


// MARK: - Import File Type .p12
extension UTType {
    public static let p12 = UTType(importedAs: "com.gilburns.Intuneomator.p12")
}

// MARK: - String Extensions for Date Formatting

extension String {
    
    /// Formats an Intune ISO 8601 date string into a human-readable format
    /// - Returns: Formatted date string (e.g., "July 9, 2025 at 3:06 PM") or original string if parsing fails
    func formatIntuneDate() -> String {
        // Return empty string if input is empty
        guard !self.isEmpty else { return "" }
        
        // Create ISO 8601 date formatter for parsing Intune dates
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Try parsing with fractional seconds first, then without
        var date: Date?
        if let parsedDate = isoFormatter.date(from: self) {
            date = parsedDate
        } else {
            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: self)
        }
        
        guard let validDate = date else {
            // If parsing fails, return the original string
            return self
        }
        
        // Create a user-friendly date formatter
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .long
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale.current
        
        return displayFormatter.string(from: validDate)
    }
    
    /// Formats an Intune ISO 8601 date string into a compact format
    /// - Returns: Compact date string (e.g., "7/9/25, 3:06 PM") or original string if parsing fails
    func formatIntuneDateCompact() -> String {
        // Return empty string if input is empty
        guard !self.isEmpty else { return "" }
        
        // Create ISO 8601 date formatter for parsing Intune dates
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Try parsing with fractional seconds first, then without
        var date: Date?
        if let parsedDate = isoFormatter.date(from: self) {
            date = parsedDate
        } else {
            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: self)
        }
        
        guard let validDate = date else {
            // If parsing fails, return the original string
            return self
        }
        
        // Create a compact date formatter
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale.current
        
        return displayFormatter.string(from: validDate)
    }
}

// MARK: - Date Extensions

extension Date {
    
    /// Formats a Date into the standard Intune display format
    /// - Returns: Formatted date string (e.g., "July 9, 2025 at 3:06 PM")
    func formatForIntuneDisplay() -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .long
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale.current
        
        return displayFormatter.string(from: self)
    }
    
    /// Formats a Date into a compact Intune display format
    /// - Returns: Compact date string (e.g., "7/9/25, 3:06 PM")
    func formatForIntuneDisplayCompact() -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale.current
        
        return displayFormatter.string(from: self)
    }
}
