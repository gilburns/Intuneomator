//
//  AppDelegate.swift
//  Intuneomator
//
//  Created by Gil Burns on 12/28/24.
//

import Cocoa
import Foundation

/// Private logging identifier for AppDelegate operations

/// Main application delegate responsible for application lifecycle management.
/// 
/// Handles application startup, shutdown, window management, and initial data loading.
/// Coordinates between the main application window and setup wizard based on first-run status.
/// 
/// **Key Responsibilities:**
/// - Application startup and initialization
/// - Data preloading (categories, groups, filters)
/// - First-run detection and wizard presentation
/// - Window management and lifecycle coordination
/// - Temporary directory cleanup and maintenance
/// - Application support folder creation
/// 
/// **Lifecycle Flow:**
/// 1. Application will finish launching - menu customization
/// 2. Application did finish launching - data loading and setup
/// 3. First-run check determines main window vs. setup wizard
/// 4. Application termination - cleanup operations
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    /// Weak reference to the main view controller (if needed for direct access)
    weak var mainViewController: MainViewController?
    
    /// Main window controller managing the primary application interface
    var mainWindowController: MainWindowController?
    
    /// Azure Storage test window controller (temporary)
    private var azureStorageTestWindowController: NSWindowController?
    
    /// Menu item for triggering full automation
    @IBOutlet weak var automationMenuItem: NSMenuItem?
    
    /// Menu item for opening discovered apps manager
    @IBOutlet weak var discoveredAppsMenuItem: NSMenuItem?
    
    /// Flag to prevent app termination during initialization
    private var isInitializing = true
    
    /// Handle for WindowActionHandler
    let windowActionHandler = WindowActionHandler()

    // MARK: - Application Lifecycle
    
    /// Called when the application has finished launching.
    /// 
    /// Performs initial setup including data preloading, directory cleanup,
    /// and first-run detection. Data loading happens asynchronously to avoid
    /// blocking the UI while essential application setup completes.
    /// 
    /// - Parameter notification: The application launch notification
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.info("Intuneomator starting...", category: .core, toUserDirectory: true)
        
        // Perform startup sequence in a single task to avoid nested task issues
        Task { @MainActor in
                        
            // Step 1: Check network connectivity first - app is useless without internet
            let hasConnectivity = await checkNetworkConnectivity()
            
            if !hasConnectivity {
                showNetworkConnectivityError()
                return
            }
            
            // Step 2: Check Graph authentication credentials
            let authStatus = await checkGraphAuthentication()
            
            if !authStatus.isValid {
                showGraphAuthenticationWarning(message: authStatus.message)
            }
            
            // Step 3: Proceed with app initialization regardless of auth status
            // (auth warning allows user to continue and fix the issue)
            
            // Step 4: Load initial data if auth is valid (in background)
            if authStatus.isValid {
                Task {
                    await loadInitialData()
                }
            }
            
            // Register the WindowActionHandler
            windowActionHandler.nextResponder = NSApp.nextResponder
            NSApp.nextResponder = windowActionHandler

            // Step 5: Perform synchronous setup operations
            cleanOldTempFolders()
            setupApplicationSupportFolders()
            checkForFirstRun()
        }
    }
    
    /// Called when the application is about to finish launching.
    /// 
    /// Performs early configuration before the main application setup.
    /// Disables automatic window tabbing and removes unwanted menu items.
    /// 
    /// - Parameter notification: The pre-launch notification
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Disable automatic window tabbing for better window management
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // Remove Format menu if present (not needed for this application)
        if let mainMenu = NSApp.mainMenu,
           let formatMenu = mainMenu.items.first(where: { $0.title == "Format"}) {
            mainMenu.removeItem(formatMenu)
        }
    }


    func applicationWillTerminate(_ aNotification: Notification) {
        // Notify titlebar accessory of termination for proper cleanup
        guard let windowController = NSApp.windows.first?.windowController as? MainWindowController,
              let window = windowController.window,
              let accessory = window.titlebarAccessoryViewControllers.first(where: { $0 is TitlebarAccessoryViewController }) as? TitlebarAccessoryViewController else {
            Logger.info("No titlebar accessory found for termination cleanup", category: .core, toUserDirectory: true)
            return
        }
        
        accessory.applicationWillTerminate(aNotification)
    }
    
    /// Determines if the application should terminate when the last window is closed.
    /// 
    /// - Parameter sender: The application instance
    /// - Returns: False during initialization to prevent premature termination, true otherwise
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate during initialization when showing alerts
        if isInitializing {
            Logger.info("Preventing app termination during initialization", category: .core, toUserDirectory: true)
            return false
        }
        return true
    }
    
    /// Indicates whether the application supports secure restorable state.
    /// 
    /// - Parameter app: The application instance
    /// - Returns: Always true, enabling secure state restoration
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    
    // MARK: - First Run Management
    
    /// Checks if this is the first application run and shows appropriate interface.
    /// 
    /// Determines whether to show the main application window or the setup wizard
    /// based on the first-run completion status retrieved from the XPC service.
    /// 
    /// **Flow:**
    /// - If first run is complete: Shows main application window
    /// - If first run is not complete: Opens setup wizard
    /// - Defaults to setup wizard if status cannot be determined
    private func checkForFirstRun() {
        XPCManager.shared.getFirstRunCompleted { [weak self] isComplete in
            DispatchQueue.main.async {
                let completed = isComplete ?? false
                if completed {
                    self?.showMainWindow()
                } else if let strongSelf = self {
                    strongSelf.openSetupWizard(strongSelf)
                }
                
                // Mark initialization as complete after window is shown
                self?.isInitializing = false
                Logger.info("App initialization complete, normal termination behavior restored", category: .core, toUserDirectory: true)
            }
        }
    }

    // MARK: - Window Management
    
    /// Shows the main application window.
    /// 
    /// Creates the main window controller if it doesn't exist and displays the primary
    /// application interface. Ensures proper delegate assignment and window presentation.
    /// 
    /// **Error Handling:**
    /// - Logs errors if storyboard instantiation fails
    /// - Logs errors if window controller or window is nil
    /// - Gracefully returns without crashing on failure
    func showMainWindow() {
        // Create main window controller if needed
        if mainWindowController == nil {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            guard let windowController = storyboard.instantiateController(withIdentifier: "MainWindow") as? MainWindowController else {
                Logger.info("Error: Failed to instantiate MainWindowController from storyboard", category: .core, toUserDirectory: true)
                return
            }
            mainWindowController = windowController
        }

        // Show the main window
        guard let windowController = mainWindowController,
              let window = windowController.window else {
            Logger.info("Error: MainWindowController or its window is nil", category: .core, toUserDirectory: true)
            return
        }
        
        window.delegate = windowController
        window.makeKeyAndOrderFront(nil)
    }

    /// Opens the setup wizard for first-run configuration.
    /// 
    /// Presents the Entra ID setup wizard that guides users through initial
    /// application configuration including authentication setup and basic settings.
    /// 
    /// - Parameter sender: The object that initiated the action
    /// 
    /// **Error Handling:**
    /// - Logs and returns gracefully if wizard controller instantiation fails
    /// - Logs and returns gracefully if window is nil
    @IBAction func openSetupWizard(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        guard let wizardWindow = storyboard.instantiateController(withIdentifier: "EntraIDWizardWindow") as? NSWindowController else {
            Logger.info("Error: Failed to instantiate wizard window controller", category: .core, toUserDirectory: true)
            return
        }
        
        guard let window = wizardWindow.window else {
            Logger.info("Error: Wizard window controller has no window", category: .core, toUserDirectory: true)
            return
        }
        
        window.center()
        wizardWindow.showWindow(self)
    }

    // MARK: - Data Loading
    
    /// Loads initial application data asynchronously.
    /// 
    /// Fetches essential data from Microsoft Graph API including mobile app categories,
    /// Entra groups, and assignment filters. This data is needed for proper application
    /// operation and is loaded in the background to avoid blocking the UI.
    /// 
    /// **Data Types Loaded:**
    /// - Mobile app categories for application classification
    /// - Entra ID groups for assignment targeting
    /// - Assignment filters for advanced deployment rules
    private func loadInitialData() async {
        do {
            // Use concurrent loading for better performance
            try await AppDataManager.shared.refreshAllData()
            Logger.info("All initial data loaded successfully", category: .core, toUserDirectory: true)
        } catch {
            Logger.info("Error during data initialization: \(error.localizedDescription)", category: .core, toUserDirectory: true)
        }
    }
    
    // MARK: - Directory Management
    
    /// Cleans up leftover temporary folders from previous application runs.
    /// 
    /// Scans the system temporary directory for folders with the "Intuneomator_" prefix
    /// and removes any that don't match the current session's temp folder. This prevents
    /// accumulation of temporary files from crashed or improperly terminated sessions.
    private func cleanOldTempFolders() {
        let tempDirectory = FileManager.default.temporaryDirectory
        let currentTempURL = AppConstants.intuneomatorTempFolderURL

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            let intuneomatorFolders = contents.filter { url in
                url.lastPathComponent.hasPrefix("Intuneomator_") && url != currentTempURL
            }
            
            for url in intuneomatorFolders {
                do {
                    // Verify it's actually a directory before attempting removal
                    let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                    guard resourceValues.isDirectory == true else { continue }
                    
                    try FileManager.default.removeItem(at: url)
                    Logger.info("Successfully removed old temp folder: \(url.path)", category: .core, toUserDirectory: true)
                } catch let error as CocoaError {
                    if error.code == .fileNoSuchFile {
                        Logger.info("Old temp folder already removed: \(url.path)", category: .core, toUserDirectory: true)
                    } else {
                        Logger.info("Failed to remove old temp folder: \(url.path), error: \(error.localizedDescription)", category: .core, toUserDirectory: true)
                    }
                } catch {
                    Logger.info("Unexpected error removing temp folder: \(url.path), error: \(error.localizedDescription)", category: .core, toUserDirectory: true)
                }
            }
            
            if intuneomatorFolders.isEmpty {
                Logger.info("No old temp folders found to clean up", category: .core, toUserDirectory: true)
            }
        } catch {
            Logger.info("Error reading temp directory contents: \(error.localizedDescription)", category: .core, toUserDirectory: true)
        }
    }
    
    // MARK: - Setup Folders and Installomator Labels

    /// Creates required application support directories if they don't exist.
    /// 
    /// Ensures that essential directories for application operation are available,
    /// creating them with appropriate permissions if needed. This prevents runtime
    /// errors when the application tries to access these directories later.
    private func setupApplicationSupportFolders() {
        Logger.info("Setting up application support directories...", category: .core, toUserDirectory: true)
        
        let requiredDirectories = [
            AppConstants.intuneomatorTempFolderURL
        ]

        for directoryURL in requiredDirectories {
            let directoryPath = directoryURL.path
            
            // Check if directory already exists
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory)
            
            if exists && isDirectory.boolValue {
                Logger.info("Directory already exists: \(directoryPath)", category: .core, toUserDirectory: true)
                continue
            }
            
            if exists && !isDirectory.boolValue {
                Logger.info("Error: File exists at directory path: \(directoryPath)", category: .core, toUserDirectory: true)
                continue
            }
            
            // Create directory with intermediate directories if needed
            do {
                try FileManager.default.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true,
                    attributes: [
                        .posixPermissions: 0o755 // Standard directory permissions
                    ]
                )
                Logger.info("Successfully created directory: \(directoryPath)", category: .core, toUserDirectory: true)
            } catch let error as CocoaError {
                Logger.info("Failed to create directory: \(directoryPath), CocoaError: \(error.localizedDescription)", category: .core, toUserDirectory: true)
            } catch {
                Logger.info("Failed to create directory: \(directoryPath), error: \(error.localizedDescription)", category: .core, toUserDirectory: true)
            }
        }
    }
    
    // MARK: - Menu Actions
    
    /// Handles the automation trigger menu item action.
    /// 
    /// Delegates to the main view controller's triggerFullAutomation action.
    /// This provides a menu-based way to trigger automation alongside any toolbar buttons.
    /// 
    /// - Parameter sender: The menu item that triggered this action
    @IBAction func triggerAutomationFromMenu(_ sender: Any) {
        // Delegate to the main view controller's automation trigger
        mainViewController?.triggerFullAutomation(sender)
    }
        
    /// Handles the check for updates menu item action.
    /// 
    /// Checks the server for available updates and prompts user to proceed with update if available.
    /// Shows appropriate dialogs for up-to-date status or update confirmation with warnings.
    /// 
    /// - Parameter sender: The menu item that triggered this action
    @IBAction func checkForUpdatesFromMenu(_ sender: Any) {
        Task { @MainActor in
            await checkForUpdates()
        }
    }
    
    /// Opens the Azure Storage test interface window.
    /// 
    /// Provides a temporary interface for testing Azure Storage upload, download link generation,
    /// and Teams notification functionality. This is intended for development and testing purposes.
    /// 
    /// - Parameter sender: The menu item that triggered this action
    @IBAction func openAzureStorageTestInterface(_ sender: Any) {
        // Close existing test window if open
        azureStorageTestWindowController?.close()
        
        let testController = AzureStorageTestViewController()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Azure Storage Test Interface"
        window.contentViewController = testController
        
        // Create window controller and retain it
        let windowController = NSWindowController(window: window)
        windowController.showWindow(self)
        window.center()
        
        // Set up window delegate to clean up when closed
        window.delegate = self
        
        // Retain the window controller
        self.azureStorageTestWindowController = windowController
    }
    
    // MARK: - Update Checking
    
    /// Checks for available application updates from the server
    /// 
    /// Downloads the latest version information and compares with current app version.
    /// Shows appropriate user dialogs for update status and confirmation.
    /// Triggers update process if user confirms and update is available.
    private func checkForUpdates() async {
        do {
            // Step 1: Check if automatic updates are enabled
            let canAutoUpdate = await checkIfAutoUpdateIsEnabled()
            
            // Step 2: Get current app version info
            guard let currentVersionInfo = getCurrentVersionInfo() else {
                await showUpdateError("Unable to determine current application version")
                return
            }
            
            // Step 3: Fetch latest version from server
            let latestVersionInfo = try await fetchLatestVersionInfo()
            
            // Step 4: Compare versions
            let updateAvailable = isUpdateAvailable(current: currentVersionInfo, latest: latestVersionInfo)
            
            if !updateAvailable {
                await showUpToDateDialog()
                return
            }
            
            // Step 5: Handle update based on auto-update capability
            if !canAutoUpdate {
                await showManualUpdateRequiredDialog(current: currentVersionInfo, latest: latestVersionInfo)
                return
            }
            
            // Step 6: Show update available dialog for automatic update
            let shouldUpdate = await showUpdateAvailableDialog(current: currentVersionInfo, latest: latestVersionInfo)
            if !shouldUpdate {
                return
            }
            
            // Step 7: Show final warning dialog
            let proceedWithUpdate = await showUpdateWarningDialog()
            if !proceedWithUpdate {
                return
            }
            
            // Step 8: Start update process
            await startUpdateProcess()
            
        } catch {
            Logger.error("Error checking for updates: \(error.localizedDescription)", category: .core, toUserDirectory: true)
            await showUpdateError("Failed to check for updates: \(error.localizedDescription)")
        }
    }
    
    /// Gets the current application version information from the bundle
    /// - Returns: Tuple containing (shortVersion, buildVersion) or nil if unable to read
    private func getCurrentVersionInfo() -> (shortVersion: String, buildVersion: String)? {
        guard let bundle = Bundle.main.infoDictionary else { return nil }
        
        let shortVersion = bundle["CFBundleShortVersionString"] as? String ?? ""
        let buildVersion = bundle["CFBundleVersion"] as? String ?? ""
        
        guard !shortVersion.isEmpty && !buildVersion.isEmpty else { return nil }
        
        return (shortVersion: shortVersion, buildVersion: buildVersion)
    }
    
    /// Fetches the latest version information from the server
    /// - Returns: Tuple containing (shortVersion, buildVersion) from server
    /// - Throws: URLError or other networking errors
    private func fetchLatestVersionInfo() async throws -> (shortVersion: String, buildVersion: String) {
        guard let url = URL(string: "https://intuneomator.org/downloads/latest-version.txt") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let versionString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Parse version string like "1.0.0.164"
        let components = versionString.split(separator: ".")
        guard components.count == 4 else {
            throw URLError(.cannotParseResponse)
        }
        
        let shortVersion = "\(components[0]).\(components[1]).\(components[2])"
        let buildVersion = String(components[3])
        
        return (shortVersion: shortVersion, buildVersion: buildVersion)
    }
    
    /// Determines if an update is available by comparing version numbers
    /// - Parameters:
    ///   - current: Current app version info
    ///   - latest: Latest available version info
    /// - Returns: True if update is available, false if current is up-to-date or newer
    private func isUpdateAvailable(current: (shortVersion: String, buildVersion: String), 
                                 latest: (shortVersion: String, buildVersion: String)) -> Bool {
        // First compare semantic versions (major.minor.patch)
        let currentSemanticVersion = parseSemanticVersion(current.shortVersion)
        let latestSemanticVersion = parseSemanticVersion(latest.shortVersion)
        
        // Compare major version
        if latestSemanticVersion.major != currentSemanticVersion.major {
            return latestSemanticVersion.major > currentSemanticVersion.major
        }
        
        // Compare minor version
        if latestSemanticVersion.minor != currentSemanticVersion.minor {
            return latestSemanticVersion.minor > currentSemanticVersion.minor
        }
        
        // Compare patch version
        if latestSemanticVersion.patch != currentSemanticVersion.patch {
            return latestSemanticVersion.patch > currentSemanticVersion.patch
        }
        
        // If semantic versions are identical, compare build numbers
        guard let currentBuild = Int(current.buildVersion),
              let latestBuild = Int(latest.buildVersion) else {
            // Fallback to string comparison if conversion fails
            return latest.buildVersion > current.buildVersion
        }
        
        return latestBuild > currentBuild
    }
    
    /// Parses a semantic version string into major, minor, and patch components
    /// - Parameter versionString: Version string in format "major.minor.patch"
    /// - Returns: Tuple with major, minor, and patch version numbers
    private func parseSemanticVersion(_ versionString: String) -> (major: Int, minor: Int, patch: Int) {
        let components = versionString.split(separator: ".").compactMap { Int($0) }
        
        let major = components.count > 0 ? components[0] : 0
        let minor = components.count > 1 ? components[1] : 0
        let patch = components.count > 2 ? components[2] : 0
        
        return (major: major, minor: minor, patch: patch)
    }
    
    /// Shows dialog indicating the app is up-to-date
    @MainActor
    private func showUpToDateDialog() {
        let alert = NSAlert()
        alert.messageText = "Intuneomator is Up-to-Date"
        alert.informativeText = "You are running the latest version of Intuneomator."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Shows dialog with update available information and asks for user confirmation
    /// - Parameters:
    ///   - current: Current app version info
    ///   - latest: Latest available version info
    /// - Returns: True if user wants to update, false otherwise
    @MainActor
    private func showUpdateAvailableDialog(current: (shortVersion: String, buildVersion: String),
                                         latest: (shortVersion: String, buildVersion: String)) async -> Bool {
        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "Update Available"
            alert.informativeText = """
            A new version of Intuneomator is available.
            
            Current Version: \(current.shortVersion) (Build \(current.buildVersion))
            Available Version: \(latest.shortVersion) (Build \(latest.buildVersion))
            
            Would you like to update the application and service?
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Update")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            continuation.resume(returning: response == .alertFirstButtonReturn)
        }
    }
    
    /// Shows final warning dialog before proceeding with update
    /// - Returns: True if user wants to proceed, false otherwise
    @MainActor
    private func showUpdateWarningDialog() async -> Bool {
        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "Confirm Update"
            alert.informativeText = """
            ⚠️ Warning: The application will automatically quit and the update will proceed.
            
            The update process will:
            • Close Intuneomator
            • Update the application and service
            • Restart the application when complete
            
            Do you want to continue?
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Continue")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            continuation.resume(returning: response == .alertFirstButtonReturn)
        }
    }
    
    /// Shows error dialog for update checking failures
    /// - Parameter message: Error message to display
    @MainActor
    private func showUpdateError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Checks if automatic updates are enabled by examining launch daemon and update mode
    /// - Returns: True if automatic updates can proceed, false if manual update is required
    private func checkIfAutoUpdateIsEnabled() async -> Bool {
        // Check 1: Verify launch daemon plist exists and is enabled
        let launchDaemonPath = "/Library/LaunchDaemons/com.gilburns.intuneomator.updatecheck.plist"
        
        guard FileManager.default.fileExists(atPath: launchDaemonPath) else {
            Logger.info("Launch daemon plist not found at \(launchDaemonPath)", category: .core, toUserDirectory: true)
            return false
        }
        
        // Read and parse the plist
        guard let plistData = FileManager.default.contents(atPath: launchDaemonPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            Logger.info("Failed to read launch daemon plist", category: .core, toUserDirectory: true)
            return false
        }
        
        // Check if daemon is disabled in plist
        if let disabled = plist["Disabled"] as? Bool, disabled {
            Logger.info("Launch daemon is disabled in plist", category: .core, toUserDirectory: true)
            return false
        }
        
        // Check 2: Verify update mode is set to automatic (0) not notify-only (1)
        let updateMode = await getUpdateMode()
        if updateMode == 1 {
            Logger.info("Update mode is set to notify-only (1)", category: .core, toUserDirectory: true)
            return false
        }
        
        Logger.info("Automatic updates are enabled", category: .core, toUserDirectory: true)
        return true
    }
    
    /// Gets the current update mode from XPC service
    /// - Returns: Update mode integer (0: automatic, 1: notify only)
    private func getUpdateMode() async -> Int {
        return await withCheckedContinuation { continuation in
            XPCManager.shared.getIntuneomatorUpdateMode { mode in
                continuation.resume(returning: mode ?? 0)
            }
        }
    }
    
    /// Shows dialog for manual update requirement with option to open releases page
    /// - Parameters:
    ///   - current: Current app version info
    ///   - latest: Latest available version info
    @MainActor
    private func showManualUpdateRequiredDialog(current: (shortVersion: String, buildVersion: String),
                                              latest: (shortVersion: String, buildVersion: String)) async {
        await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "Update Available - Manual Update Required"
            alert.informativeText = """
            A new version of Intuneomator is available, but automatic updates are disabled.
            
            Current Version: \(current.shortVersion) (Build \(current.buildVersion))
            Available Version: \(latest.shortVersion) (Build \(latest.buildVersion))
            
            Automatic updates are disabled either because:
            • The update daemon is disabled
            • Update mode is set to "Notify Only"
            
            Would you like to open the releases page to manually download the update?
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open Releases Page")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open releases page in default browser
                if let url = URL(string: "https://github.com/gilburns/Intuneomator/releases") {
                    NSWorkspace.shared.open(url)
                    Logger.info("Opened releases page for manual update", category: .core, toUserDirectory: true)
                }
            }
            
            continuation.resume()
        }
    }
    
    /// Starts the update process by showing progress dialog and triggering update daemon
    @MainActor
    private func startUpdateProcess() async {
        // Create and show progress window
        let progressAlert = NSAlert()
        progressAlert.messageText = "Update in Progress"
        progressAlert.informativeText = "The update process has started. Please wait..."
        progressAlert.alertStyle = .informational
        
        // Add progress indicator
        let progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.startAnimation(nil)
        progressAlert.accessoryView = progressIndicator
        
        // Show the alert in a non-blocking way
        DispatchQueue.main.async {
            progressAlert.runModal()
        }
        
        // Trigger the update daemon
        XPCManager.shared.triggerDaemon(triggerType: "updatecheck") { result in
            DispatchQueue.main.async {
                if let (success, message) = result {
                    if success {
                        Logger.info("✅ Update process triggered successfully", category: .core, toUserDirectory: true)
                        // The update daemon will handle quitting the app and updating
                    } else {
                        Logger.error("❌ Failed to trigger update process: \(message ?? "Unknown error")", category: .core, toUserDirectory: true)
                        
                        // Close progress alert and show error
                        NSApp.abortModal()
                        
                        let errorAlert = NSAlert()
                        errorAlert.messageText = "Update Failed"
                        errorAlert.informativeText = "Failed to start update process: \(message ?? "Unknown error")"
                        errorAlert.alertStyle = .critical
                        errorAlert.addButton(withTitle: "OK")
                        errorAlert.runModal()
                    }
                } else {
                    Logger.error("❌ XPC connection failed during update trigger", category: .core, toUserDirectory: true)
                    
                    // Close progress alert and show error
                    NSApp.abortModal()
                    
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Update Failed"
                    errorAlert.informativeText = "Unable to communicate with update service"
                    errorAlert.alertStyle = .critical
                    errorAlert.addButton(withTitle: "OK")
                    errorAlert.runModal()
                }
            }
        }
    }
    
    // MARK: - Network Connectivity Validation
    
    /// Checks for internet connectivity using multiple reliable methods.
    /// 
    /// This method performs a comprehensive network connectivity check suitable for
    /// an application that requires cloud service access. It tests actual internet
    /// connectivity rather than just local network availability.
    /// 
    /// **Test Methods:**
    /// - Primary: Attempts to connect to Microsoft's Graph API endpoint
    /// - Fallback: Tests connectivity to reliable public DNS servers
    /// 
    /// - Returns: True if internet connectivity is available, false otherwise
    private func checkNetworkConnectivity() async -> Bool {
        // Test 1: Try to connect to Microsoft Graph API (our primary dependency)
        if await testConnectivity(to: "https://graph.microsoft.com", timeout: 10.0) {
            Logger.info("Network connectivity confirmed via Microsoft Graph endpoint", category: .core, toUserDirectory: true)
            return true
        }
        
        // Test 2: Fallback to reliable public services
        let fallbackHosts = [
            "https://www.google.com",
            "https://www.cloudflare.com",
            "https://1.1.1.1"
        ]
        
        for host in fallbackHosts {
            if await testConnectivity(to: host, timeout: 5.0) {
                Logger.info("Network connectivity confirmed via fallback host: \(host)", category: .core, toUserDirectory: true)
                return true
            }
        }
        
        Logger.error("No network connectivity detected - all tests failed", category: .core, toUserDirectory: true)
        return false
    }
    
    /// Tests connectivity to a specific URL with timeout.
    /// 
    /// Performs a lightweight HEAD request to test connectivity without downloading
    /// large amounts of data. Uses a reasonable timeout to avoid hanging.
    /// 
    /// - Parameters:
    ///   - urlString: The URL to test connectivity to
    ///   - timeout: Maximum time to wait for response in seconds
    /// - Returns: True if the URL is reachable, false otherwise
    private func testConnectivity(to urlString: String, timeout: TimeInterval) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                // Accept any response in the 200-399 range as "connected"
                let isConnected = (200...399).contains(httpResponse.statusCode)
                Logger.info("Connectivity test to \(urlString): \(isConnected ? "Success" : "Failed") (Status: \(httpResponse.statusCode))", category: .core, toUserDirectory: true)
                return isConnected
            }
            
            return false
        } catch {
            Logger.info("Connectivity test to \(urlString) failed: \(error.localizedDescription)", category: .core, toUserDirectory: true)
            return false
        }
    }
    
    /// Shows a network connectivity error dialog and quits the application.
    /// 
    /// Presents a user-friendly dialog explaining that internet connectivity is required
    /// for the application to function, then gracefully terminates the application.
    /// 
    /// **Dialog Features:**
    /// - Clear explanation of the requirement
    /// - Helpful troubleshooting suggestions
    /// - Graceful application termination
    private func showNetworkConnectivityError() {
        let alert = NSAlert()
        alert.messageText = "No Internet Connection"
        alert.informativeText = """
        Intuneomator requires an active internet connection to function properly. The application connects to Microsoft Graph API and other cloud services to manage your Intune environment.
        
        Please check:
        • Your network connection
        • Firewall or proxy settings
        • VPN connectivity (if required)
        
        The application will now quit. Please restart once you have established an internet connection.
        """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")
        
        // Show the alert and quit when dismissed
        alert.runModal()
        
        Logger.info("Application terminating due to lack of network connectivity", category: .core, toUserDirectory: true)
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Graph Authentication Validation
    
    /// Checks Microsoft Graph authentication credentials and validates connectivity.
    /// 
    /// This method performs a comprehensive check of Graph authentication:
    /// 1. Verifies that either certificate or client secret credentials exist
    /// 2. Attempts to validate credentials using the Graph API
    /// 3. Returns detailed status for user feedback
    /// 
    /// **Authentication Methods Checked:**
    /// - Certificate-based authentication (.p12 files)
    /// - Client secret authentication
    /// 
    /// - Returns: Authentication status with descriptive message
    private func checkGraphAuthentication() async -> (isValid: Bool, message: String) {
        return await withCheckedContinuation { continuation in
            // First check if any credentials exist
            XPCManager.shared.privateKeyExists { [weak self] certExists in
                guard self != nil else {
                    continuation.resume(returning: (false, "Internal error during credential check"))
                    return
                }
                
                XPCManager.shared.entraIDSecretKeyExists { secretExists in
                    let certExists = certExists ?? false
                    let secretExists = secretExists ?? false
                    
                    // If no credentials exist at all (likely first run - user will see Setup Wizard)
                    guard certExists || secretExists else {
                        Logger.info("Graph auth check: No credentials found (likely first run)", category: .core, toUserDirectory: true)
                        continuation.resume(returning: (true, "No authentication configured yet"))
                        return
                    }
                    
                    // Credentials exist, now validate them
                    Logger.info("Graph auth check: Found credentials (cert: \(certExists), secret: \(secretExists))", category: .core, toUserDirectory: true)
                    
                    XPCManager.shared.validateCredentials { validationResult in
                        let isValid = validationResult ?? false
                        
                        if isValid {
                            Logger.info("Graph auth check: Credentials validated successfully", category: .core, toUserDirectory: true)
                            continuation.resume(returning: (true, "Microsoft Graph authentication is working properly"))
                        } else {
                            let authType = certExists ? "certificate" : "client secret"
                            let message = "Microsoft Graph authentication failed. Your \(authType) credentials may be expired, invalid, or lack proper permissions. Please check your authentication settings."
                            Logger.info("Graph auth check: Credential validation failed", category: .core, toUserDirectory: true)
                            continuation.resume(returning: (false, message))
                        }
                    }
                }
            }
        }
    }
    
    /// Shows a warning dialog about Graph authentication issues but allows app to continue.
    /// 
    /// Unlike the network connectivity error, this warning is non-blocking to allow users
    /// to access the settings and fix authentication issues without restarting the app.
    /// 
    /// **Dialog Features:**
    /// - Clear description of the authentication problem
    /// - Guidance on how to resolve the issue
    /// - Non-blocking to allow access to settings
    /// 
    /// - Parameter message: Descriptive message about the authentication issue
    private func showGraphAuthenticationWarning(message: String) {
        let alert = NSAlert()
        alert.messageText = "Microsoft Graph Authentication Issue"
        alert.informativeText = """
        \(message)
        
        Some features that depend on Microsoft Graph API may not work properly:
        • Discovered Apps Manager
        • Application category assignment
        • Entra group management
        • Assignment filter configuration
        
        You can continue using the application and fix this issue by:
        1. Opening Settings from the main window
        2. Configuring your authentication credentials
        3. Ensuring proper API permissions are granted
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        
        Logger.info("Showing Graph authentication warning to user", category: .core, toUserDirectory: true)
        alert.runModal()
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    
    /// Called when a window is about to close
    /// Cleans up the Azure Storage test window controller when it's closed
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // Check if this is the Azure Storage test window
        if window.title == "Azure Storage Test Interface" {
            azureStorageTestWindowController = nil
            Logger.info("Azure Storage test window closed and cleaned up", category: .core, toUserDirectory: true)
        }
    }
}
