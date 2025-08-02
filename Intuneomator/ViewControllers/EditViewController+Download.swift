//
//  EditViewController+Download.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

///
///  EditViewController+Download.swift
///  Intuneomator
///
///  Extension for `EditViewController` to handle downloading and inspecting packages and apps.
///  Provides methods to download files from a URL, track progress, process different archive types
///  (pkg, zip, dmg, app), invoke inspectors for metadata extraction, and clean up temporary resources.
///

import Foundation
import AppKit


/// Adds download inspection functionality to `EditViewController`.
/// Implements methods to initiate a download, handle URLSession delegate callbacks for progress and completion,
/// process downloaded files based on type, and invoke inspection workflows for pkg and app metadata.
extension EditViewController {
    
    // MARK: - Download Inspection
    
    /// Initiates download of the URL entered in `fieldDownloadURL` and prepares for inspection.
    /// Validates the URL, creates a temporary unique folder, configures a URLSession with self as delegate,
    /// disables UI controls, and shows a determinate progress bar for the download.
    /// - Parameter sender: The control that triggered the download action.
    @IBAction func inspectDownload(_ sender: Any) {
        
        guard let appLabel = appData?.label else {
            return
        }
        if appLabel == "adobecreativeclouddesktop" {
            showError(message: "Adobe Creative Cloud Desktop is not supported for inspection.\n\nThere is a separate workflow for this app.")
            return
        }
        
        guard let downloadURL = URL(string: fieldDownloadURL.stringValue) else {
            showError(message: "Invalid download URL")
            self.cleanupAfterProcessing()
            return
        }
        
        buttonInspectDownload.title = "Downloading..."
        buttonInspectDownload.isEnabled = false
        fieldDownloadURL.isEnabled = false
        
        
        let tempDir = AppConstants.intuneomatorTempFolderURL
        let uniqueFolder = tempDir.appendingPathComponent(UUID().uuidString) // Create a unique subfolder
        
        do {
            // Create the unique folder
            try FileManager.default.createDirectory(at: uniqueFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            showError(message: "Failed to create temporary folder: \(error.localizedDescription)")
            return
        }
        
        // Configure the session
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        session.sessionDescription = uniqueFolder.path
        
        // Start the download task
        let downloadTask = session.downloadTask(with: downloadURL)
        downloadTask.resume()
        
        // Reset and show progress bar
        DispatchQueue.main.async {
            self.progPkgInspect.isHidden = false
            self.progPkgInspect.isIndeterminate = false
            self.progPkgInspect.doubleValue = 0
        }
    }
    
    
    /// Presents a modal pop-up menu to allow the user to select a package ID-version pair.
    /// If the `items` array is empty, displays an error alert. Otherwise, shows an NSAlert with
    /// a NSPopUpButton listing choices. On selection, populates `fieldIntuneID` and `fieldIntuneVersion`.
    /// - Parameter items: Array of strings formatted as "id - version" for user selection.
    private func presentMenu(items: [String]) {
        guard !items.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No valid pkg metadata found"
            alert.runModal()
            cleanupAfterProcessing()
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Select an Option"
        alert.informativeText = "Choose the appropriate identifier-version pair from the list."
        
        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 30))
        popUp.addItems(withTitles: items)
        alert.accessoryView = popUp
        
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn, let selectedItem = popUp.titleOfSelectedItem {
            // Split selected item into id and version
            let components = selectedItem.split(separator: " - ")
            if components.count == 2 {
                let pkgID = String(components[0])
                let pkgVersion = String(components[1])
                
                // Populate the new fields
                DispatchQueue.main.async {
                    self.fieldIntuneID.stringValue = pkgID
                    AppDataManager.shared.currentAppBundleID = pkgID
                    self.fieldIntuneVersion.stringValue = pkgVersion
                    self.trackChanges()
                }
            }
        }
        
