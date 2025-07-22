//
//  MainViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/11/25.
//

import Cocoa

/**
 * MainViewController
 *
 * The primary view controller for the Intuneomator application. This controller manages the main
 * table view that displays managed application labels and provides the core user interface for
 * interacting with Installomator-based app automation.
 *
 * ## Responsibilities:
 * - Manages the main table view displaying app data
 * - Handles XPC service lifecycle and transactions
 * - Maintains validation cache for automation readiness
 * - Provides core UI lifecycle management
 *
 * ## Architecture:
 * This class is split across multiple extension files for better organization:
 * - MainViewController+Actions: UI action handlers and sheet presentation
 * - MainViewController+DataHandling: Data loading and processing
 * - MainViewController+TableView: Table view data source and delegate
 * - MainViewController+ContextMenu: Right-click context menu functionality
 * - MainViewController+Notifications: Notification handling and registration
 * - MainViewController+Helpers: Utility methods and UI helpers
 *
 * ## Data Flow:
 * 1. Loads app data from managed titles directory
 * 2. Validates automation readiness for each app
 * 3. Displays results in filterable table view
 * 4. Provides actions for editing, deleting, and managing apps
 */
class MainViewController: NSViewController {
    
    /// Logging identifier for this class
    
    // MARK: - Data Properties
    
    /// Complete array of all app data loaded from the managed titles directory
    var appData: [AppInfo] = []
    
    /// Filtered subset of appData based on current search criteria
    var filteredAppData: [AppInfo] = []
    
    /// Cache storing validation results to avoid repeated file system checks
    /// Key: folder path, Value: validation result (true = ready for automation)
    var validationCache: [String: Bool] = [:]
    
    // MARK: - UI Outlets
    
    /// Main table view displaying the app data
    @IBOutlet weak var tableView: NSTableView!
    
    /// Table header view for column headers
    @IBOutlet weak var headerView: NSTableHeaderView!
    
    /// Status label showing current operation status
    @IBOutlet weak var statusLabel: NSTextField!
    
    /// Search field for filtering the app list
    @IBOutlet weak var appSearchField: NSSearchField!
    
    /// Label displaying count of visible vs total apps
    @IBOutlet weak var labelCountField: NSTextField!
    
    /// Button for removing selected app from automation
    @IBOutlet weak var removeButton: NSButton!
    
    /// Button for editing selected app's automation settings
    @IBOutlet weak var editButton: NSButton!
    
    /// Info button for additional app details
    @IBOutlet weak var infoButton: NSButton!
    
    /// Button for triggering full automation (optional - connect in Interface Builder if using a button)
    @IBOutlet weak var automationTriggerButton: NSButton?
    
    /// Button for opening discovered apps manager (optional - connect in Interface Builder if using a button)
    @IBOutlet weak var discoveredAppsButton: NSButton?
    
    /// Label displaying current app version information
    @IBOutlet weak var labelVersionInfo: NSTextField!
    
    /// Progress indicator shown during data loading operations
    @IBOutlet weak var progressSpinner: NSProgressIndicator!
    
    /// Animated status update label for user feedback
    @IBOutlet weak var statusUpdateLabel: NSTextField!
    
    /// Daemon feedback to the GUI on current status
    @IBOutlet weak var progressView: NSProgressIndicator!
    @IBOutlet weak var progressLabel: NSTextField!
    @IBOutlet weak var progressDetailLabel: NSTextField!

    // MARK: - Search Properties
    
    /// Buffer for accumulating keystrokes for quick table navigation
    var searchBuffer: String = ""
    
    /// Timer for clearing the search buffer after inactivity
    var searchTimer: Timer?

    // MARK: - Window Management
    
    /// Array tracking app category manager window controllers
    var appCategoryManagerWindowControllers: [NSWindowController] = []

    /// Array tracking apps reporting manager window controllers to prevent duplication
    var appsReportingManagerWindowControllers: [NSWindowController] = []

    /// Array tracking config reporting manager window controllers to prevent duplication
    var configReportingManagerWindowControllers: [NSWindowController] = []

    /// Array tracking devices window controllers to prevent duplication
    var devicesManagerWindowControllers: [NSWindowController] = []

    /// Array tracking config report export window controllers to prevent duplication
    var reportExportManagerWindowControllers: [NSWindowController] = []
    
    /// Array tracking custom attribute manager window controllers
    var customAttributeManagerWindowControllers: [NSWindowController] = []
        
    /// Array tracking discovered apps manager window controllers
    var discoveredAppsManagerWindowControllers: [NSWindowController] = []

