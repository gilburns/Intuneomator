//
//  AppDelegate.swift
//  Intuneomator
//
//  Created by Gil Burns on 12/28/24.
//

import Cocoa
import Foundation

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    weak var mainViewController: MainViewController?
    var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.logUser("Intuneomator starting...", logType: "AppDelegate")
        Task {
            do {
                // Fetch mobile app categories
                try await AppDataManager.shared.fetchMobileAppCategories()
                Logger.logUser("Mobile app categories loaded successfully.", logType: "AppDelegate")
                
                // Fetch Entra groups
                try await AppDataManager.shared.fetchEntraGroups()
                Logger.logUser("Entra ID groups loaded successfully.", logType: "AppDelegate")
                
                // Fetch Entra Application Filters
                try await AppDataManager.shared.fetchEntraFilters()
                Logger.logUser("Entra Application Filters loaded successfully.", logType: "AppDelegate")
                Logger.logUser("Filters: \(AppDataManager.shared.entraFilters)", logType: "AppDelegate")
                
                
            } catch {
                Logger.logUser("Error during initialization: \(error.localizedDescription)", logType: "AppDelegate")
            }
        }
        
        cleanOldTempFolders()
        
        setupApplicationSupportFolders()
        
        checkForFirstRun()

    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        // Clean up any resources or save state if necessary
        if let windowController = NSApp.windows.first?.windowController as? MainWindowController,
           let accessory = windowController.window?.titlebarAccessoryViewControllers.first(where: { $0 is TitlebarAccessoryViewController }) as? TitlebarAccessoryViewController {
            accessory.applicationWillTerminate(aNotification)
        }

    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    
    func checkForFirstRun() {
        // Get First Run Status
        XPCManager.shared.getFirstRunCompleted { isComplete in
            DispatchQueue.main.async {
                let completed = isComplete ?? false
                completed ? self.showMainWindow() : self.openSetupWizard(self)            }
        }
    }

    // MARK: - Main Window
    
    func showMainWindow() {
        if mainWindowController == nil {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            mainWindowController = storyboard.instantiateController(withIdentifier: "MainWindow") as? MainWindowController
        }

        if let window = mainWindowController?.window {
            window.delegate = mainWindowController // Ensure delegate is set
            window.makeKeyAndOrderFront(nil)
        } else {
            Logger.logUser("Error: mainWindowController has no window.", logType: "AppDelegate")
        }
    }

    // MARK: - Welcome Wizard Window
        
    @IBAction func openSetupWizard(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        if let wizardWindow = storyboard.instantiateController(withIdentifier: "EntraIDWizardWindow") as? NSWindowController {
            wizardWindow.window?.center()
            wizardWindow.showWindow(self)
        }
    }

    
    // Check for left over temp folders and clean up
    private func cleanOldTempFolders() {
        let tempDirectory = FileManager.default.temporaryDirectory

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil, options: [])
            
            for url in contents {
                let folderName = url.lastPathComponent
                if folderName.hasPrefix("Intuneomator_") {
                    if url != AppConstants.intuneomatorTempFolderURL {
                        do {
                            try FileManager.default.removeItem(at: url)
                            Logger.logUser("Removed old temp folder: \(url.path)", logType: "AppDelegate")
                        } catch {
                            Logger.logUser("Failed to remove old temp folder: \(url.path), error: \(error)", logType: "AppDelegate")
                        }
                    }
                }
            }
        } catch {
            Logger.logUser("Error reading contents of temp directory: \(error)", logType: "AppDelegate")
        }
    }
    
    // MARK: - Setup Folders and Installomator Labels

    private func setupApplicationSupportFolders() {
        Logger.logUser("Checking for and creating application support folders...", logType: "AppDelegate")
        let folders = [
            AppConstants.intuneomatorTempFolderURL.path
        ]

        // Create required folders if they don't exist
        for folder in folders {
            if !FileManager.default.fileExists(atPath: folder) {
                do {
                    try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
                    Logger.logUser("Created folder: \(folder)", logType: "AppDelegate")
                } catch {
                    Logger.logUser("Failed to create folder: \(folder), error: \(error)", logType: "AppDelegate")
                }
            }
        }
    }
    
    // MARK: - Application Wide Actions
    @IBAction func openScriptManagerWindowAppDelegate(_ sender: Any?) {
        // Perform the action, e.g., notify MainViewController
//        mainViewController?.openScriptManagerWindow(sender as Any)
    }

    @IBAction func openCustomAttributeManagerWindowAppDelegate(_ sender: Any?) {
        // Perform the action, e.g., notify MainViewController
//        mainViewController?.openCustomAttributeManagerWindow(sender as Any)
    }

    @IBAction func openAppCategoriesManagerWindowAppDelegate(_ sender: Any?) {
        // Perform the action, e.g., notify MainViewController
//        mainViewController?.openAppCategoriesManagerWindow(sender as Any)
    }

    @IBAction func openDiscoveredAppsWindowAppDelegate(_ sender: Any?) {
        // Perform the action, e.g., notify MainViewController
//        mainViewController?.openDiscoveredAppsManagerWindow(sender as Any)
    }


}
