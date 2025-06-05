///
///  AppInspectorViewController.swift
///  Intuneomator
///
///  Modal view controller for inspecting downloaded applications (DMG, PKG) and editing metadata.
///  - Allows users to view and override detected metadata such as App ID, Version, Publisher, and Minimum OS.
///  - Validates code signatures and team IDs.
///  - Handles disk image mounting/unmounting and icon extraction.
///
  
//
//  AppInspectorViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/26/25.
//

import Cocoa

/// Delegate protocol to notify when the app inspector finishes saving metadata.
/// Provides optional overridden values for App ID, Version, Publisher, and Minimum OS.
protocol AppInspectorDelegate: AnyObject {
    /// Called when the app inspector saves data.
    /// - Parameters:
    ///   - appID: The selected or overridden application bundle identifier.
    ///   - appVersion: The selected or overridden application version string.
    ///   - appPublisher: The selected or overridden publisher name.
    ///   - appMinOSVersion: The selected or overridden minimum OS version string.
    func appInspectorDidSave(
        appID: String?,
        appVersion: String?,
        appPublisher: String?,
        appMinOSVersion: String?
    )
}

/// `AppInspectorViewController` presents a sheet for inspecting downloaded application metadata.
/// Users can override detected values, view code signature validation status, and save changes.
///
/// Modal view controller for inspecting and editing application metadata
/// Handles inspection of downloaded applications (DMG, PKG) and allows users to override
/// detected metadata such as app ID, version, publisher, and minimum OS requirements
/// 
/// **Key Features:**
/// - Inspects application bundles for metadata and code signatures
/// - Validates team IDs and certificate signatures
/// - Allows selective override of detected app information
/// - Handles disk image mounting/unmounting automatically
/// - Extracts and saves application icons
/// - Provides macOS version mapping for minimum OS requirements
class AppInspectorViewController: NSViewController {
    /// Text field displaying or editing the application bundle identifier (CFBundleIdentifier).
    @IBOutlet weak var appIDTextField: NSTextField!
    /// Text field displaying or editing the application version (CFBundleShortVersionString).
    @IBOutlet weak var appVersionTextField: NSTextField!
    /// Text field displaying or editing the detected application publisher (Developer ID).
    @IBOutlet weak var appPublisherTextField: NSTextField!
    /// Text field displaying or editing the detected minimum OS requirement.
    @IBOutlet weak var appMinOSTextField: NSTextField!

    /// Text field displaying the expected Apple Developer Team ID from configuration.
    @IBOutlet weak var appExpectedTeamField: NSTextField!
    /// Text field displaying the team ID discovered from the application’s signature.
    @IBOutlet weak var appDiscoveredTeamField: NSTextField!
    
    /// Checkbox to indicate whether to save and use the discovered application icon.
    @IBOutlet weak var useImageCheckbox: NSButton!
    /// Checkbox to indicate whether to override the App ID with the detected value.
    @IBOutlet weak var useAppIDCheckbox: NSButton!
    /// Checkbox to indicate whether to override the Publisher with the detected value.
    @IBOutlet weak var usePublisherCheckbox: NSButton!
    /// Checkbox to indicate whether to override the Minimum OS version with the detected value.
    @IBOutlet weak var useMinOSCheckbox: NSButton!

    /// Button displaying code signature validation status (green/red icon).
    @IBOutlet weak var appValidationButton: NSButton!
    /// Button that displays the extracted application icon if available.
    @IBOutlet weak var appImageButton: NSButton!
    /// Button to save any overrides and notify the delegate.
    @IBOutlet weak var saveButton: NSButton!
    
    /// File URL pointing to the downloaded application or mounted DMG being inspected.
    var appPath: URL!
    /// The detected or prefilled application bundle identifier.
    var appID: String = ""
    /// The detected or prefilled application version string.
    var appVersion: String = ""
    /// The detected or prefilled minimum OS requirement string.
    var appMinOSVersion: String = ""
    /// Dictionary containing signature inspection results (e.g., DeveloperID, DeveloperTeam, Accepted).
    var signature: [String: Any] = [:]
    /// The expected Apple Developer Team ID used for code signature validation.
    var expectedTeamID: String = ""
    /// The Installomator label name associated with this app being inspected.
    var label: String = ""
    /// Unique GUID tracking identifier for this app/label instance.
    var itemGUID: String = ""
    /// Path to the directory where title data and icons are stored.
    var directoryPath: String = ""

    /// URL to the selected icon file to be saved if “Use Image” is checked.
    private var selectedIconPath: URL?

    /// Delegate reference to inform when user saves overrides.
    weak var delegate: AppInspectorDelegate?

    /// Lifecycle callback after view loads.
    /// - Populates UI fields with initial data.
    /// - Loads the application icon and updates checkbox states.
    override func viewDidLoad() {
        super.viewDidLoad()

        // Populate UI with input data
        populateUI()
        loadAndSetIcon()
        updateCheckboxState()
    }

