//
//  WindowManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/28/25.
//

import Cocoa

class WindowManager {
    static let shared = WindowManager()

    private var windows: [String: NSWindowController] = [:]

    /// Opens or focuses a window for the given identifier
    func openWindow(
        identifier: String,
        storyboardName: String,
        controllerType: NSViewController.Type,
        windowTitle: String,
        defaultSize: NSSize,
        restoreKey: String? = nil,
        customization: ((NSViewController) -> Void)? = nil
    ) {
        
        // If already open and visible, bring it to front
        if let existingWC = windows[identifier], let window = existingWC.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Load from storyboard
        let storyboard = NSStoryboard(name: storyboardName, bundle: nil)
        guard let viewController = storyboard.instantiateController(withIdentifier: identifier) as? NSViewController else {
            Logger.error("❌ Failed to instantiate \(identifier) from \(storyboardName)", category: .core)
            return
        }

        // Allow caller to modify VC before embedding
        customization?(viewController)
    
        // Size handling
        let frame: NSRect
        if let key = restoreKey,
           let savedFrame = restoredWindowFrame(forElement: key) {
            frame = savedFrame
        } else {
            frame = NSRect(origin: .zero, size: defaultSize)
        }

        // Setup window
        let window = NSWindow(contentRect: frame,
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = windowTitle
        window.minSize = defaultSize
        window.contentViewController = viewController
        window.center()

        let windowController = NSWindowController(window: window)
        windows[identifier] = windowController
        windowController.showWindow(nil)

        // Listen for close to remove reference
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.windows.removeValue(forKey: identifier)
        }
    }

    /// Restore a saved window frame if available
    private func restoredWindowFrame(forElement key: String) -> NSRect? {
        let defaults = UserDefaults.standard
        guard let dict = defaults.dictionary(forKey: key),
              let x = dict["x"] as? CGFloat,
              let y = dict["y"] as? CGFloat,
              let w = dict["width"] as? CGFloat,
              let h = dict["height"] as? CGFloat else { return nil }
        return NSRect(x: x, y: y, width: w, height: h)
    }

}