        cleanupAfterProcessing()
    }
    
    
    /// Handles changes to the "Ignore Version" radio buttons.
    /// Invokes `trackChanges()` after any selection to detect unsaved changes.
    /// - Parameter sender: The radio button that was clicked.
    @IBAction func handleRadioSelection(_ sender: NSButton) {
        if sender == radioYes {
            // Add logic for "Yes" selection
        } else if sender == radioNo {
            // Add logic for "No" selection
        }
        
        trackChanges()
    }
    
    
    
    // MARK: - Download Inspection Processing Methods
    
    /// Processes the downloaded file based on the selected `fieldType`.
    /// On the main thread, hides progress UI and restores button states, then dispatches
    /// to specialized methods to handle pkg, pkgInZip, pkgInDmg, pkgInDmgInZip, or app types.
    /// - Parameter location: The local file URL where the download was saved.
    private func processDownloadedFile(at location: URL) async {
        let fieldType = fieldType.stringValue.lowercased()
        
        DispatchQueue.main.async {
            self.progPkgInspect.isHidden = true
            self.progPkgInspect.stopAnimation(self)
            self.setFinalDownloadSize()
            
            self.buttonInspectDownload.title = "Download and Inspect"
            self.buttonInspectDownload.isEnabled = true
            self.fieldDownloadURL.isEnabled = true
        }
        
        
        switch fieldType {
        case "pkg":
            await processPkg(at: location)
        case "pkginzip":
            await processPkgInZip(at: location)
        case "pkgindmg":
            await processPkgInDmg(at: location)
        case "pkgindmginzip":
            await processPkgInDmgInZip(at: location)
        case "dmg", "appindmginzip", "zip", "tbz":
            let appInspector = AppInspector()
            processAppType(location: location, type: fieldType, inspector: appInspector)
        default:
            showError(message: "Unsupported type: \(fieldType)")
            cleanupAfterProcessing()
        }
    }
    
    
    // MARK: - PKG Types
    
    /// Inspects a standalone .pkg file: verifies existence, performs signature inspection,
    /// and invokes `PkgInspector` to extract metadata. On completion, calls `handleInspectionResultPkg`.
    /// - Parameter location: File URL of the downloaded .pkg.
    // MARK: - PKG Types
    private func processPkg(at location: URL) async {
        var signatureResult: [String: Any] = [:]
        
        // Decode the percent-encoded path
        let decodedPath = location.path.removingPercentEncoding ?? location.path
        
        
        guard FileManager.default.fileExists(atPath: location.path) else {
            return
        }
        
        do {
            signatureResult = try SignatureInspector.inspectPackageSignature(pkgPath: decodedPath)
        } catch {
            signatureResult = [
                "Accepted": false,
                "DeveloperID": "Unknown",
                "DeveloperTeam": "Unknown"
            ]
        }
        
        let pkgInspector = PkgInspector()
        pkgInspector.inspect(pkgAt: location) { result in
            DispatchQueue.main.async {
                self.handleInspectionResultPkg(result, type: "pkg", signature: signatureResult, fileURL: location)
            }
        }
    }
    
    
    /// Handles a .zip containing a .pkg: unzips to a temporary folder, locates the first .pkg,
    /// and forwards it to `processPkg`. If any step fails, shows an error and cleans up.
    /// - Parameter location: File URL of the downloaded zip archive.
    private func processPkgInZip(at location: URL) async {
        let tempDir = AppConstants.intuneomatorTempFolderURL
            .appendingPathComponent(UUID().uuidString)
        let tempZipPath = tempDir.appendingPathComponent("downloaded.zip")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.moveItem(at: location, to: tempZipPath)
            
            // Unzip the file
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzip.arguments = ["-qq", tempZipPath.path, "-d", tempDir.path]
            
            // Redirect output to prevent terminal spam
            unzip.standardOutput = FileHandle.nullDevice
            unzip.standardError = FileHandle.nullDevice

            try unzip.run()
            unzip.waitUntilExit()
            
            guard unzip.terminationStatus == 0 else {
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to unzip pkg in zip"])
            }
            
            // Recursively find .pkg file
            func findFirstPkgFile(in directory: URL) throws -> URL {
                let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                for item in contents {
                    if item.pathExtension == "pkg" {
                        return item
                    }
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                        if let found = try? findFirstPkgFile(in: item) {
                            return found
                        }
                    }
                }
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No .pkg file found after unzipping"])
            }
            
            let pkgPath = try findFirstPkgFile(in: tempDir)
            await processPkg(at: pkgPath)
            
        } catch {
            showError(message: error.localizedDescription)
            cleanupAfterProcessing()
        }
    }
    

    /// Handles a .dmg containing a .pkg: mounts the DMG (converting if SLA present),
    /// searches for the .pkg, copies it to a temp directory, unmounts the image, and processes the pkg.
    /// - Parameter location: File URL of the downloaded disk image.
    private func processPkgInDmg(at location: URL) async {
        let tempDir = location.deletingLastPathComponent()
        let mountPoint = tempDir.appendingPathComponent("mount")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            
            // Convert the DMG first if it has a Software License Agreement
            if dmgHasSLA(at: location.path) {
                let success = await convertDmgWithSLA(at: location.path)
                if success {
                    Logger.info("Successfully converted dmg with SLA", category: .core, toUserDirectory: true)
                } else {
                    Logger.info("Failed to convert dmg with SLA", category: .core, toUserDirectory: true)
                    throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert dmg containing pkg"])
                }
            }
            
            // Mount the dmg
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            process.arguments = ["attach", location.path, "-mountpoint", mountPoint.path, "-nobrowse", "-quiet"]
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to mount dmg containing pkg"])
            }
            
            // Search for .pkg
            let pkgFiles = try FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "pkg" }
            
            guard let pkgPath = pkgFiles.first else {
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No pkg found in dmg"])
            }
            
            let pkgName = pkgPath.lastPathComponent
            let destinationpkgPath = tempDir.appendingPathComponent(pkgName)
            
            if FileManager.default.fileExists(atPath: pkgPath.path) {
                try FileManager.default.copyItem(atPath: pkgPath.path, toPath: destinationpkgPath.path)
            }
            
            // Unmount dmg
            let unmountProcess = Process()
            unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            unmountProcess.arguments = ["detach", mountPoint.path, "-quiet", "-force"]
            try unmountProcess.run()
            unmountProcess.waitUntilExit()
            
            await processPkg(at: destinationpkgPath)
        } catch {
            showError(message: error.localizedDescription)
            cleanupAfterProcessing()
        }
    }
    
    
    /// Handles a .zip containing a .dmg: unzips to a temporary folder, finds the .dmg,
    /// and delegates to `processPkgInDmg`.
    /// - Parameter location: File URL of the downloaded zip archive.
    private func processPkgInDmgInZip(at location: URL) async {
        let tempDir = AppConstants.intuneomatorTempFolderURL
            .appendingPathComponent(UUID().uuidString)
        
        let tempZipPath = tempDir.appendingPathComponent("downloaded.zip")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.moveItem(at: location, to: tempZipPath)
            
            // Unzip
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-qq", tempZipPath.path, "-d", tempDir.path]
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to unzip dmg in zip"])
            }
            
            // Find .dmg
            let dmgFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "dmg" }
            
            guard let dmgPath = dmgFiles.first else {
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No dmg found in zip"])
            }
            
            await processPkgInDmg(at: dmgPath)
        } catch {
            showError(message: error.localizedDescription)
            cleanupAfterProcessing()
        }
    }


    /// Handles the result of pkg inspection.
    /// On success with non-empty items, presents the `PkgInspectorViewController` modal
    /// to let the user choose the correct ID-version. On failure, logs the error and cleans up.
    /// - Parameters:
    ///   - result: Result containing an array of (id, version) tuples or an error.
    ///   - type: The type tag (e.g., "pkg").
    ///   - signature: Dictionary with signature inspection information.
    ///   - fileURL: File URL of the inspected pkg.
    private func handleInspectionResultPkg(_ result: Result<[(String, String)], Error>, type: String, signature: [String: Any], fileURL: URL) {
        switch result {
        case .success(let items):
            guard !items.isEmpty else {
                return
            }
            
            // Always present the appropriate modal dialog
            presentPkgInspectorModal(
                pkgItems: items,
                signature: signature,
                pkgURL: fileURL
            )
        case .failure(let error):
            Logger.error("Inspection failed: \(error)", category: .core, toUserDirectory: true)
            cleanupAfterProcessing()
        }
    }


    /// Presents the `PkgInspectorViewController` as a sheet, passing in pkg metadata and signature.
    /// Configures expectedTeamID, label, GUID, and directory path before showing.
    /// - Parameters:
    ///   - pkgItems: Array of (id, version) tuples from inspection.
    ///   - signature: Signature inspection result dictionary.
    ///   - pkgURL: File URL of the pkg to inspect.
    private func presentPkgInspectorModal(pkgItems: [(String, String)], signature: [String: Any], pkgURL: URL) {
        guard let appData = appData else {
            return
        }
        
        let storyboard = NSStoryboard(name: "Inspectors", bundle: nil)
        let pkgInspectorVC = storyboard.instantiateController(withIdentifier: "PkgInspectorViewController") as! PkgInspectorViewController
        
        // Pass data to the modal
        pkgInspectorVC.pkgItems = pkgItems
        pkgInspectorVC.pkgSignature = signature
        pkgInspectorVC.pkgURL = pkgURL
        pkgInspectorVC.expectedTeamID = appData.expectedTeamID // Use appData for expectedTeamID
        pkgInspectorVC.label = appData.label // Use appData for label
        pkgInspectorVC.itemGUID = appData.guid // Use appData for guid
        pkgInspectorVC.directoryPath = AppConstants.intuneomatorManagedTitlesFolderURL.path
        pkgInspectorVC.delegate = self
        
        // Show the modal
        presentAsSheet(pkgInspectorVC)
    }


    // MARK: - APP Types
    
    /// Processes downloaded app-type content based on `type` (dmg, appInDmgInZip, zip, tbz).
    /// Delegates to specialized methods or throws an error for unsupported types.
    /// - Parameters:
    ///   - location: File URL of the downloaded resource.
    ///   - type: Lowercased string indicating the content type.
    ///   - inspector: `AppInspector` instance to extract app metadata.
    private func processAppType(location: URL, type: String, inspector: AppInspector) {
        let tempDir = URL(fileURLWithPath: location.deletingLastPathComponent().path)
        
        do {
            switch type {
            case "dmg":
                try processDmg(at: location, tempDir: tempDir, inspector: inspector)
            case "appindmginzip":
                try processAppInDmgInZip(at: location, tempDir: tempDir, inspector: inspector)
            case "zip", "tbz":
                try processCompressedApp(at: location, tempDir: tempDir, inspector: inspector)
            default:
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported app type"])
            }
        } catch {
            showError(message: error.localizedDescription)
            cleanupAfterProcessing()
        }
    }


    /// Mounts a DMG, finds the contained .app bundle, inspects its signature,
    /// invokes `AppInspector` to extract app ID, version, and minOS, and presents the modal.
    /// - Parameters:
    ///   - location: File URL of the DMG.
    ///   - tempDir: Temporary directory URL for mounting and extraction.
    ///   - inspector: `AppInspector` instance for metadata extraction.
    private func processDmg(at location: URL, tempDir: URL, inspector: AppInspector) throws {
        // Mount, find app, and inspect
        let mountPoint = tempDir.appendingPathComponent("mount")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", location.path, "-mountpoint", mountPoint.path, "-nobrowse", "-quiet"]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to mount dmg"])
        }
        
        // Find the app bundle
        let apps = try FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        
        guard let appPath = apps.first else {
            throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No app found in dmg"])
        }
        
        // Inspect app signature
        var signatureResult: [String: Any] = [:]
        do {
            signatureResult = try SignatureInspector.inspectAppSignature(appPath: appPath.path)
        } catch {
        }
        
        // Inspect app ID and version
        inspector.inspect(appAt: appPath) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (id, version, minOSVersion)):
                    // Call the AppInspectorViewController modal
                    self.presentAppInspectorModal(
                        appPath: appPath,
                        appID: id,
                        appVersion: version,
                        appMinOSVersion: minOSVersion,
                        signature: signatureResult                    )
                case .failure(let error):
                    self.showError(message: "App inspection failed: \(error.localizedDescription)")
                }
            }
        }
    }


    /// Unzips a dmg-in-zip archive, finds the DMG, and calls `processDmg` to handle the app.
    /// - Parameters:
    ///   - location: File URL of the zip containing a DMG.
    ///   - tempDir: Temporary directory URL for extraction.
    ///   - inspector: `AppInspector` instance.
    private func processAppInDmgInZip(at location: URL, tempDir: URL, inspector: AppInspector) throws {
        // Unzip and process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-qq", location.path, "-d", tempDir.path]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to unzip dmg in zip"])
        }
        
        let dmgFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "dmg" }
        
        guard let dmgPath = dmgFiles.first else {
            throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No dmg found in zip"])
        }
        
        try processDmg(at: dmgPath, tempDir: tempDir, inspector: inspector)
    }


    /// Expands a compressed app archive (tar, zip, tbz), locates the .app bundle,
    /// inspects its signature, uses `AppInspector` to extract metadata, and calls `handleInspectionResultApp`.
    /// - Parameters:
    ///   - location: File URL of the compressed app archive.
    ///   - tempDir: Temporary directory URL for extraction.
    ///   - inspector: `AppInspector` instance.
    private func processCompressedApp(at location: URL, tempDir: URL, inspector: AppInspector) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xf", location.path, "-C", tempDir.path]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to expand compressed app"])
        }
        
        let apps = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        
        guard let appPath = apps.first else {
            throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No app found in compressed archive"])
        }
        
        // Inspect app signature
        var signatureResult: [String: Any] = [:]
        do {
            signatureResult = try SignatureInspector.inspectAppSignature(appPath: appPath.path)
        } catch {
        }
        
        // Inspect the app for its ID and version
        inspector.inspect(appAt: appPath) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (id, version, minOSVersion)):
                    // Wrap the single result in an array
                    self.handleInspectionResultApp(
                        .success([(id, version, minOSVersion)]),
                        type: "app",
                        signature: signatureResult,
                        fileURL: appPath
                    )
                case .failure(let error):
                    self.handleInspectionResultApp(.failure(error), type: "app", signature: signatureResult, fileURL: appPath)
                }
            }
        }
    }


    /// Handles the result of app inspection.
    /// On success with non-empty items, presents the `AppInspectorViewController` modal
    /// for the first (id, version, minOS) tuple. On failure or empty result, cleans up.
    /// - Parameters:
    ///   - result: Result containing array of (id, version, minOS) tuples or an error.
    ///   - type: The type tag (e.g., "app").
    ///   - signature: Signature inspection data.
    ///   - fileURL: File URL of the inspected app bundle.
    private func handleInspectionResultApp(_ result: Result<[(String, String, String?)], Error>, type: String, signature: [String: Any], fileURL: URL) {
        switch result {
        case .success(let items):
            guard !items.isEmpty else {
                cleanupAfterProcessing()
                return
            }
            
            // Always present the appropriate modal dialog
            presentAppInspectorModal(
                appPath: fileURL,
                appID: items.first?.0 ?? "",   // Default to the first item
                appVersion: items.first?.1 ?? "", // Default to the first version
                appMinOSVersion: items.first?.2 ?? "",
                signature: signature
            )
            
        case .failure(let error):
            Logger.error("Processing failed: \(error)")
            cleanupAfterProcessing()
        }
    }


    /// Presents the `AppInspectorViewController` as a sheet, passing in app metadata and signature.
    /// Configures expectedTeamID, label, GUID, and directory path before showing.
    /// - Parameters:
    ///   - appPath: File URL of the .app bundle.
    ///   - appID: String of the app bundle identifier.
    ///   - appVersion: String of the app version.
    ///   - appMinOSVersion: Minimum OS version string.
    ///   - signature: Dictionary of signature inspection data.
    private func presentAppInspectorModal(appPath: URL, appID: String, appVersion: String, appMinOSVersion: String, signature: [String: Any]) {
        guard let appData = appData else {
            return
        }
        
        let storyboard = NSStoryboard(name: "Inspectors", bundle: nil)
        let appInspectorVC = storyboard.instantiateController(withIdentifier: "AppInspectorViewController") as! AppInspectorViewController
        
        // Pass data to the modal
        appInspectorVC.appPath = appPath
        appInspectorVC.appID = appID
        appInspectorVC.appVersion = appVersion
        appInspectorVC.appMinOSVersion = appMinOSVersion
        appInspectorVC.signature = signature
        appInspectorVC.expectedTeamID = fieldExpectedTeamID.stringValue
        appInspectorVC.label = appData.label // Use appData for label
        appInspectorVC.itemGUID = appData.guid // Use appData for guid
        appInspectorVC.directoryPath = AppConstants.intuneomatorManagedTitlesFolderURL.path
        appInspectorVC.delegate = self
        
        // Show the modal
        presentAsSheet(appInspectorVC)
    }
    
    
    // MARK: - DMG SLA
    
    /// Checks if a DMG includes a Software License Agreement (SLA).
    /// Runs `hdiutil imageinfo -plist` and parses the `Software License Agreement` property.
    /// - Parameter path: File system path of the DMG.
    /// - Returns: `true` if the DMG contains an SLA, `false` otherwise.
    private func dmgHasSLA(at path: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/hdiutil"
        process.arguments = ["imageinfo", path, "-plist"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            Logger.info("Error: Failed to check for SLA in DMG.", category: .core, toUserDirectory: true)
            return false
        }
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
              let properties = plist["Properties"] as? [String: Any],
              let hasSLA = properties["Software License Agreement"] as? Bool else {
            return false
        }
        
        return hasSLA
    }
    
    
    /// Converts a DMG with an SLA to a read/write format using `hdiutil convert`.
    /// Writes to a temporary location and replaces the original DMG upon success.
    /// - Parameter path: File system path of the DMG with SLA.
    /// - Returns: `true` if conversion succeeded, `false` on error.
    func convertDmgWithSLA(at path: String) async -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent(fileName)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["convert", "-format", "UDRW", "-o", tempFileURL.path, path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
        } catch {
            Logger.info("Error: Could not launch hdiutil: \(error)", category: .core, toUserDirectory: true)
            return false
        }
        
        // Wait asynchronously for the process to finish
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }
        
        guard process.terminationStatus == 0 else {
            Logger.info("Error: hdiutil failed to convert DMG with SLA.", category: .core, toUserDirectory: true)
            return false
        }
        
        guard FileManager.default.fileExists(atPath: tempFileURL.path) else {
            Logger.info("Error: Converted file not found at expected location.", category: .core, toUserDirectory: true)
            return false
        }
        
        do {
            try FileManager.default.removeItem(atPath: path)
            try FileManager.default.moveItem(atPath: tempFileURL.path, toPath: path)
        } catch {
            Logger.info("Failed to finalize converted DMG: \(error)", category: .core, toUserDirectory: true)
            return false
        }
        
        return true
    }
    
    
    
    // MARK: - Cleanup After Download Processing
    
    /// Resets the progress UI and hides the progress bar after download or inspection steps.
    /// Invoked when processing completes or errors occur.
    func cleanupAfterProcessing() {
        DispatchQueue.main.async {
            self.progPkgInspect.isIndeterminate = false
            self.progPkgInspect.doubleValue = 0
            self.progPkgInspect.isHidden = true
            self.progPkgInspect.stopAnimation(self)
            //            self.setFinalDownloadSize()
        }
    }


    // MARK: - URLSessionDownloadDelegate Methods
    
    /// URLSessionDownloadDelegate callback to update download progress.
    /// Calculates fraction complete and updates the determinate progress bar and `fieldDownloadSize` text.
    /// - Parameters:
    ///   - session: The URLSession instance.
    ///   - downloadTask: The download task reporting progress.
    ///   - bytesWritten: Number of bytes written since last callback.
    ///   - totalBytesWritten: Total bytes written so far.
    ///   - totalBytesExpectedToWrite: Total bytes expected for the download.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return } // Avoid division by zero
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            // Update progress bar
            self.progPkgInspect.doubleValue = progress * 100
            
            // Format download sizes
            let totalMB = Double(totalBytesExpectedToWrite) / 1_048_576
            let downloadedMB = Double(totalBytesWritten) / 1_048_576
            
            if totalMB > 1000 {
                let totalGB = totalMB / 1024
                let downloadedGB = downloadedMB / 1024
                if totalGB > 1 {
                    self.fieldDownloadSize.stringValue = String(format: "%.2f GB of %.2f GB", downloadedGB, totalGB)
                } else {
                    self.fieldDownloadSize.stringValue = String(format: "%.1f MB of %.2f GB", downloadedMB, totalGB)
                }
            } else {
                self.fieldDownloadSize.stringValue = String(format: "%.1f MB of %.1f MB", downloadedMB, totalMB)
            }
        }
    }


    /// URLSessionDownloadDelegate callback invoked when download finishes.
    /// Validates the HTTP response, converts progress bar to indeterminate, determines file name
    /// from headers or URL, moves the file to the unique temp folder, and calls `processDownloadedFile`.
    /// - Parameters:
    ///   - session: The URLSession instance.
    ///   - downloadTask: The completed download task.
    ///   - location: Temporary file URL of the downloaded data.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Check the HTTP response for success
        if let response = downloadTask.response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
            DispatchQueue.main.async {
                self.showError(message: "Download failed: HTTP status code \(response.statusCode)")
                self.cleanupAfterProcessing()
            }
            return
        }
        
        DispatchQueue.main.async {
            // Change progress bar to indeterminate for post-download tasks
            self.progPkgInspect.isIndeterminate = true
            self.progPkgInspect.startAnimation(self)
        }
        
        let uniqueFolderPath = session.sessionDescription ?? ""
        let uniqueFolder = URL(fileURLWithPath: uniqueFolderPath)
        
        // Determine the file name
        let fileName: String
        
        if let httpResponse = downloadTask.response as? HTTPURLResponse {
            // Check Content-Disposition header for a file name
            if let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String,
               let matchedFileName = contentDisposition.split(separator: ";")
                .first(where: { $0.contains("filename=") })?
                .split(separator: "=").last?.trimmingCharacters(in: CharacterSet.whitespaces.union(.init(charactersIn: "\""))) {
                fileName = matchedFileName
            } else if let finalURL = httpResponse.url {
                // Fallback to the last path component of the redirected URL
                fileName = finalURL.lastPathComponent.isEmpty ? "downloaded.tmp" : finalURL.lastPathComponent
            } else {
                // Fallback if no name can be determined
                fileName = "downloaded.tmp"
            }
        } else {
            // Absolute fallback
            fileName = "downloaded.tmp"
        }
        
        let destinationPath = uniqueFolder.appendingPathComponent(fileName)
        
        do {
            // Move the downloaded file to the destination
            try FileManager.default.moveItem(at: location, to: destinationPath)
            
            Task {
                await self.processDownloadedFile(at: destinationPath)
            }
            
        } catch {
            DispatchQueue.main.async {
                self.showError(message: "Failed to move downloaded file: \(error.localizedDescription)")
                self.cleanupAfterProcessing()
            }
        }
    }


    /// URLSessionDownloadDelegate callback invoked when download finishes.
    /// Validates the HTTP response, converts progress bar to indeterminate, determines file name
    /// from headers or URL, moves the file to the unique temp folder, and calls `processDownloadedFile`.
    /// - Parameters:
    ///   - session: The URLSession instance.
    ///   - downloadTask: The completed download task.
    ///   - location: Temporary file URL of the downloaded data.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.showError(message: "Download failed: \(error.localizedDescription)")
                self.cleanupAfterProcessing()
            }
        }
    }
}
