//
//  PkgInspectorViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/26/25.
//

import Cocoa

protocol PkgInspectorDelegate: AnyObject {
    /// Called when the user saves the package information.
    func pkgInspectorDidSave(
        pkgID: String?,
        pkgVersion: String?,
        pkgPublisher: String?,
        pkgMinOSVersion: String?
        
    )
}

/// Modal view controller for inspecting and editing PKG installer metadata
/// Handles inspection of macOS installer packages (.pkg) and allows users to override
/// detected metadata such as bundle identifier, version, publisher, and minimum OS requirements
///
/// **Key Features:**
/// - Inspects PKG installer packages for embedded metadata and receipts
/// - Validates code signatures and certificate information for packages
/// - Allows selective override of detected package information
/// - Extracts and displays installer icons from package contents
/// - Provides macOS version mapping for minimum OS requirements
/// - Handles package mounting/unmounting and temporary file cleanup
/// - Supports both flat packages and bundle-style installer packages
class PkgInspectorViewController: NSViewController {
    @IBOutlet weak var pkgIDPopupButton: NSPopUpButton!
    
    @IBOutlet weak var pkgVersionTextField: NSTextField!
    @IBOutlet weak var pkgPublisherTextField: NSTextField!
    @IBOutlet weak var pkgMinOSTextField: NSTextField!

    @IBOutlet weak var pkgExpectedTeamField: NSTextField!
    @IBOutlet weak var pkgDiscoveredTeamField: NSTextField!
    
    @IBOutlet weak var useImageCheckbox: NSButton!
    @IBOutlet weak var usePkgIDCheckbox: NSButton!
    @IBOutlet weak var usePublisherCheckbox: NSButton!
    @IBOutlet weak var useMinOSCheckbox: NSButton!

    @IBOutlet weak var pkgValidationButton: NSButton!
    @IBOutlet weak var pkgImageButton: NSButton!
    @IBOutlet weak var saveButton: NSButton!
    
    
    // Input data
    var pkgItems: [(String, String)] = [] // [(pkgID, version)]
    var pkgSignature: [String: Any] = [:] // Signature details (Accepted, DeveloperID, DeveloperTeam)
    var pkgURL: URL! // URL to the inspected PKG file
    var expectedTeamID: String = ""
    var label: String = ""
    var itemGUID: String = ""
    var directoryPath: String = ""
    
    // Image Popover and Images
    private var imagesPopover: NSPopover?
    private var availableImages: [URL: NSImage] = [:]
    
    // Selected Icon Path for Saving
    private var selectedIconPath: URL?
    
    // Delegate to pass data back
    weak var delegate: PkgInspectorDelegate?
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Populate UI with input data
        populateUI()

        // Find all images in the package
        availableImages = findAllImages()

        print("Available Images: \(availableImages.count)")
        print("Available Images: \(availableImages.keys)")
        
