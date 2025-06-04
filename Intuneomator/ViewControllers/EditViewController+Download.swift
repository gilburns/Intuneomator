//
//  EditViewController+Download.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

import Foundation
import AppKit

private let logType = "EditViewController"

extension EditViewController {
    
    // MARK: - Download Inspection
    @IBAction func inspectDownload(_ sender: Any) {
        
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
                    self.fieldIntuneVersion.stringValue = pkgVersion
                    self.trackChanges()
                }
            }
        }
        
        cleanupAfterProcessing()
    }
    
    
    @IBAction func handleRadioSelection(_ sender: NSButton) {
        if sender == radioYes {
            //            print("Yes selected")
            // Add logic for "Yes" selection
        } else if sender == radioNo {
            //            print("No selected")
            // Add logic for "No" selection
        }
        
        trackChanges()
    }
    
    
    
    // MARK: - Download Inspection Processing Methods
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
    private func processPkg(at location: URL) async {
        var signatureResult: [String: Any] = [:]
        
        // Decode the percent-encoded path
        let decodedPath = location.path.removingPercentEncoding ?? location.path
        
        //        print("Inspecting package at path: \(decodedPath)")
        
        guard FileManager.default.fileExists(atPath: location.path) else {
            //            print("Error: File does not exist at path \(location.path())")
            return
        }
        
        do {
            signatureResult = try SignatureInspector.inspectPackageSignature(pkgPath: decodedPath)
            //            print("Package Signature Inspection Result: \(signatureResult)")
        } catch {
            //            print("Error inspecting package signature: \(error)")
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
            unzip.arguments = ["-q", tempZipPath.path, "-d", tempDir.path]
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
    
    private func processPkgInDmg(at location: URL) async {
        let tempDir = location.deletingLastPathComponent()
        let mountPoint = tempDir.appendingPathComponent("mount")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            
            // Convert the DMG first if it has a Software License Agreement
            if dmgHasSLA(at: location.path) {
                let success = await convertDmgWithSLA(at: location.path)
                if success {
                    Logger.logUser("Successfully converted dmg with SLA", logType: logType)
                } else {
                    Logger.logUser("Failed to convert dmg with SLA", logType: logType)
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
            process.arguments = ["-q", tempZipPath.path, "-d", tempDir.path]
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
            //            print("Error processing app type: \(error)")
            showError(message: error.localizedDescription)
            cleanupAfterProcessing()
        }
    }
    
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
            print("Inspection failed: \(error)")
            cleanupAfterProcessing()
        }
    }
    
    private func presentPkgInspectorModal(pkgItems: [(String, String)], signature: [String: Any], pkgURL: URL) {
        guard let appData = appData else {
            //            print("Error: appData is missing.")
            return
        }
        
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
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
            //            print("Error processing app type: \(error)")
            showError(message: error.localizedDescription)
            cleanupAfterProcessing()
        }
    }
    
    private func processDmg(at location: URL, tempDir: URL, inspector: AppInspector) throws {
        // Mount, find app, and inspect
        //        print("Processing dmg at \(location)")
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
            //            print("App Signature Inspection Result: \(signatureResult)")
        } catch {
            //            print("Error inspecting app signature: \(error)")
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
    
    private func processAppInDmgInZip(at location: URL, tempDir: URL, inspector: AppInspector) throws {
        // Unzip and process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", location.path, "-d", tempDir.path]
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
            //            print("App Signature Inspection Result: \(signatureResult)")
        } catch {
            //            print("Error inspecting app signature: \(error)")
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
            cleanupAfterProcessing()
        }
    }
    
    
    
    private func presentAppInspectorModal(appPath: URL, appID: String, appVersion: String, appMinOSVersion: String, signature: [String: Any]) {
        guard let appData = appData else {
            return
        }
        
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
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
    private func dmgHasSLA(at path: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/hdiutil"
        process.arguments = ["imageinfo", path, "-plist"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            Logger.logUser("Error: Failed to check for SLA in DMG.", logType: logType)
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
            Logger.logUser("Error: Could not launch hdiutil: \(error)", logType: logType)
            return false
        }
        
        // Wait asynchronously for the process to finish
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }
        
        guard process.terminationStatus == 0 else {
            Logger.logUser("Error: hdiutil failed to convert DMG with SLA.", logType: logType)
            return false
        }
        
        guard FileManager.default.fileExists(atPath: tempFileURL.path) else {
            Logger.logUser("Error: Converted file not found at expected location.", logType: logType)
            return false
        }
        
        do {
            try FileManager.default.removeItem(atPath: path)
            try FileManager.default.moveItem(atPath: tempFileURL.path, toPath: path)
        } catch {
            Logger.logUser("Failed to finalize converted DMG: \(error)", logType: logType)
            return false
        }
        
        return true
    }
    
    
    
    // MARK: - Cleanup After Download Processing
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
    // Update progress bar as data is written
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
    
    // Handle download completion
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
    
    // Handle errors
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.showError(message: "Download failed: \(error.localizedDescription)")
                self.cleanupAfterProcessing()
            }
        }
    }
}
