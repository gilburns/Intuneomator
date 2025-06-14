//
//  FileFolderUtils.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/19/25.
//

import Foundation

/// Utility class for managing file and folder operations including permissions and ownership
/// Provides methods for creating directories, modifying permissions, and changing ownership
class FileFolderManagerUtil {
    
    /// Creates a folder with specified permissions (default: 755)
    static func createFolder(at path: String, withPermissions permissions: Int = 0o755) -> Bool {
        let fileManager = FileManager.default
        let attributes: [FileAttributeKey: Any] = [.posixPermissions: permissions]
        
        do {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: attributes)
            return true
        } catch {
            print("Failed to create folder: \(error.localizedDescription)")
            return false
        }
    }

    /// Retrieves and prints the current POSIX permissions of a folder or file in octal format
    /// - Parameter path: The file system path to check permissions for
    static func getPermissions(of path: String) {
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            if let permissions = attributes[.posixPermissions] as? NSNumber {
                let octalPermissions = String(format: "%o", permissions.intValue) // Convert to octal
                print("Permissions for \(path): \(octalPermissions) (octal)")
            }
        } catch {
            print("Failed to get attributes for \(path): \(error.localizedDescription)")
        }
    }
    
    /// Changes POSIX permissions for a file or folder
    /// - Parameters:
    ///   - path: The file system path to modify
    ///   - newPermissions: New permissions in octal format (e.g., 0o755)
    /// - Returns: True if permissions were changed successfully, false otherwise
    static func changePermissions(
        at path: String,
        to newPermissions: Int
    ) -> Bool {
        let fileManager = FileManager.default
        let attributes: [FileAttributeKey: Any] = [.posixPermissions: newPermissions]
        
        do {
            try fileManager.setAttributes(attributes, ofItemAtPath: path)
            
            return true
        } catch {
            print("Failed to change permissions: \(error.localizedDescription)")
            return false
        }
    }

    /// Recursively changes permissions for a folder and its contents with advanced filtering
    /// Directories always get 755 permissions to maintain accessibility
    /// - Parameters:
    ///   - path: The root folder path to process recursively
    ///   - newPermissions: New permissions in octal format for files
    ///   - allowedExtensions: Optional array of file extensions to process (nil = all files)
    ///   - excludeHiddenFiles: Whether to skip files starting with dot (.)
    ///   - skipDirectories: Whether to skip processing directories
    /// - Returns: True if operation completed successfully, false otherwise
    static func changePermissionsRecursively(
        at path: String,
        to newPermissions: Int,
        allowedExtensions: [String]? = nil,
        excludeHiddenFiles: Bool = false,
        skipDirectories: Bool = false
    ) -> Bool {
        let fileManager = FileManager.default
        
        do {
            let items = try fileManager.subpathsOfDirectory(atPath: path)
            
            for item in items {
                let fullPath = (path as NSString).appendingPathComponent(item)
                let attributes = try fileManager.attributesOfItem(atPath: fullPath)
                let isDirectory = attributes[.type] as? FileAttributeType == .typeDirectory
                
                // Apply filtering rules
                if isDirectory {
                    if skipDirectories { continue }
                    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fullPath)  // Keep directories executable
                } else {
                    if excludeHiddenFiles && (item as NSString).lastPathComponent.hasPrefix(".") { continue }
                    if let allowedExtensions = allowedExtensions, !allowedExtensions.contains((item as NSString).pathExtension) { continue }
                    Logger.info("Item: \(item)", category: .core)
                    
                    do {
                        try fileManager.setAttributes([.posixPermissions: newPermissions], ofItemAtPath: fullPath)
                    } catch {
                        Logger.info("Failed to set permissions for \(item): \(error.localizedDescription).", category: .core)
                    }

                }
            }
            
            return true
        } catch {
            print("Failed to change permissions recursively: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Changes the owner and group of a folder or file using the chown command
    /// - Parameters:
    ///   - path: The file system path to modify ownership for
    ///   - owner: The new owner username
    ///   - group: The new group name
    /// - Returns: True if ownership was changed successfully, false otherwise
    static func changeOwnerAndGroup(at path: String, owner: String, group: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/sbin/chown"
        process.arguments = ["\(owner):\(group)", path]
        
        let pipe = Pipe()
        process.standardError = pipe // Capture error output
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                print("Successfully changed owner to '\(owner)' and group to '\(group)' for \(path)")
                return true
            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("Failed to change owner/group: \(errorMessage)")
                return false
            }
        } catch {
            print("Error executing chown: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Recursively changes owner and group for all files and directories inside a folder
    /// Uses the chown -R command for efficient recursive ownership changes
    /// - Parameters:
    ///   - path: The root folder path to process recursively
    ///   - owner: The new owner username
    ///   - group: The new group name
    /// - Returns: True if recursive ownership change completed successfully, false otherwise
    static func changeOwnerAndGroupRecursively(at path: String, owner: String, group: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/sbin/chown"
        process.arguments = ["-R", "\(owner):\(group)", path] // -R flag for recursive
        
        let pipe = Pipe()
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                print("Successfully changed owner to '\(owner)' and group to '\(group)' recursively for \(path)")
                return true
            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("Failed to change owner/group recursively: \(errorMessage)")
                return false
            }
        } catch {
            print("Error executing chown: \(error.localizedDescription)")
            return false
        }
    }
    
}

// **Usage**

/*
 
let folderPath = "/Users/yourusername/Documents/TestFolder"

// 1. Create the folder with 755 permissions
if FileManagerUtil.createFolder(at: folderPath) {
    print("Folder created successfully!")
}

// 2. Create test files inside the folder
let testFile1 = folderPath + "/file1.txt"
let testFile2 = folderPath + "/file2.log"
let hiddenFile = folderPath + "/.hiddenfile"
FileManager.default.createFile(atPath: testFile1, contents: nil, attributes: nil)
FileManager.default.createFile(atPath: testFile2, contents: nil, attributes: nil)
FileManager.default.createFile(atPath: hiddenFile, contents: nil, attributes: nil)

// 3. Check initial permissions
FileManagerUtil.getPermissions(of: folderPath)
FileManagerUtil.getPermissions(of: testFile1)
FileManagerUtil.getPermissions(of: testFile2)
FileManagerUtil.getPermissions(of: hiddenFile)

// 4. Recursively change permissions to 700 **only for .txt and .log files**, skipping hidden files and directories
if FileManagerUtil.changePermissionsRecursively(at: folderPath, to: 0o700, allowedExtensions: ["txt", "log"], excludeHiddenFiles: true, skipDirectories: true) {
    print("Permissions changed recursively!")
}

// 5. Verify new permissions
FileManagerUtil.getPermissions(of: folderPath)      // Should be unchanged if skipDirectories is true
FileManagerUtil.getPermissions(of: testFile1)       // Should be updated
FileManagerUtil.getPermissions(of: testFile2)       // Should be updated
FileManagerUtil.getPermissions(of: hiddenFile)      // Should be unchanged


// **Usage**
let folderPath = "/Users/yourusername/Documents/TestFolder"
let newOwner = "yourusername"
let newGroup = "staff"

// Change owner/group for a single folder
FileManagerUtil.changeOwnerAndGroup(at: folderPath, owner: newOwner, group: newGroup)

// Change owner/group for all files and subfolders inside
FileManagerUtil.changeOwnerAndGroupRecursively(at: folderPath, owner: newOwner, group: newGroup)

 */