        // Set an app image as the default if available
        if !availableImages.isEmpty {
            // First try to find an image from an .app bundle
            var foundAppImage = false
            
            for (path, image) in availableImages {
                if path.pathExtension.lowercased() == "app" {
                    // Found an app bundle, use its image
                    pkgImageButton.image = image
                    selectedIconPath = path
                    
                    // Update checkbox state
                    if useImageCheckbox.state == .off {
                        useImageCheckbox.state = .on
                    }
                    
                    foundAppImage = true
                    break
                }
            }
            
            // If no app image was found, fall back to the first image
            if !foundAppImage, let firstPath = availableImages.keys.first,
               let firstImage = availableImages[firstPath] {
                pkgImageButton.image = firstImage
                selectedIconPath = firstPath
                
                // Update checkbox state
                if useImageCheckbox.state == .off {
                    useImageCheckbox.state = .on
                }
            }
        }
        
        
        // Connect the image button to the popover action
        pkgImageButton.target = self
        pkgImageButton.action = #selector(showImageSelector(_:))
        
    }
    
    // MARK: - UI Setup
    
    /// Populates the user interface with detected package metadata
    /// Updates text fields and controls with information extracted from the PKG file
    private func populateUI() {
        // Populate the package ID popup with IDs only
        let ids = pkgItems.map { $0.0 }
        pkgIDPopupButton.removeAllItems()
        pkgIDPopupButton.addItems(withTitles: ids)
        if !ids.isEmpty {
            pkgIDPopupButton.selectItem(at: 0)
            updateVersionForSelectedID()
        }
        
        // Populate signature fields
        pkgDiscoveredTeamField.stringValue = pkgSignature["DeveloperTeam"] as? String ?? ""
        pkgPublisherTextField.stringValue = pkgSignature["DeveloperID"] as? String ?? ""
        
        // Set expected team field
        pkgExpectedTeamField.stringValue = expectedTeamID
        
        // Set validation button state
        if let accepted = pkgSignature["Accepted"] as? Bool, accepted {
            pkgValidationButton.image = NSImage(named: NSImage.statusAvailableName) // Green icon
        } else {
            pkgValidationButton.image = NSImage(named: NSImage.statusUnavailableName) // Red icon
        }
        
        updateCheckboxState()
    }
    
    // MARK: - Buttons
    
    /// Shows an image selector popover for choosing package icons
    /// Displays available images found within the package contents
    @IBAction func showImageSelector(_ sender: NSButton) {
        
        if availableImages.isEmpty {
            let alert = NSAlert()
            alert.messageText = "No Images Found"
            alert.informativeText = "No suitable images were found in the package."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.beginSheetModal(for: self.view.window!) { _ in }
            return
        }
        
        // Create the popover if it doesn't exist
        if imagesPopover == nil {
            imagesPopover = NSPopover()
            imagesPopover?.behavior = .transient
            
            // Create the view controller for the popover
            let imageSelectorVC = ImageSelectorViewController()
            imageSelectorVC.images = Array(availableImages.values)
            imageSelectorVC.imagePaths = Array(availableImages.keys)
            imageSelectorVC.delegate = self
            imageSelectorVC.popover = imagesPopover
            
            imagesPopover?.contentViewController = imageSelectorVC
            imagesPopover?.contentSize = NSSize(width: 400, height: 300)
        } else {
            // Update the images in the existing popover
            if let imageSelectorVC = imagesPopover?.contentViewController as? ImageSelectorViewController {
                imageSelectorVC.images = Array(availableImages.values)
                imageSelectorVC.imagePaths = Array(availableImages.keys)
            }
        }
        
        // Show the popover
        imagesPopover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }
    
    
    /// Handles package ID selection changes in the popup
    /// Updates version and other metadata when a different package ID is selected
    @IBAction func pkgIDPopupChanged(_ sender: NSPopUpButton) {
        // Update version and icon when ID is changed
        updateVersionForSelectedID()

    }
    
    /// Updates checkbox states based on available metadata
    /// Automatically enables/disables override checkboxes based on whether data is present
    func updateCheckboxState() {

        if pkgPublisherTextField.stringValue.isEmpty {
            usePublisherCheckbox.state = .off
        } else {
            usePublisherCheckbox.state = .on
        }
        
        if pkgMinOSTextField.stringValue.isEmpty {
            useMinOSCheckbox.state = .off
        } else {
            useMinOSCheckbox.state = .on
        }

        if let image = pkgImageButton.image, image.isValid {
            useImageCheckbox.state = .on
        } else {
            useImageCheckbox.state = .off
        }
    }
    
    /// Converts a version string to a human-readable macOS version name
    /// - Parameter versionString: Version string (e.g., "14.0")
    /// - Returns: Human-readable version name (e.g., "macOS Sonoma 14.0")
    func displayName(forMinimumOS versionString: String) -> String {
        // Define known macOS versions
        let versionMap: [(version: OperatingSystemVersion, displayName: String)] = [
            (OperatingSystemVersion(majorVersion: 10, minorVersion: 11, patchVersion: 0), "macOS Mojave 10.14"),
            (OperatingSystemVersion(majorVersion: 10, minorVersion: 12, patchVersion: 0), "macOS Mojave 10.14"),
            (OperatingSystemVersion(majorVersion: 10, minorVersion: 13, patchVersion: 0), "macOS Mojave 10.14"),
            (OperatingSystemVersion(majorVersion: 10, minorVersion: 14, patchVersion: 0), "macOS Mojave 10.14"),
            (OperatingSystemVersion(majorVersion: 10, minorVersion: 15, patchVersion: 0), "macOS Catalina 10.15"),
            (OperatingSystemVersion(majorVersion: 11, minorVersion: 0, patchVersion: 0), "macOS Big Sur 11.0"),
            (OperatingSystemVersion(majorVersion: 12, minorVersion: 0, patchVersion: 0), "macOS Monterey 12.0"),
            (OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0), "macOS Ventura 13.0"),
            (OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0), "macOS Sonoma 14.0"),
            (OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0), "macOS Sequoia 15.0"),
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

    /// Recursively finds files with a specific extension in a folder
    /// - Parameters:
    ///   - folderURL: The folder to search in
    ///   - ext: The file extension to search for
    /// - Returns: Array of URLs matching the extension, sorted by path length
    private func findFiles(inFolder folderURL: URL, withExtension ext: String) throws -> [URL] {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        
        var foundFiles = [URL]()
        
        while let fileURL = enumerator?.nextObject() as? URL {
            // Special case for .app bundles which are directories
            if ext.lowercased() == "app" {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true && fileURL.pathExtension.lowercased() == "app" {
                    foundFiles.append(fileURL)
                }
            } else {
                // Normal files
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == false && fileURL.pathExtension.lowercased() == ext.lowercased() {
                    foundFiles.append(fileURL)
                }
            }
        }
                
        // Sort by shortest full path length
        foundFiles.sort { $0.path.count < $1.path.count }

        return foundFiles
    }

    
    /// Compares two operating system versions
    /// - Parameters:
    ///   - a: First version to compare
    ///   - b: Second version to compare
    /// - Returns: True if version a is greater than or equal to version b
    func isVersion(_ a: OperatingSystemVersion, greaterThanOrEqualTo b: OperatingSystemVersion) -> Bool {
        if a.majorVersion != b.majorVersion {
            return a.majorVersion > b.majorVersion
        }
        if a.minorVersion != b.minorVersion {
            return a.minorVersion > b.minorVersion
        }
        return a.patchVersion >= b.patchVersion
    }

    
    /// Updates the version field and minimum OS for the selected package ID
    /// Automatically populates version information when a package ID is selected
    private func updateVersionForSelectedID() {
        guard let selectedID = pkgIDPopupButton.titleOfSelectedItem else { return }
        
        // Clean up the version string before updating the text field
        if let version = pkgItems.first(where: { $0.0 == selectedID })?.1 {
            let cleanedVersion = version.replacingOccurrences(of: "&quot;", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            pkgVersionTextField.stringValue = cleanedVersion
        }
        
        // Find and set minimum OS based on the selected ID
        loadMinOSForSelectedPackage(id: selectedID)

        updateCheckboxState()
        
    }
    
    /// Loads and sets the minimum supported macOS version for the given package ID.
    /// - Parameter id: The package identifier whose metadata is being inspected.
    ///
    /// This function locates the expanded package folder, parses the Distribution or PackageInfo
    /// XML to find the matching `<pkg-ref>` node for the selected ID and version, decodes the
    /// percent-encoded payload folder name, drills into the payload to find an `.app` bundle,
    /// reads its `Info.plist` for `LSMinimumSystemVersion`, converts it to a human-readable
    /// display string, and updates the `pkgMinOSTextField`. If any step fails, it logs an error
    /// and clears the minimum OS field.
    private func loadMinOSForSelectedPackage(id: String) {
        guard let pkgURL = pkgURL else {
            return
        }

        let expandedPkgDir = pkgURL.deletingLastPathComponent().appendingPathComponent("expanded_pkg")
        
        // Look for metadata files: Distribution or PackageInfo
        let distributionPath = expandedPkgDir.appendingPathComponent("Distribution")
        let packageInfoPath = expandedPkgDir.appendingPathComponent("PackageInfo")
        let xmlFilePath: URL
        
        if FileManager.default.fileExists(atPath: distributionPath.path) {
            xmlFilePath = distributionPath
        } else if FileManager.default.fileExists(atPath: packageInfoPath.path) {
            xmlFilePath = packageInfoPath
        } else {
            print("No valid metadata file found")
            return
        }
        
        do {
            let xmlData = try Data(contentsOf: xmlFilePath)
            guard let xmlDocument = try? XMLDocument(data: xmlData, options: .documentTidyXML) else {
                print("Error: Failed to parse XML")
                return
            }

            // Get the selected version
            guard let selectedVersionRaw = pkgItems.first(where: { $0.0 == id })?.1 else {
                print("Error: No version found for ID: \(id)")
                return
            }

            // Clean the version string
            let cleanedVersion = selectedVersionRaw.replacingOccurrences(of: "&quot;", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

            // Define possible formats for the version attribute
            let possibleVersions = [
                selectedVersionRaw,
                "\"\(cleanedVersion)\"",
                "&quot;\(cleanedVersion)&quot;",
                "&quot;\(cleanedVersion)&quot; "
            ]

            var matchedPkgRefNode: XMLElement? = nil

            // Try each possible version format
            for version in possibleVersions {
                let pkgRefXPath = "//pkg-ref[@id='\(id)' and @version='\(version)']"
                if let pkgRefNode = try? xmlDocument.nodes(forXPath: pkgRefXPath).first as? XMLElement {
                    matchedPkgRefNode = pkgRefNode
                    break
                }
            }

            guard let pkgRefNode = matchedPkgRefNode,
                  let pkgRefValue = pkgRefNode.stringValue,
                  pkgRefValue.hasPrefix("#") else {
                print("Error: No matching pkg-ref found")
                return
            }

            let encodedFolderName = String(pkgRefValue.dropFirst()) // Remove the `#`
            guard let folderName = encodedFolderName.removingPercentEncoding else {
                print("Error: Failed to decode percent-encoded folder name")
                return
            }

            let payloadDir = expandedPkgDir.appendingPathComponent(folderName).appendingPathComponent("Payload")
            
            let apps = try findFiles(inFolder: URL(fileURLWithPath: payloadDir.path), withExtension: "app")
            
            if let appPath = apps.first {
                // Look up LSMinimumSystemVersion and update the text field
                let infoPlistPath = appPath.appendingPathComponent("Contents/Info.plist")
                if let infoPlist = NSDictionary(contentsOf: infoPlistPath),
                   let minOSVersion = infoPlist["LSMinimumSystemVersion"] as? String {
                    let display = displayName(forMinimumOS: minOSVersion)
                    pkgMinOSTextField.stringValue = display
                } else {
                    print("LSMinimumSystemVersion not found in Info.plist")
                    pkgMinOSTextField.stringValue = ""
                }
            }
        } catch {
            print("Error processing XML: \(error)")
        }
    }

    /// Scans the expanded package contents for potential icon images.
    /// - Returns: A dictionary mapping each found file URL to its corresponding `NSImage`.
    ///
    /// This method first locates the expanded package directory, then:
    ///   1. Finds all `.app` bundles and extracts their application icons via `NSWorkspace`.
    ///   2. Finds all `.icns` files, loads them as `NSImage`.
    ///   3. Finds `.png` files that resemble icons (based on filename or resource path and a square size >= 64 px).
    /// Each discovered image is resized to 512x512 and stored in the returned map. If any errors
    /// occur during folder enumeration or image loading, it logs the error and skips that file.
    private func findAllImages() -> [URL: NSImage] {
        var imageMap = [URL: NSImage]()
        
        guard let pkgURL = pkgURL else {
            return imageMap
        }
        
        let expandedPkgDir = pkgURL.deletingLastPathComponent().appendingPathComponent("expanded_pkg")
        
        do {
            // Find all app bundles
            let appBundles = try findFiles(inFolder: expandedPkgDir, withExtension: "app")
            
            // Extract icons from app bundles
            for appBundle in appBundles {
                let icon = NSWorkspace.shared.icon(forFile: appBundle.path)
                icon.size = NSSize(width: 512, height: 512)
                imageMap[appBundle] = icon
            }
            
            // Find all icns files
            let icnsFiles = try findFiles(inFolder: expandedPkgDir, withExtension: "icns")
            for icnsFile in icnsFiles {
                if let image = NSImage(contentsOfFile: icnsFile.path) {
                    image.size = NSSize(width: 512, height: 512)
                    imageMap[icnsFile] = image
                }
            }
            
            // Find all png files that might be app icons
            let pngFiles = try findFiles(inFolder: expandedPkgDir, withExtension: "png")
            for pngFile in pngFiles {
                // Only consider PNG files that might be icons (in certain directories or meeting size criteria)
                let fileName = pngFile.lastPathComponent.lowercased()
                if fileName.contains("icon") || fileName.contains("app") ||
                   pngFile.path.lowercased().contains("resources") {
                    if let image = NSImage(contentsOfFile: pngFile.path) {
                        // Check if the image is square and reasonably sized to be an icon
                        let imgRep = image.representations.first
                        if let width = imgRep?.pixelsWide, let height = imgRep?.pixelsHigh,
                           width >= 64 && height >= 64 && abs(width - height) < 10 {
                            image.size = NSSize(width: 512, height: 512)
                            imageMap[pngFile] = image
                        }
                    }
                }
            }
        } catch {
            print("Error finding images: \(error)")
        }
        
        return imageMap
    }
    
    
    private func loadAndSetIconAndMinOS(forID id: String) {
        guard let pkgURL = pkgURL else {
            print("Error: pkgURL is nil. Cannot load icon.")
            pkgImageButton.image = nil
            selectedIconPath = nil
            return
        }

        let expandedPkgDir = pkgURL.deletingLastPathComponent().appendingPathComponent("expanded_pkg")
        
        // Look for metadata files: Distribution or PackageInfo
        let distributionPath = expandedPkgDir.appendingPathComponent("Distribution")
        let packageInfoPath = expandedPkgDir.appendingPathComponent("PackageInfo")
        let xmlFilePath: URL
        
        if FileManager.default.fileExists(atPath: distributionPath.path) {
            // Parse `Distribution` file
            xmlFilePath = distributionPath
        } else if FileManager.default.fileExists(atPath: packageInfoPath.path) {
            // Parse `PackageInfo` file
            xmlFilePath = packageInfoPath
        } else {
            print([NSLocalizedDescriptionKey: "No valid metadata file found"])
            return
        }
        
        guard FileManager.default.fileExists(atPath: xmlFilePath.path) else {
            print("Error: Could not locate Distribution file.")
            pkgImageButton.image = nil
            selectedIconPath = nil
            return
        }

        do {
            let xmlData = try Data(contentsOf: xmlFilePath)
            guard let xmlDocument = try? XMLDocument(data: xmlData, options: .documentTidyXML) else {
                print("Error: Failed to parse XML at \(xmlFilePath.path).")
                pkgImageButton.image = nil
                selectedIconPath = nil
                return
            }

            // Get the selected version
            guard let selectedVersionRaw = pkgItems.first(where: { $0.0 == id })?.1 else {
                print("Error: No version found for ID: \(id)")
                pkgImageButton.image = nil
                selectedIconPath = nil
                return
            }

            // Clean the version string for weird cases
            let cleanedVersion = selectedVersionRaw.replacingOccurrences(of: "&quot;", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

            // Define possible formats for the version attribute
            let possibleVersions = [
                selectedVersionRaw,                          // Normal version (e.g., "1.0.0")
                "\"\(cleanedVersion)\"",                    // Cleaned version wrapped in quotes
                "&quot;\(cleanedVersion)&quot;",            // Escaped quotes without trailing space
                "&quot;\(cleanedVersion)&quot; "            // Escaped quotes with trailing space
            ]

            var matchedPkgRefNode: XMLElement? = nil

            // Try each possible version format
            for version in possibleVersions {
                let pkgRefXPath = "//pkg-ref[@id='\(id)' and @version='\(version)']"
                print("Trying XPath: \(pkgRefXPath)") // Debug
                if let pkgRefNode = try? xmlDocument.nodes(forXPath: pkgRefXPath).first as? XMLElement {
                    matchedPkgRefNode = pkgRefNode
                    break
                }
            }

            guard let pkgRefNode = matchedPkgRefNode,
                  let pkgRefValue = pkgRefNode.stringValue,
                  pkgRefValue.hasPrefix("#") else {
                print("Error: No matching pkg-ref found for ID: \(id) and version: \(selectedVersionRaw)")
                pkgImageButton.image = nil
                selectedIconPath = nil
                return
            }

            let encodedFolderName = String(pkgRefValue.dropFirst()) // Remove the `#`
            guard let folderName = encodedFolderName.removingPercentEncoding else {
                print("Error: Failed to decode percent-encoded folder name: \(encodedFolderName)")
                pkgImageButton.image = nil
                selectedIconPath = nil
                return
            }

            let payloadDir = expandedPkgDir.appendingPathComponent(folderName).appendingPathComponent("Payload")
            guard FileManager.default.fileExists(atPath: payloadDir.path) else {
                print("Error: Payload directory does not exist for ID: \(id)")
                pkgImageButton.image = nil
                selectedIconPath = nil
                return
            }

            let apps = try findFiles(inFolder: URL(fileURLWithPath: payloadDir.path), withExtension: "app")
            
            print("Found \(apps.count) .app files in \(payloadDir)")
            
            for app in apps {
                print(app.path)
                let appName = app.deletingPathExtension().lastPathComponent
                print("App name: \(appName)")
                
            }
            
            guard apps.first != nil else {
                throw NSError(domain: "ProcessingError", code: 110, userInfo: [NSLocalizedDescriptionKey: "No .app file found in path \(payloadDir)"])
            }

//            let apps = FileManager.default.enumerator(at: payloadDir, includingPropertiesForKeys: nil)?
//                .compactMap { $0 as? URL }
//                .filter { $0.pathExtension == "app" }

            if let appPath = apps.first {
                let image = NSWorkspace.shared.icon(forFile: appPath.path)
                image.size = NSSize(width: 512, height: 512)
                pkgImageButton.image = image
                selectedIconPath = appPath
                
                
                // Look up LSMinimumSystemVersion and update the text field
                let infoPlistPath = appPath.appendingPathComponent("Contents/Info.plist")
                if let infoPlist = NSDictionary(contentsOf: infoPlistPath),
                   let minOSVersion = infoPlist["LSMinimumSystemVersion"] as? String {
                    let display = displayName(forMinimumOS: minOSVersion)
                    pkgMinOSTextField.stringValue = display
                } else {
                    print("LSMinimumSystemVersion not found in Info.plist for app at: \(appPath.path)")
                    pkgMinOSTextField.stringValue = ""
                }
                
            } else {
                print("No .app found in Payload directory for ID: \(id)")
                pkgImageButton.image = nil
                selectedIconPath = nil
            }
        } catch {
            print("Error processing XML or locating Payload folder: \(error)")
            pkgImageButton.image = nil
            selectedIconPath = nil
        }
    }

    // MARK: - Helpers
    func unMountDiskImage() {
        // Unmount the DMG if needed
        if let pkgURL = pkgURL, pkgURL.path.contains("/mount/") {
            //            print("Unmounting DMG for path: \(pkgURL.path)")
            let unmountProcess = Process()
            unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            unmountProcess.arguments = ["detach", pkgURL.deletingLastPathComponent().path, "-quiet", "-force"]
            do {
                try unmountProcess.run()
                unmountProcess.waitUntilExit()
                                print("DMG unmounted successfully.")
            } catch {
                                print("Failed to unmount DMG: \(error)")
            }
        }
    }
    
    /// Determines the working folder URL for cleanup operations
    /// - Parameter fileURL: The file URL to find the working folder for
    /// - Returns: Working folder URL if found, nil otherwise
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
    
    /// Saves user-selected metadata overrides and dismisses the modal
    /// Processes selected checkboxes and saves any custom icon before notifying delegate
    @IBAction func saveChanges(_ sender: NSButton) {
        
        // Save the image if the checkbox is checked
        if useImageCheckbox.state == .on, let image = pkgImageButton.image {
            let folderName = "\(label)_\(itemGUID)"
            let folderPath = AppConstants.intuneomatorTempFolderURL
                .appendingPathComponent(folderName)
            let imageURL = folderPath
                .appendingPathComponent("\(label).png")
            
            // Save image to temp folder
            do {
                try FileManager.default.createDirectory(atPath: folderPath.path, withIntermediateDirectories: true, attributes: nil)
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try pngData.write(to: URL(fileURLWithPath: imageURL.path))
                    print("Image saved to: \(imageURL)")
                }
            } catch {
                print("Failed to save image: \(error)")
            }

            // copy to permanent location
            do {
                XPCManager.shared.importIconToLabel(imageURL.path, folderName) { success in
                    if success! {
                        // clean up temp folder/icon
                        do {
                            try FileManager.default.removeItem(atPath: folderPath.path)
                            print("Temp folder removed.")
                        } catch {
                            print("Failed to remove temp folder: \(error)")
                        }
                    } else {
                        print("Failed to reset icon")
                    }
                }
            }
            
        } else {
            print("No image to save.")
        }

        
        // Prepare data to pass back
        let pkgID = usePkgIDCheckbox.state == .on ? pkgIDPopupButton.titleOfSelectedItem : nil
        let pkgVersion = usePkgIDCheckbox.state == .on ? pkgVersionTextField.stringValue : nil
        let pkgPublisher = usePublisherCheckbox.state == .on ? pkgPublisherTextField.stringValue : nil
        let pkgMinOSVersion = useMinOSCheckbox.state == .on ? pkgMinOSTextField.stringValue : nil
        
        
        // Unmount the DMG if needed
        unMountDiskImage()
        
        // Clean up working folder
        if let workingFolder = workingFolderURL(for: pkgURL) {
            print("Working folder: \(workingFolder.path)")
            try? FileManager.default.removeItem(at: workingFolder)
        }


        // Notify the delegate and close the modal
        delegate?.pkgInspectorDidSave(pkgID: pkgID, pkgVersion: pkgVersion, pkgPublisher: pkgPublisher, pkgMinOSVersion: pkgMinOSVersion)
        dismiss(self)
    }
    
    /// Cancels the inspection process and dismisses the modal
    /// Performs cleanup operations before closing
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        
        // Unmount the DMG if needed
        unMountDiskImage()
        
        // Clean up working folder
        if let workingFolder = workingFolderURL(for: pkgURL) {
            print("Working folder: \(workingFolder.path)")
            try? FileManager.default.removeItem(at: workingFolder)
        }

        dismiss(self) // Dismiss without saving
    }
    
}


extension PkgInspectorViewController: ImageSelectorDelegate {
    func didSelectImage(_ image: NSImage, at path: URL) {
        // Set the selected image
        pkgImageButton.image = image
        selectedIconPath = path
        
        // Update the checkbox state
        updateCheckboxState()
    }
}
