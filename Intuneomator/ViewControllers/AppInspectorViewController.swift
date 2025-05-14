//
//  AppInspectorViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/26/25.
//

import Cocoa

protocol AppInspectorDelegate: AnyObject {
    /// Called when the app inspector saves data.
    func appInspectorDidSave(
        appID: String?,
        appVersion: String?,
        appPublisher: String?,
        appMinOSVersion: String?
    )
}

class AppInspectorViewController: NSViewController {
    @IBOutlet weak var appIDTextField: NSTextField!
    @IBOutlet weak var appVersionTextField: NSTextField!
    @IBOutlet weak var appPublisherTextField: NSTextField!
    @IBOutlet weak var appMinOSTextField: NSTextField!

    @IBOutlet weak var appExpectedTeamField: NSTextField!
    @IBOutlet weak var appDiscoveredTeamField: NSTextField!
    
    @IBOutlet weak var useImageCheckbox: NSButton!
    @IBOutlet weak var useAppIDCheckbox: NSButton!
    @IBOutlet weak var usePublisherCheckbox: NSButton!
    @IBOutlet weak var useMinOSCheckbox: NSButton!

    @IBOutlet weak var appValidationButton: NSButton!
    @IBOutlet weak var appImageButton: NSButton!
    @IBOutlet weak var saveButton: NSButton!
    
    // Input data
    var appPath: URL!
    var appID: String = ""
    var appVersion: String = ""
    var appMinOSVersion: String = ""
    var signature: [String: Any] = [:]
    var expectedTeamID: String = ""
    var label: String = ""
    var itemGUID: String = ""
    var directoryPath: String = ""

    // Selected Icon Path for Saving
    private var selectedIconPath: URL?

    weak var delegate: AppInspectorDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Populate UI with input data
        populateUI()
        loadAndSetIcon()
        updateCheckboxState()
    }

    // MARK: - UI Setup
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

    func isVersion(_ a: OperatingSystemVersion, greaterThanOrEqualTo b: OperatingSystemVersion) -> Bool {
        if a.majorVersion != b.majorVersion {
            return a.majorVersion > b.majorVersion
        }
        if a.minorVersion != b.minorVersion {
            return a.minorVersion > b.minorVersion
        }
        return a.patchVersion >= b.patchVersion
    }
    
    // MARK: - Helper
    
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
    
    
    // MARK: - Actions
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
