//
//  MainWindowController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/4/25.
//

import Cocoa

/// Main window controller responsible for managing the primary application window lifecycle.
/// 
/// This controller handles window initialization, position restoration, titlebar accessories,
/// and cleanup operations. It implements NSWindowDelegate to respond to window events and
/// maintain application state across launches.
/// 
/// **Key Responsibilities:**
/// - Window frame persistence and restoration
/// - Titlebar accessory management
/// - Temporary directory cleanup on window close
/// - Application termination handling
/// 
/// **Window Management:**
/// - Automatically restores saved window position on launch
/// - Centers window if no saved position exists or position is invalid
/// - Validates restored frames to ensure reasonable window dimensions
/// - Saves current position before closing for next launch
class MainWindowController: NSWindowController, NSWindowDelegate {

    /// UserDefaults key used for persisting window frame between application launches
    private let windowFrameKey = "MainWindowFrame"
    
    // MARK: - Lifecycle Management

    /// Called after the window loads from the storyboard.
    /// 
    /// Performs initial window setup including position restoration, delegate assignment,
    /// and titlebar accessory configuration. Posts notification to inform other components
    /// that the main window has been loaded and is ready for use.
    override func windowDidLoad() {
        super.windowDidLoad()

        // Restore window position with validation
        if let frameDescription = UserDefaults.standard.string(forKey: windowFrameKey),
           !frameDescription.isEmpty,
           let window = self.window {
            // Validate frame description format before applying
            let frameRect = NSRectFromString(frameDescription)
            if !frameRect.isEmpty && frameRect.width > 100 && frameRect.height > 100 {
                window.setFrame(frameRect, display: true)
            } else {
                Logger.logApp("Invalid saved window frame, centering window")
                window.center()
            }
        } else {
            self.window?.center()
        }
        
        // Set the delegate
        self.window?.delegate = self

        self.showWindow(self)
        
        // Notify other components that main window is ready
        NotificationCenter.default.post(name: .mainWindowDidLoad, object: nil)

        // Prevent duplicates
        guard let window = self.window,
              !window.titlebarAccessoryViewControllers.contains(where: { $0 is TitlebarAccessoryViewController }) else {
            return
        }

        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let accessory = storyboard.instantiateController(withIdentifier: "TitlebarAccessory") as? TitlebarAccessoryViewController else {
            return
        }

        accessory.layoutAttribute = .right
        window.addTitlebarAccessoryViewController(accessory)

        // Initialize titlebar accessory functionality
        accessory.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidLaunch")))
        
        
        // Set window title with current version information
        if let window = self.window {
            window.title = "Intuneomator \(formattedAppVersion())"
        }

    }
    
    // MARK: - Window Delegate Methods

    /// Called when the window is about to close.
    /// 
    /// Performs cleanup operations including saving window position and removing
    /// temporary files. This ensures a clean application shutdown.
    /// 
    /// - Parameter notification: The window close notification
    func windowWillClose(_ notification: Notification) {
        saveWindowFrame()
        cleanupTempDirectory()
    }

    
    /// Called to determine if the window should be allowed to close.
    /// 
    /// Saves the current window position and initiates application termination.
    /// Always returns true to allow the window to close.
    /// 
    /// - Parameter sender: The window requesting to close
    /// - Returns: Always true to allow closure
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        saveWindowFrame()
        NSApplication.shared.terminate(self)
        return true
    }
    
    // MARK: - Helper Methods
    
    /// Saves the current window frame to UserDefaults for restoration on next launch
    private func saveWindowFrame() {
        if let frameDescriptor = self.window?.frameDescriptor {
            UserDefaults.standard.set(frameDescriptor, forKey: windowFrameKey)
        }
    }
    
    /// Cleans up temporary directory with proper error handling
    private func cleanupTempDirectory() {
        let tempPath = AppConstants.intuneomatorTempFolderURL.path
        guard FileManager.default.fileExists(atPath: tempPath) else {
            Logger.logApp("Temp directory does not exist, skipping cleanup")
            return
        }
        
        do {
            try FileManager.default.removeItem(atPath: tempPath)
            Logger.logApp("Successfully deleted temp directory: \(tempPath)")
        } catch let error as CocoaError {
            if error.code == .fileNoSuchFile {
                Logger.logApp("Temp directory already removed: \(tempPath)")
            } else {
                Logger.logApp("Failed to delete temp directory: \(error.localizedDescription)")
            }
        } catch {
            Logger.logApp("Unexpected error deleting temp directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Version Information
    
    /// Reads CFBundleShortVersionString and CFBundleVersion from Info.plist.
    /// 
    /// Extracts version information from the application bundle and formats it
    /// for display in the window title.
    /// 
    /// - Returns: Formatted version string in the format "vX.Y.Z"
    private func formattedAppVersion() -> String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber  = info?["CFBundleVersion"]            as? String ?? "?"
        return "v\(shortVersion).\(buildNumber)"
    }

}

