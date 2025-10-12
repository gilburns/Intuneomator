//
//  MainViewController+DataHandling.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/11/25.
//

import Cocoa

/**
 * MainViewController+DataHandling
 *
 * This extension handles all data loading and processing operations for the MainViewController.
 * It manages the asynchronous loading of app data from the file system and provides search functionality.
 *
 * ## Responsibilities:
 * - Load app data from managed titles directory
 * - Process subdirectories and parse plist files
 * - Handle search/filtering of app data
 * - Manage concurrent data processing
 * - Update UI after data operations
 *
 * ## Data Flow:
 * 1. `loadAppData()` initiates XPC scan and directory enumeration
 * 2. `processSubdirectory()` handles individual app folder processing
 * 3. Data is parsed from plist files and stored in AppInfo structures
 * 4. Results are sorted and assigned to data arrays
 * 5. UI is updated on main thread
 */
extension MainViewController {
    
    // MARK: - Data Loading
    
    /**
     * Loads app data from the managed titles directory.
     * 
     * This method performs the primary data loading operation for the application:
     * 1. Initiates XPC service scan for Installomator labels
     * 2. Enumerates subdirectories in the managed titles folder
     * 3. Processes each subdirectory concurrently using TaskGroup
     * 4. Updates UI on main thread with loaded and sorted data
     * 
     * The operation is performed asynchronously to avoid blocking the UI thread.
     * Progress is indicated via the progress spinner and status label.
     * 
     * ## Concurrency:
     * Uses Swift's TaskGroup for concurrent processing of multiple app directories,
     * significantly improving load times for large numbers of managed apps.
     */
    func loadAppData() {

        Task {
            do {
                // Load local data first (non-blocking, immediate UI population)
                let directoryContents = try FileManager.default.contentsOfDirectory(
                    at: URL(fileURLWithPath: AppConstants.intuneomatorManagedTitlesFolderURL.path),
                    includingPropertiesForKeys: nil
                )
                let subdirectories = directoryContents.filter { $0.hasDirectoryPath }
                
                // Run scripts and load plist files concurrently
                await withTaskGroup(of: AppInfo?.self) { taskGroup in
                    for subdir in subdirectories {
                        taskGroup.addTask {
                            return await self.processSubdirectory(subdir)
                        }
                    }

                    var loadedAppData: [AppInfo] = []
                    for await appInfo in taskGroup {
                        if let appInfo = appInfo {
                            loadedAppData.append(appInfo)
                        }
                    }
                    DispatchQueue.main.async {
                        self.appData = loadedAppData.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
                        self.filteredAppData = loadedAppData.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })

                        // Update UI immediately with local data
                        self.progressSpinner.stopAnimation(self)
                        self.statusLabel.isHidden = true
                        self.tableView.reloadData()
                        self.setLabelCount()

                        // Now run the XPC scan in the background (non-blocking)
                        self.runBackgroundXPCScan()
                    }
                }
            } catch {
                Logger.info("Error loading app data: \(error)", category: .core, toUserDirectory: true)
                DispatchQueue.main.async {
                    self.progressSpinner.stopAnimation(self)
                    self.statusLabel.stringValue = "Error loading app data"
                }
            }
        }
        
    }

    // MARK: - Search and Filtering
    
    /**
     * Handles real-time search filtering as the user types in the search field.
     * 
     * This method is called automatically when the search field text changes.
     * It performs case-insensitive filtering on the app label field and immediately
     * updates the table view to show matching results.
     * 
     * - Parameter obj: The text change notification from the search field
     * 
     * ## Search Behavior:
     * - Empty query shows all apps
     * - Non-empty query filters by label containing the search text
     * - Search is case-insensitive and uses localized string comparison
     * - Results update immediately as user types
     */
    func controlTextDidChange(_ obj: Notification) {
        let query = appSearchField.stringValue
        filteredAppData = query.isEmpty
            ? appData
            : appData.filter { $0.label.localizedCaseInsensitiveContains(query) }
        tableView.reloadData()
        setLabelCount()
    }


    // MARK: - Data Processing
    
    /**
     * Processes a single app subdirectory and extracts AppInfo data.
     * 
     * This method handles the parsing of individual app directories within the
     * managed titles folder. Each directory should contain a plist file with
     * app configuration data.
     * 
     * - Parameter subdir: URL of the subdirectory to process
     * - Returns: AppInfo object if parsing succeeds, nil otherwise
     * 
     * ## Directory Structure Expected:
     * ```
     * labelname_guid/
     *   ├── labelname.plist    (configuration data)
     *   ├── labelname.png      (app icon)
     *   ├── metadata.json      (deployment settings)
     *   └── other files...
     * ```
     * 
     * ## Error Handling:
     * - Invalid directory format: logs error and returns nil
     * - Missing plist file: logs error and returns nil
     * - Plist parsing failure: logs error and returns nil
     * - All errors are logged using the application's logging system
     */
    func processSubdirectory(_ subdir: URL) async -> AppInfo? {
        let directoryName = subdir.lastPathComponent
        
        // Declare variables
        var name: String?
        
        let parts = directoryName.split(separator: "_")

        if parts.count == 2 {
            name = String(parts[0])
        } else {
            Logger.info("Invalid directory format for: \(directoryName)", category: .core, toUserDirectory: true)
            return nil
        }
        
        guard let validName = name else { return nil }
        let plistPath = subdir.appendingPathComponent("\(validName).plist")

        // Load plist file
        if FileManager.default.fileExists(atPath: plistPath.path) {
            do {
                let plistData = try Data(contentsOf: plistPath)
                guard let plistDictionary = try PropertyListSerialization.propertyList(
                    from: plistData,
                    options: [],
                    format: nil
                ) as? [String: Any] else {
                    Logger.info("Failed to parse plist for \(directoryName)", category: .core, toUserDirectory: true)
                    return nil
                }

                return AppInfo(
                    CLIArguments: plistDictionary["CLIArguments"] as? String ?? "",
                    CLIInstaller: plistDictionary["CLIInstaller"] as? String ?? "",
                    appName: plistDictionary["appName"] as? String ?? "",
                    appNewVersion: plistDictionary["appNewVersion"] as? String ?? "",
                    archiveName: plistDictionary["archiveName"] as? String ?? "",
                    blockingProcesses: plistDictionary["blockingProcesses"] as? String ?? "",
                    curlOptions: plistDictionary["curlOptions"] as? String ?? "",
                    downloadFile: plistDictionary["downloadFile"] as? String ?? "",
                    downloadURL: plistDictionary["downloadURL"] as? String ?? "",
                    expectedTeamID: plistDictionary["expectedTeamID"] as? String ?? "",
                    guid: plistDictionary["guid"] as? String ?? "",
                    installerTool: plistDictionary["installerTool"] as? String ?? "",
                    label: plistDictionary["label"] as? String ?? "",
                    labelIcon: plistDictionary["labelIcon"] as? String ?? "",
                    name: plistDictionary["name"] as? String ?? directoryName,
                    packageID: plistDictionary["packageID"] as? String ?? "",
                    pkgName: plistDictionary["pkgName"] as? String ?? "",
                    targetDir: plistDictionary["targetDir"] as? String ?? "",
                    transformToPkg: plistDictionary["asPkg"] as? Bool ?? false,
                    type: plistDictionary["type"] as? String ?? "",
                    versionKey: plistDictionary["versionKey"] as? String ?? ""
                )
            } catch {
                Logger.info("Error loading plist for \(directoryName): \(error)", category: .core, toUserDirectory: true)
            }
        } else {
            Logger.info("Plist file not found for directory: \(directoryName)", category: .core, toUserDirectory: true)
        }

        return nil
    }

    // MARK: - Background Operations

    /**
     * Runs the XPC scan operation in the background after UI has loaded.
     *
     * This method implements the non-blocking startup approach by running the
     * potentially slow XPC scan operation after the UI has been populated with
     * local data. This prevents startup hangs while still running the scan.
     */
    private func runBackgroundXPCScan() {
        Logger.info("Starting background XPC scan...", category: .core, toUserDirectory: true)

        // Run XPC scan in background queue to avoid blocking UI
        DispatchQueue.global(qos: .utility).async { [weak self] in
            XPCManager.shared.scanAllInstallomatorManagedLabels() { success in
                DispatchQueue.main.async {
                    if let success = success, success {
                        Logger.info("Background XPC scan completed successfully", category: .core, toUserDirectory: true)
                        // Could optionally reload data here if the scan modified anything
                        // self?.tableView.reloadData()
                    } else {
                        Logger.warning("Background XPC scan failed or returned no result", category: .core, toUserDirectory: true)
                    }
                }
            }
        }
    }

}
