//
//  ApplicationIconExporter.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/23/25.
//

import Foundation
import CoreServices
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics
import CoreFoundation

class IconExporter {
    
    static private let logType = "IconExporter"
    
    /// Saves an application icon to the specified path as a PNG file.
    /// - Parameter path: The destination file path.
    /// - Returns: `true` if the operation succeeded, `false` otherwise.
    static func extractAppIcon(appPath: String, outputPath: String) -> Bool {
        let plistPath = "\(appPath)/Contents/Info.plist"
        
        guard let plist = NSDictionary(contentsOfFile: plistPath),
              var iconName = plist["CFBundleIconFile"] as? String else {
            Logger.log("❌ Failed to read CFBundleIconFile from Info.plist", logType: logType)
            return false
        }
        
        // Ensure the icon file has .icns extension
        if !iconName.hasSuffix(".icns") {
            iconName += ".icns"
        }
        
        let icnsPath = "\(appPath)/Contents/Resources/\(iconName)"
        
        guard FileManager.default.fileExists(atPath: icnsPath) else {
            Logger.log("❌ .icns file not found at path: \(icnsPath)", logType: logType)
            return false
        }
        
        // Use `sips` to convert to PNG
        let process = Process()
        process.launchPath = "/usr/bin/sips"
        process.arguments = ["-s", "format", "png", icnsPath, "--out", outputPath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                Logger.log("✅ Icon converted successfully to: \(outputPath)", logType: logType)
                return true
            } else {
                Logger.log("❌ sips failed with exit code: \(process.terminationStatus)", logType: logType)
                return false
            }
        } catch {
            Logger.log("❌ Failed to run sips: \(error)", logType: logType)
            return false
        }
    }
    
    
    /// Saves the generic application icon to the specified path as a PNG file.
    /// - Parameter path: The destination file path.
    /// - Returns: `true` if the operation succeeded, `false` otherwise.
    static func saveGenericAppIcon(to path: String) -> Bool {
        let iconPath = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"
        let iconURL = URL(fileURLWithPath: iconPath)
        
        guard let imageSource = CGImageSourceCreateWithURL(iconURL as CFURL, nil) else {
            Logger.log("❌ Failed to create image source.", logType: logType)
            return false
        }

        // Find the largest available image representation
        let imageCount = CGImageSourceGetCount(imageSource)
        var largestImage: CGImage?
        var largestSize: CGFloat = 0

        for index in 0..<imageCount {
            if let image = CGImageSourceCreateImageAtIndex(imageSource, index, nil) {
                let size = CGFloat(image.width * image.height)
                if size > largestSize {
                    largestSize = size
                    largestImage = image
                }
            }
        }

        guard let finalImage = largestImage else {
            Logger.log("❌ Failed to extract image from icon.", logType: logType)
            return false
        }

        let outputURL = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            Logger.log("❌ Failed to create image destination.", logType: logType)
            return false
        }

        CGImageDestinationAddImage(destination, finalImage, nil)
        if CGImageDestinationFinalize(destination) {
            Logger.log("✅ Saved generic app icon to \(path)", logType: logType)
            return true
        } else {
            Logger.log("❌ Failed to write PNG file.", logType: logType)
            return false
        }
    }
    
    
    static func getCGImageFromPath(fileImagePath: String) -> CGImage? {
        let fileURL = URL(fileURLWithPath: fileImagePath)
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            Logger.log("Failed to create image source from path: \(fileImagePath)", logType: logType)
            return nil
        }

        let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        if cgImage == nil {
            Logger.log("Failed to create CGImage from source.", logType: logType)
        }

        return cgImage
    }
    
    
    static func saveCGImageAsPNG(_ image: CGImage, to path: String) {
        let fileURL = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            Logger.log("Failed to create image destination.", logType: logType)
            return
        }

        CGImageDestinationAddImage(destination, image, nil)

        if !CGImageDestinationFinalize(destination) {
            Logger.log("Failed to finalize image destination.", logType: logType)
        }
    }
    
}

// Example Usage:
/*
 
 let success = IconExporter.extractAppIcon(
     appPath: "/Applications/Safari.app",
     outputPath: "/tmp/safari_icon.png"
 )

 */


// Example Usage:
/*
 
 import Foundation

 // Call the class method
 let outputPath = "/Users/yourname/Desktop/generic_app_icon.png"
 let success = IconExporter.saveIcon(to: outputPath)
 print("Export status: \(success ? "Success" : "Failure")")
 
 */


// Example Usage:

/*
 
 if let cgImage = getCGImageFromPath(fileImagePath: url.path) {
     saveCGImageAsPNG(cgImage, to: iconDestinationPath)
 }
 
 */