    /// Populates all UI fields with input data and signature results.
    /// - Sets text fields for App ID, Version, Publisher, Minimum OS, and team IDs.
    /// - Updates the validation icon based on the “Accepted” signature flag.
    private func populateUI() {
        
        //debug logging
        print(appPath.path)
        print(appID)
        print(appVersion)
        print(appMinOSVersion)
        print(signature["DeveloperID"] as? String ?? "")
        print(expectedTeamID)
        print(label)
        print(itemGUID)
        print(signature["DeveloperTeam"] as? String ?? "")
        print(signature["Accepted"] as Any)
        print(directoryPath)

        appIDTextField.stringValue = appID
        appVersionTextField.stringValue = appVersion
        appMinOSTextField.stringValue = displayName(forMinimumOS: appMinOSVersion) 
        appPublisherTextField.stringValue = signature["DeveloperID"] as? String ?? ""
        appExpectedTeamField.stringValue = expectedTeamID
        appDiscoveredTeamField.stringValue = signature["DeveloperTeam"] as? String ?? ""

        // Set the signature image based on the "Accepted" key
        if let accepted = signature["Accepted"] as? Bool, accepted {
            appValidationButton.image = NSImage(named: NSImage.statusAvailableName) // Green icon
        } else {
            appValidationButton.image = NSImage(named: NSImage.statusUnavailableName) // Red icon
        }
    }

    /// Updates checkbox states based on whether detected values exist.
    /// - Turns off publisher/MinOS checkboxes if corresponding fields are empty.
    /// - Turns off image checkbox if no valid icon is loaded.
    func updateCheckboxState() {
        if appPublisherTextField.stringValue.isEmpty {
            usePublisherCheckbox.state = .off
        } else {
            usePublisherCheckbox.state = .on
        }
        
        if appMinOSTextField.stringValue.isEmpty {
            useMinOSCheckbox.state = .off
        } else {
            useMinOSCheckbox.state = .on
        }

        if let image = appImageButton.image, image.isValid {
            useImageCheckbox.state = .on
        } else {
            useImageCheckbox.state = .off
        }
    }

    /// Attempts to load the application icon from the file system.
    /// - If successful, resizes to 512x512 and sets it on `appImageButton`.
    /// - Stores the icon path in `selectedIconPath`.
    /// - Clears the icon and path if loading fails.
    private func loadAndSetIcon() {
        guard let appPath = appPath, FileManager.default.fileExists(atPath: appPath.path) else {
            print("Error: appPath is invalid or does not exist.")
            appImageButton.image = nil
            selectedIconPath = nil
            return
        }

        // Attempt to load the app icon
        let image = NSWorkspace.shared.icon(forFile: appPath.path)
        if image.isValid {
            image.size = NSSize(width: 512, height: 512)
            appImageButton.image = image
            selectedIconPath = appPath
            print("Successfully loaded app icon for: \(appPath.path)")
        } else {
            print("Error: Failed to load icon for app at: \(appPath.path)")
            appImageButton.image = nil
            selectedIconPath = nil
        }
        
        updateCheckboxState()
    }

