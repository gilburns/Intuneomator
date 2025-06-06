//
//  MainWindowController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/4/25.
//

import Cocoa

class MainWindowController: NSWindowController, NSWindowDelegate {

    private let windowFrameKey = "MainWindowFrame"

    override func windowDidLoad() {
        super.windowDidLoad()

        // Restore window position
        if let frameDescription = UserDefaults.standard.string(forKey: windowFrameKey) {
            DispatchQueue.main.async {
                self.window?.setFrame(from: frameDescription)
            }
        } else {
            self.window?.center()
        }
        
        // Set the delegate
        DispatchQueue.main.async { [weak self] in
            self?.window?.delegate = self
        }

        self.showWindow(self)
        
        NotificationCenter.default.post(name: .mainWindowDidLoad, object: nil)

        // Prevent duplicates
        guard !window!.titlebarAccessoryViewControllers.contains(where: { $0 is TitlebarAccessoryViewController }) else {
            return
        }

        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let accessory = storyboard.instantiateController(withIdentifier: "TitlebarAccessory") as? TitlebarAccessoryViewController else {
            return
        }

        accessory.layoutAttribute = .right
        self.window?.addTitlebarAccessoryViewController(accessory)

        // Optional: Start heartbeat if needed
        accessory.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidLaunch")))
        
        
        if let window = self.window {
            window.title = "Intuneomator \(formattedAppVersion())"
        }

    }

    func windowWillClose(_ notification: Notification) {
        if let frameDescriptor = self.window?.frameDescriptor {
            UserDefaults.standard.set(frameDescriptor, forKey: windowFrameKey)
        }
        
        do {
            try FileManager.default.removeItem(atPath: AppConstants.intuneomatorTempFolderURL.path)
//            Logger.logApp("Deleted directory: \(AppConstants.intuneomatorTempFolderURL.path)")
        } catch {
            Logger.logApp("Failed to delete directory: \(error)")
        }

    }

    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Save window position before closing
        if let frameDescriptor = self.window?.frameDescriptor {
            UserDefaults.standard.set(frameDescriptor, forKey: windowFrameKey)
        }

        NSApplication.shared.terminate(self)
        return true
    }
    
    
    /// Reads CFBundleShortVersionString and CFBundleVersion from Info.plist
    private func formattedAppVersion() -> String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber  = info?["CFBundleVersion"]            as? String ?? "?"
        return "v\(shortVersion) (build \(buildNumber))"
    }

    

}

