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

/// Utility class for extracting and converting application icons from macOS applications.
/// This class provides functionality to extract icons from .app bundles, convert between formats,
/// and handle fallback scenarios using system-provided generic icons. Supports both custom
/// application icons and system fallbacks for consistent icon availability.
class IconExporter {
    
    static private let logType = "IconExporter"
    
    /// Extracts an application icon from a macOS .app bundle and saves it as a PNG file.
    /// 
    /// Reads the application's Info.plist to locate the icon file, finds the corresponding
    /// .icns file in the Resources directory, and converts it to PNG format using the system's
    /// `sips` utility. Handles icon name normalization and file existence validation.
    /// 
    /// - Parameters:
    ///   - appPath: The full path to the .app bundle (e.g., "/Applications/Safari.app")
    ///   - outputPath: The destination file path for the converted PNG icon
    /// - Returns: `true` if the extraction and conversion succeeded, `false` otherwise
    /// 
    /// **Process Flow:**
    /// 1. Reads CFBundleIconFile from the app's Info.plist
    /// 2. Ensures the icon filename has .icns extension
    /// 3. Locates the icon file in Contents/Resources/
    /// 4. Uses `sips` command-line tool to convert ICNS to PNG
    /// 5. Validates conversion success via process exit code
    /// 
    /// **Error Handling:**
    /// - Returns false if Info.plist cannot be read
    /// - Returns false if CFBundleIconFile key is missing
    /// - Returns false if .icns file doesn't exist
    /// - Returns false if `sips` conversion fails
    static func extractAppIcon(appPath: String, outputPath: String) -> Bool {
        let plistPath = "\(appPath)/Contents/Info.plist"
        
        // Read application's Info.plist to locate icon file name
        guard let plist = NSDictionary(contentsOfFile: plistPath),
              var iconName = plist["CFBundleIconFile"] as? String else {
            Logger.log("❌ Failed to read CFBundleIconFile from Info.plist", logType: logType)
            return false
        }
        
        // Ensure the icon file has .icns extension (some apps omit it in plist)
        if !iconName.hasSuffix(".icns") {
            iconName += ".icns"
        }
        
        let icnsPath = "\(appPath)/Contents/Resources/\(iconName)"
        
        // Verify the icon file exists before attempting conversion
        guard FileManager.default.fileExists(atPath: icnsPath) else {
            Logger.log("❌ .icns file not found at path: \(icnsPath)", logType: logType)
            return false
        }
        
        // Use macOS built-in `sips` utility to convert ICNS to PNG
        let process = Process()
        process.launchPath = "/usr/bin/sips"
        process.arguments = ["-s", "format", "png", icnsPath, "--out", outputPath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            
            // Check conversion success via process exit code
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
    
    
    /// Extracts and saves the system's generic application icon as a PNG file.
    /// 
    /// Uses the macOS system-provided generic application icon from CoreTypes bundle
    /// as a fallback when application-specific icons are unavailable. Automatically
    /// selects the highest resolution representation from the multi-resolution ICNS file.
    /// 
    /// - Parameter path: The destination file path for the PNG icon
    /// - Returns: `true` if the extraction and conversion succeeded, `false` otherwise
    /// 
    /// **Process Flow:**
    /// 1. Loads GenericApplicationIcon.icns from system CoreTypes bundle
    /// 2. Analyzes all available image representations in the ICNS
    /// 3. Selects the largest/highest quality representation
    /// 4. Converts the selected image to PNG format
    /// 5. Saves to the specified output path
    /// 
    /// **Use Cases:**
    /// - Fallback when app-specific icon extraction fails
    /// - Placeholder icons for applications without custom icons
    /// - Consistent icon representation across the system
    static func saveGenericAppIcon(to path: String) -> Bool {
        let iconPath = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"
        let iconURL = URL(fileURLWithPath: iconPath)
        
        // Create image source from system generic icon
        guard let imageSource = CGImageSourceCreateWithURL(iconURL as CFURL, nil) else {
            Logger.log("❌ Failed to create image source.", logType: logType)
            return false
        }

        // Find the largest available image representation from multi-resolution ICNS
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

        // Create PNG destination and write the image
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
    
    
    /// Loads an image file from disk and returns it as a CGImage object.
    /// 
    /// Creates a CGImage from various image file formats (PNG, JPEG, TIFF, etc.)
    /// by using Core Graphics image source APIs. Always loads the first image
    /// representation from the file.
    /// 
    /// - Parameter fileImagePath: The full file path to the image file
    /// - Returns: A CGImage object if successful, nil if the file cannot be loaded
    /// 
    /// **Supported Formats:**
    /// - PNG, JPEG, TIFF, GIF, BMP, and other Core Graphics supported formats
    /// - Multi-page formats will return only the first image
    /// 
    /// **Use Cases:**
    /// - Loading custom icons for processing
    /// - Converting between image formats
    /// - Preparing images for further manipulation
    static func getCGImageFromPath(fileImagePath: String) -> CGImage? {
        let fileURL = URL(fileURLWithPath: fileImagePath)
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            Logger.log("Failed to create image source from path: \(fileImagePath)", logType: logType)
            return nil
        }

        // Load the first image from the source
        let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        if cgImage == nil {
            Logger.log("Failed to create CGImage from source.", logType: logType)
        }

        return cgImage
    }
    
    
    /// Saves a CGImage object as a PNG file to the specified path.
    /// 
    /// Converts a CGImage to PNG format and writes it to disk using Core Graphics
    /// image destination APIs. Provides a simple way to save processed images
    /// in a consistent PNG format.
    /// 
    /// - Parameters:
    ///   - image: The CGImage object to save
    ///   - path: The destination file path (will be overwritten if exists)
    /// 
    /// **Behavior:**
    /// - Always saves in PNG format regardless of source format
    /// - Overwrites existing files at the destination path
    /// - Logs errors but does not return success/failure status
    /// 
    /// **Use Cases:**
    /// - Saving processed or converted images
    /// - Creating standardized PNG outputs from various sources
    /// - Final step in image conversion pipelines
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