    /// Converts a raw minimum OS version string into a human-readable macOS name.
    /// - Parameters:
    ///   - versionString: Version string in “major.minor.patch” format.
    /// - Returns: A display name such as “macOS Monterey 12.0”.
    func displayName(forMinimumOS versionString: String) -> String {
        // Define known macOS versions
        let versionMap: [(version: OperatingSystemVersion, displayName: String)] = [
            (OperatingSystemVersion(majorVersion: 10, minorVersion: 13, patchVersion: 0), "macOS High Sierra 10.13"),
            (OperatingSystemVersion(majorVersion: 10, minorVersion: 14, patchVersion: 0), "macOS Mojave 10.14"),
            (OperatingSystemVersion(majorVersion: 10, minorVersion: 15, patchVersion: 0), "macOS Catalina 10.15"),
            (OperatingSystemVersion(majorVersion: 11, minorVersion: 0, patchVersion: 0), "macOS Big Sur 11.0"),
            (OperatingSystemVersion(majorVersion: 12, minorVersion: 0, patchVersion: 0), "macOS Monterey 12.0"),
            (OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0), "macOS Ventura 13.0"),
            (OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0), "macOS Sonoma 14.0"),
            (OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0), "macOS Sequoia 15.0"),
        ]

        // Parse the input version
        let components = versionString.split(separator: ".").map { Int($0) ?? 0 }
        let inputVersion = OperatingSystemVersion(
            majorVersion: components.count > 0 ? components[0] : 0,
            minorVersion: components.count > 1 ? components[1] : 0,
            patchVersion: components.count > 2 ? components[2] : 0
        )

        // Find the matching or next lower version
        for (version, name) in versionMap.reversed() {
            if isVersion(inputVersion, greaterThanOrEqualTo: version) {
                return name
            }
        }

        // Default to the lowest supported version
        return versionMap.first!.displayName
    }

    /// Compares two `OperatingSystemVersion` instances.
    /// - Returns true if version `a` is greater than or equal to version `b`.
    func isVersion(_ a: OperatingSystemVersion, greaterThanOrEqualTo b: OperatingSystemVersion) -> Bool {
        if a.majorVersion != b.majorVersion {
            return a.majorVersion > b.majorVersion
        }
        if a.minorVersion != b.minorVersion {
            return a.minorVersion > b.minorVersion
        }
        return a.patchVersion >= b.patchVersion
    }
    
    /// Unmounts the DMG if `appPath` points to a mounted volume.
    /// - Runs `hdiutil detach` on the containing mount point.
    func unMountDiskImage() {
        // Unmount the DMG if needed
        if let appPath = appPath, appPath.path.contains("/mount/") {
//            print("Unmounting DMG for path: \(appPath.path)")
            let unmountProcess = Process()
            unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            unmountProcess.arguments = ["detach", appPath.deletingLastPathComponent().path, "-quiet", "-force"]
            do {
                try unmountProcess.run()
                unmountProcess.waitUntilExit()
//                print("DMG unmounted successfully.")
            } catch {
//                print("Failed to unmount DMG: \(error)")
            }
        }
    }
    
    
    /// Returns the top-level temp folder URL for a given file URL under the Intuneomator temp directory.
    /// - Strips “/var/” to “/private/var/” normalization.
    /// - Returns nil if the file is not inside the temp folder.
    func workingFolderURL(for fileURL: URL) -> URL? {
        // Normalize both paths to use /private/var
        func normalizePath(_ path: String) -> String {
            if path.hasPrefix("/var/") {
                return "/private" + path
            }
            return path
        }

        let tempPath = normalizePath(AppConstants.intuneomatorTempFolderURL.path)
        let filePath = normalizePath(fileURL.path)

        // Ensure the file is inside the temp folder
        guard filePath.hasPrefix(tempPath + "/") else { return nil }

        // Get the subpath within the temp folder
        let remainingPath = String(filePath.dropFirst(tempPath.count + 1))
        let components = remainingPath.components(separatedBy: "/")

        guard let firstComponent = components.first else { return nil }

        return URL(fileURLWithPath: tempPath).appendingPathComponent(firstComponent, isDirectory: true)
    }
    
    
    /// Action handler for the Save button.
    /// - If “Use Image” is checked, saves the selected icon to the temp folder and imports via XPC.
    /// - Collects overridden values based on corresponding checkboxes.
    /// - Unmounts DMG and cleans up temp working folder.
    /// - Notifies the delegate with possibly nil values for overrides.
    /// - Dismisses the inspector sheet.
    @IBAction func saveChanges(_ sender: NSButton) {
        
        // Save the image if the checkbox is checked
        if useImageCheckbox.state == .on, let image = appImageButton.image {
            let folderName = "\(label)_\(itemGUID)"
            let folderPath = AppConstants.intuneomatorTempFolderURL
                .appendingPathComponent(folderName)
            let imagePath = folderPath.appendingPathComponent("\(label).png")
            
            // Save image to temp folder
            do {
                try FileManager.default.createDirectory(atPath: folderPath.path, withIntermediateDirectories: true, attributes: nil)
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try pngData.write(to: URL(fileURLWithPath: imagePath.path))
//                    print("Image saved to: \(imagePath)")
                }
            } catch {
//                print("Failed to save image: \(error)")
            }

            // copy to permanent location
            do {
                XPCManager.shared.importIconToLabel(imagePath.path, folderName) { success in
                    if success! {
//                        print("Saved icon")
                        // clean up temp folder/icon
                        do {
                            try FileManager.default.removeItem(atPath: folderPath.path)
//                            print("Temp folder removed.")
                        } catch {
//                            print("Failed to remove temp folder: \(error)")
                        }
                    } else {
//                        print("Failed to reset icon")
                    }
                }
            }
            
        }

        // Pass the data back to the delegate
        let appID = useAppIDCheckbox.state == .on ? appIDTextField.stringValue : nil
        let appVersion = useAppIDCheckbox.state == .on ? appVersionTextField.stringValue : nil
        let appPublisher = usePublisherCheckbox.state == .on ? appPublisherTextField.stringValue : nil
        let appMinOSVersion = useMinOSCheckbox.state == .on ? appMinOSTextField.stringValue : nil

        // Unmount the DMG if needed
        unMountDiskImage()
        
        // Clean up working folder
        if let workingFolder = workingFolderURL(for: appPath) {
            print("Working folder: \(workingFolder.path)")
            try? FileManager.default.removeItem(at: workingFolder)
        }
        
        // Notify the delegate and close the modal
        delegate?.appInspectorDidSave(appID: appID, appVersion: appVersion, appPublisher: appPublisher, appMinOSVersion: appMinOSVersion)

        // Close the modal
        dismiss(self)
    }

    /// Action handler for the Cancel button.
    /// - Unmounts DMG if mounted and cleans up temp working folder.
    /// - Dismisses the inspector sheet without saving any changes.
    @IBAction func cancel(_ sender: NSButton) {
        
        print("Canceled")
        print("App path: \(appPath.path)")
        
              
        // Unmount the DMG if needed
        unMountDiskImage()
        
        // Clean up working folder
        if let workingFolder = workingFolderURL(for: appPath) {
            print("Working folder: \(workingFolder.path)")
            try? FileManager.default.removeItem(at: workingFolder)
        }
        
        dismiss(self)
    }
}