    /// Array tracking script manager window controllers to prevent duplication
    var shellScriptManagerWindowControllers: [NSWindowController] = []

    /// Array tracking web clips manager window controllers to prevent duplication
    var webClipsManagerWindowControllers: [NSWindowController] = []

    
    // MARK: - Lifecycle
    
    /**
     * Called after the view controller's view is loaded into memory.
     * 
     * Initializes the main view controller by:
     * 1. Starting XPC service transaction for background operations
     * 2. Registering with AppDelegate for global access
     * 3. Setting up notification observers
     * 4. Configuring table view interactions
     * 5. Initializing UI state
     * 6. Starting automation check
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start XPC service transaction for background operations
        XPCManager.shared.beginXPCServiceTransaction { success in
            if success ?? false {
                print("XPC service transaction started")
            } else {
                print("Failed to start XPC service transaction")
            }
        }
        
        // Store reference in AppDelegate for global access
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.mainViewController = self
        }

        // Set up notification observers
        registerNotifications()
        
        // Configure table view right-click menu
        setupTableViewRightClickMenu()

        // Initialize UI state
        refreshUI()
        
        // Display current app version
        labelVersionInfo.stringValue = formattedAppVersion()
        
        // Setup status monitoring for real-time progress updates
        setupStatusMonitoring()
        
        // Initially hide progress UI elements
        progressView.isHidden = true
        progressLabel.isHidden = true
        progressDetailLabel.isHidden = true

        // Start background automation check
        checkForIntuneAutomation()
    }
    
    /**
     * Called when the view is about to disappear.
     * 
     * Cleans up status monitoring to prevent resource leaks.
     */
    override func viewWillDisappear() {
        super.viewWillDisappear()
        teardownStatusMonitoring()
    }
    
    /**
     * Called when the application is about to terminate.
     * 
     * Performs cleanup by ending the XPC service transaction to ensure
     * proper resource cleanup and background service shutdown.
     * 
     * - Parameter notification: The termination notification
     */
    func applicationWillTerminate(_ notification: Notification) {
        XPCManager.shared.endXPCServiceTransaction { _ in }
    }
    
    
    // MARK: - Validation Cache Management
    
    /**
     * Clears the entire validation cache.
     * 
     * This forces all automation readiness checks to be re-evaluated on the next
     * table view update. Typically called when global changes might affect multiple
     * app validations.
     */
    func invalidateValidationCache() {
        validationCache.removeAll()
    }
    
    /**
     * Invalidates the validation cache for a specific folder path.
     * 
     * Forces re-evaluation of automation readiness for a single app. This is more
     * efficient than clearing the entire cache when only one app has changed.
     * 
     * - Parameter folderPath: The full path to the app's managed folder
     */
    func invalidateValidationCache(for folderPath: String) {
        validationCache.removeValue(forKey: folderPath)
    }
    
    // MARK: - Window Management
    
    /**
     * Handles cleanup when a app categories manager window is closed.
     *
     * Removes the closed window controller from the tracking array to prevent
     * memory leaks and ensure proper window management.
     *
     * - Parameter notification: Window close notification containing the closed window
     */
    @objc func appCategoriesManagerWindowClosed(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow {
            appCategoryManagerWindowControllers.removeAll { $0.window == closedWindow }
        }
    }

    /**
     * Handles cleanup when a discovered apps manager window is closed.
     *
     * Removes the closed window controller from the tracking array to prevent
     * memory leaks and ensure proper window management.
     *
     * - Parameter notification: Window close notification containing the closed window
     */
    @objc func appDiscoveredAppsManagerWindowClosed(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow {
            discoveredAppsManagerWindowControllers.removeAll { $0.window == closedWindow }
        }
    }

    /**
     * Handles cleanup when a custom attribute manager window is closed.
     *
     * Removes the closed window controller from the tracking array to prevent
     * memory leaks and ensure proper window management.
     *
     * - Parameter notification: Window close notification containing the closed window
     */
    @objc func customAttributeManagerWindowClosed(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow {
            customAttributeManagerWindowControllers.removeAll { $0.window == closedWindow }
        }
    }

    /**
     * Handles cleanup when a shell script manager window is closed.
     *
     * Removes the closed window controller from the tracking array to prevent
     * memory leaks and ensure proper window management.
     *
     * - Parameter notification: Window close notification containing the closed window
     */
    @objc func shellScriptsManagerWindowClosed(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow {
            shellScriptManagerWindowControllers.removeAll { $0.window == closedWindow }
        }
    }


}


