//
//  AppDelegate.swift
//  Intuneomator
//
//  Created by Gil Burns on 12/28/24.
//

import Cocoa
import Foundation

private let logType = "AppDelegate"

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    weak var mainViewController: MainViewController?
    var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.logApp("Intuneomator starting...", logType: logType)
        Task {
            do {
                // Fetch mobile app categories
                try await AppDataManager.shared.fetchMobileAppCategories()
                Logger.logApp("Mobile app categories loaded successfully.", logType: logType)
                
                // Fetch Entra groups
                try await AppDataManager.shared.fetchEntraGroups()
                Logger.logApp("Entra ID groups loaded successfully.", logType: logType)
                
                // Fetch Entra Application Filters
                try await AppDataManager.shared.fetchEntraFilters()
                Logger.logApp("Entra Application Filters loaded successfully.", logType: logType)
                
                
            } catch {
                Logger.logApp("Error during initialization: \(error.localizedDescription)", logType: logType)
            }
        }
        
        cleanOldTempFolders()
        
        setupApplicationSupportFolders()
        
        checkForFirstRun()

    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        
        if let mainMenu = NSApp.mainMenu {
            DispatchQueue.main.async {
                if let formatMenu = mainMenu.items.first(where: { $0.title == "Format"}) {
                    mainMenu.removeItem(formatMenu);
                }
            }
        }
    }


    func applicationWillTerminate(_ aNotification: Notification) {

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
            Logger.logApp("Error: mainWindowController has no window.", logType: logType)
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
                            Logger.logApp("Removed old temp folder: \(url.path)", logType: logType)
                        } catch {
                            Logger.logApp("Failed to remove old temp folder: \(url.path), error: \(error)", logType: logType)
                        }
                    }
                }
            }
        } catch {
            Logger.logApp("Error reading contents of temp directory: \(error)", logType: logType)
        }
    }
    
    // MARK: - Setup Folders and Installomator Labels

    private func setupApplicationSupportFolders() {
        Logger.logApp("Checking for and creating application support folders...", logType: logType)
        let folders = [
            AppConstants.intuneomatorTempFolderURL.path
        ]

        // Create required folders if they don't exist
        for folder in folders {
            if !FileManager.default.fileExists(atPath: folder) {
                do {
                    try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
                    Logger.logApp("Created folder: \(folder)", logType: logType)
                } catch {
                    Logger.logApp("Failed to create folder: \(folder), error: \(error)", logType: logType)
                }
            }
        }
    }
}
