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
            Logger.error("❌ Failed to read CFBundleIconFile from Info.plist", category: .core)
            return false
        }
        
        // Ensure the icon file has .icns extension (some apps omit it in plist)
        if !iconName.hasSuffix(".icns") {
            iconName += ".icns"
        }
        
        let icnsPath = "\(appPath)/Contents/Resources/\(iconName)"
        
        // Verify the icon file exists before attempting conversion
        guard FileManager.default.fileExists(atPath: icnsPath) else {
            Logger.info("❌ .icns file not found at path: \(icnsPath)", category: .core)
            return false
        }
        
        // Use macOS built-in `sips` utility to convert ICNS to PNG
        let process = Process()
        process.launchPath = "/usr/bin/sips"
        process.arguments = ["-s", "format", "png", icnsPath, "--out", outputPath]
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            if let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !errorOutput.isEmpty {
                Logger.info(" stderr from |(executableURL.lastPathComponent) with \(appPath): \(errorOutput)", category: .core)
            }

            // Check conversion success via process exit code
            if process.terminationStatus == 0 {
                Logger.info("✅ Icon converted successfully to: \(outputPath)", category: .core)
                return true
            } else {
                Logger.error("❌ sips failed with exit code: \(process.terminationStatus)", category: .core)
                return false
            }
        } catch {
            Logger.error("❌ Failed to run sips: \(error)", category: .core)
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
            Logger.error("❌ Failed to create image source.", category: .core)
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
            Logger.error("❌ Failed to extract image from icon.", category: .core)
            return false
        }

        // Create PNG destination and write the image
        let outputURL = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            Logger.error("❌ Failed to create image destination.", category: .core)
            return false
        }

        CGImageDestinationAddImage(destination, finalImage, nil)
        if CGImageDestinationFinalize(destination) {
            Logger.info("✅ Saved generic app icon to \(path)", category: .core)
            return true
        } else {
            Logger.error("❌ Failed to write PNG file.", category: .core)
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
            Logger.error("Failed to create image source from path: \(fileImagePath)", category: .core)
            return nil
        }

        // Load the first image from the source
        let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        if cgImage == nil {
            Logger.error("Failed to create CGImage from source.", category: .core)
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
            Logger.error("Failed to create image destination.", category: .core)
            return
        }

        CGImageDestinationAddImage(destination, image, nil)

        if !CGImageDestinationFinalize(destination) {
            Logger.error("Failed to finalize image destination.", category: .core)
        }
    }


    // MARK: - Icon Sizing for Graph API Upload

    /// Maximum icon file size (in bytes) permitted before the icon is downscaled prior to
    /// being embedded in a Graph API app metadata request.
    ///
    /// Icons are embedded as base64 directly inside the same JSON body used to create/update
    /// macOS Pkg/Dmg/LOB app metadata. Oversized icons (observed: a 2.9 MB, 1024x1024 PNG) have
    /// been seen to trigger a generic `StaticContentCommon0ContentValidateContent` internal
    /// server error (HTTP 500) from Intune's mobileApps metadata-creation endpoint, even though
    /// every other field in the payload is well-formed.
    static let maxIconFileSizeBytes = 1_000_000

    /// Starting target dimension (pixels, per side) used when downscaling an oversized icon.
    static let maxIconDimension = 512

    /// Returns PNG data for the icon at `path`, ready to embed as `largeIcon` in a Graph API
    /// app metadata request. If the file is already at or under `maxIconFileSizeBytes`, its raw
    /// bytes are returned unchanged. If it's larger, the icon is downscaled (preserving aspect
    /// ratio, halving the target dimension as needed) until it fits, falling back to the
    /// original bytes if downscaling fails for any reason.
    /// - Parameter path: Full path to the icon PNG file on disk.
    /// - Returns: PNG data suitable for base64 embedding, or `nil` if the file couldn't be read.
    static func iconDataForUpload(atPath path: String) -> Data? {
        guard let originalData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }

        guard originalData.count > maxIconFileSizeBytes else {
            return originalData
        }

        guard let downscaledData = downscaledPNGData(atPath: path, startingDimension: maxIconDimension) else {
            Logger.error("⚠️ Icon at \(path) is \(originalData.count) bytes and could not be downscaled; uploading as-is.", category: .core)
            return originalData
        }

        Logger.info("ℹ️ Downscaled oversized icon before upload: \(path) (\(originalData.count) bytes → \(downscaledData.count) bytes)", category: .core)
        return downscaledData
    }

    /// Loads the image at `path` and re-encodes it as PNG data scaled to fit within
    /// `startingDimension` x `startingDimension`, halving the target dimension (down to a
    /// floor of 64px) if the result is still larger than `maxIconFileSizeBytes`.
    private static func downscaledPNGData(atPath path: String, startingDimension: Int) -> Data? {
        guard let cgImage = getCGImageFromPath(fileImagePath: path) else { return nil }

        var targetDimension = startingDimension

        while targetDimension >= 64 {
            let scale = min(CGFloat(targetDimension) / CGFloat(cgImage.width),
                             CGFloat(targetDimension) / CGFloat(cgImage.height),
                             1.0)
            let width = max(1, Int(CGFloat(cgImage.width) * scale))
            let height = max(1, Int(CGFloat(cgImage.height) * scale))

            if let resized = resizedCGImage(cgImage, width: width, height: height),
               let pngData = pngData(from: resized),
               pngData.count <= maxIconFileSizeBytes {
                return pngData
            }

            targetDimension /= 2
        }

        return nil
    }

    /// Draws `image` into a new bitmap context of the given pixel dimensions, producing a
    /// resized CGImage.
    private static func resizedCGImage(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Encodes a CGImage as in-memory PNG data.
    private static func pngData(from image: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
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
