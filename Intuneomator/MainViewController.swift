//
//  MainViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/11/25.
//

import Cocoa

class MainViewController: NSViewController {
    
    static let logType = "MainViewController"
    
    var appData: [AppInfo] = []
    var filteredAppData: [AppInfo] = []
    
    var validationCache: [String: Bool] = [:] // Cache with folder paths as keys
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var headerView: NSTableHeaderView!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var appSearchField: NSSearchField!
    @IBOutlet weak var labelCountField: NSTextField!
    
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var editButton: NSButton!
    @IBOutlet weak var infoButton: NSButton!
    
    @IBOutlet weak var labelVersionInfo: NSTextField!
    
    @IBOutlet weak var progressSpinner: NSProgressIndicator!
    
    @IBOutlet weak var statusUpdateLabel: NSTextField!
    
    var searchBuffer: String = ""
    var searchTimer: Timer?

    var scriptManagerWindowControllers: [NSWindowController] = []
    var customAttributeManagerWindowControllers: [NSWindowController] = []
    var appCategoryManagerWindowControllers: [NSWindowController] = []
    var discoveredAppsManagerWindowControllers: [NSWindowController] = []

    
    // MARK: -  Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start the heartbeat
        XPCManager.shared.beginXPCServiceTransaction { success in
            if success ?? false {
                print("XPC service transaction started")
            } else {
                print("Failed to start XPC service transaction")
            }
        }
        
        // Store reference in AppDelegate
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.mainViewController = self
        }

        registerNotifications()
        
        setupTableViewRightClickMenu()

        refreshUI()
        
        labelVersionInfo.stringValue = formattedAppVersion()

        checkForIntuneAutomation()

    }
    
    
    
    func applicationWillTerminate(_ notification: Notification) {
        XPCManager.shared.endXPCServiceTransaction { _ in }
    }
    
    
    // MARK: - Validation Cache Management
    func invalidateValidationCache() {
        validationCache.removeAll()
    }
    
    func invalidateValidationCache(for folderPath: String) {
        validationCache.removeValue(forKey: folderPath)
    }
    
    // MARK: - Window Management
    @objc func appDiscoveredAppsManagerWindowClosed(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow {
            discoveredAppsManagerWindowControllers.removeAll { $0.window == closedWindow }
        }
    }

}


