//
//  AppDelegate.swift
//  Intuneomator
//
//  Created by Gil Burns on 12/28/24.
//

import Cocoa
import Foundation

/// Private logging identifier for AppDelegate operations
private let logType = "AppDelegate"

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

    // MARK: - Application Lifecycle
    
    /// Called when the application has finished launching.
    /// 
    /// Performs initial setup including data preloading, directory cleanup,
    /// and first-run detection. Data loading happens asynchronously to avoid
    /// blocking the UI while essential application setup completes.
    /// 
    /// - Parameter notification: The application launch notification
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.logApp("Intuneomator starting...", logType: logType)
        
        // Perform initial data loading asynchronously
        Task {
            await loadInitialData()
        }
        
        // Perform synchronous setup operations
        cleanOldTempFolders()
        setupApplicationSupportFolders()
        checkForFirstRun()
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
            Logger.logApp("No titlebar accessory found for termination cleanup", logType: logType)
            return
        }
        
        accessory.applicationWillTerminate(aNotification)
    }
    
    /// Determines if the application should terminate when the last window is closed.
    /// 
    /// - Parameter sender: The application instance
    /// - Returns: Always true, allowing the application to quit when all windows close
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
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
                Logger.logApp("Error: Failed to instantiate MainWindowController from storyboard", logType: logType)
                return
            }
            mainWindowController = windowController
        }

        // Show the main window
        guard let windowController = mainWindowController,
              let window = windowController.window else {
            Logger.logApp("Error: MainWindowController or its window is nil", logType: logType)
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
            Logger.logApp("Error: Failed to instantiate wizard window controller", logType: logType)
            return
        }
        
        guard let window = wizardWindow.window else {
            Logger.logApp("Error: Wizard window controller has no window", logType: logType)
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
            Logger.logApp("All initial data loaded successfully", logType: logType)
        } catch {
            Logger.logApp("Error during data initialization: \(error.localizedDescription)", logType: logType)
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
                    Logger.logApp("Successfully removed old temp folder: \(url.path)", logType: logType)
                } catch let error as CocoaError {
                    if error.code == .fileNoSuchFile {
                        Logger.logApp("Old temp folder already removed: \(url.path)", logType: logType)
                    } else {
                        Logger.logApp("Failed to remove old temp folder: \(url.path), error: \(error.localizedDescription)", logType: logType)
                    }
                } catch {
                    Logger.logApp("Unexpected error removing temp folder: \(url.path), error: \(error.localizedDescription)", logType: logType)
                }
            }
            
            if intuneomatorFolders.isEmpty {
                Logger.logApp("No old temp folders found to clean up", logType: logType)
            }
        } catch {
            Logger.logApp("Error reading temp directory contents: \(error.localizedDescription)", logType: logType)
        }
    }
    
    // MARK: - Setup Folders and Installomator Labels

    /// Creates required application support directories if they don't exist.
    /// 
    /// Ensures that essential directories for application operation are available,
    /// creating them with appropriate permissions if needed. This prevents runtime
    /// errors when the application tries to access these directories later.
    private func setupApplicationSupportFolders() {
        Logger.logApp("Setting up application support directories...", logType: logType)
        
        let requiredDirectories = [
            AppConstants.intuneomatorTempFolderURL
        ]

        for directoryURL in requiredDirectories {
            let directoryPath = directoryURL.path
            
            // Check if directory already exists
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory)
            
            if exists && isDirectory.boolValue {
                Logger.logApp("Directory already exists: \(directoryPath)", logType: logType)
                continue
            }
            
            if exists && !isDirectory.boolValue {
                Logger.logApp("Error: File exists at directory path: \(directoryPath)", logType: logType)
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
                Logger.logApp("Successfully created directory: \(directoryPath)", logType: logType)
            } catch let error as CocoaError {
                Logger.logApp("Failed to create directory: \(directoryPath), CocoaError: \(error.localizedDescription)", logType: logType)
            } catch {
                Logger.logApp("Failed to create directory: \(directoryPath), error: \(error.localizedDescription)", logType: logType)
            }
        }
    }
}
