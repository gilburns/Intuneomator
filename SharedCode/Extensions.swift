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
