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
        
        // Start XPC service transaction with robust retry and timeout handling
        startupWithRobustTransactionHandling()
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

    // MARK: - Robust Startup Handling

    /**
     * Handles startup with robust XPC transaction management and timeout handling.
     *
     * This method implements a resilient startup sequence that prevents GUI hangs
     * by using timeout detection, retry logic, and graceful degradation when the
     * daemon is busy or unresponsive.
     *
     * ## Startup Flow:
     * 1. Check daemon health first
     * 2. Start XPC transaction with retry logic
     * 3. Initialize UI components
     * 4. Load data asynchronously
     * 5. Handle failures gracefully
     */
    private func startupWithRobustTransactionHandling() {
        Logger.info("Starting robust startup sequence...", category: .core, toUserDirectory: true)

        // First, check if daemon is responsive
        XPCManager.shared.checkDaemonHealth { [weak self] isHealthy in
            guard let self = self else { return }

            if isHealthy {
                Logger.info("Daemon health check passed, starting transaction...", category: .core, toUserDirectory: true)
                self.startXPCTransactionWithRetry()
            } else {
                Logger.warning("Daemon appears unresponsive, proceeding with degraded startup", category: .core, toUserDirectory: true)
                self.startupInDegradedMode()
            }
        }
    }

    /**
     * Starts XPC transaction with retry logic and proper timeout handling.
     */
    private func startXPCTransactionWithRetry() {
        XPCManager.shared.beginXPCServiceTransactionWithRetry(
            identifier: "mainOperation",
            maxRetries: 3,
            timeoutSeconds: 30
        ) { [weak self] success in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if success {
                    Logger.info("XPC service transaction started successfully", category: .core, toUserDirectory: true)
                    self.completeNormalStartup()
                } else {
                    Logger.error("Failed to start XPC transaction after retries, falling back to degraded mode", category: .core, toUserDirectory: true)
                    self.startupInDegradedMode()
                }
            }
        }
    }

    /**
     * Completes normal startup sequence after successful XPC transaction.
     */
    private func completeNormalStartup() {
        Logger.info("Completing normal startup sequence", category: .core, toUserDirectory: true)

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

        // Start background automation check (non-blocking)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.checkForIntuneAutomation()
        }

        // Load app data from managed titles directory
        progressSpinner.startAnimation(self)
        statusLabel.stringValue = "Loading app data..."
        statusLabel.isHidden = false
        loadAppData()

        Logger.info("Normal startup sequence completed", category: .core, toUserDirectory: true)
    }

    /**
     * Starts up in degraded mode when daemon is unresponsive.
     *
     * This mode provides basic UI functionality while the daemon is busy
     * or unresponsive, preventing complete application hangs.
     */
    private func startupInDegradedMode() {
        Logger.info("Starting in degraded mode due to daemon issues", category: .core, toUserDirectory: true)

        // Store reference in AppDelegate for global access
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.mainViewController = self
        }

        // Set up notification observers (these don't require XPC)
        registerNotifications()

        // Configure table view right-click menu
        setupTableViewRightClickMenu()

        // Initialize UI state
        refreshUI()

        // Display current app version
        labelVersionInfo.stringValue = formattedAppVersion()

        // Show status indicating degraded mode
        statusLabel.stringValue = "Starting in degraded mode - daemon is busy or unresponsive"
        statusLabel.isHidden = false

        // Don't setup status monitoring in degraded mode
        progressView.isHidden = true
        progressLabel.isHidden = true
        progressDetailLabel.isHidden = true

        // Try to load app data even in degraded mode (local file system operations)
        // This gives users some functionality while daemon is busy
        progressSpinner.startAnimation(self)
        loadAppData()

        // Schedule retry of full startup after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.retryNormalStartup()
        }

        Logger.info("Degraded mode startup completed", category: .core, toUserDirectory: true)
    }

    /**
     * Attempts to retry normal startup after degraded mode.
     */
    private func retryNormalStartup() {
        Logger.info("Attempting to retry normal startup from degraded mode", category: .core, toUserDirectory: true)

        XPCManager.shared.checkDaemonHealth { [weak self] isHealthy in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if isHealthy {
                    Logger.info("Daemon now responsive, upgrading to normal mode", category: .core, toUserDirectory: true)
                    self.upgradeToNormalMode()
                } else {
                    Logger.info("Daemon still unresponsive, staying in degraded mode", category: .core, toUserDirectory: true)
                    // Schedule another retry
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
                        self?.retryNormalStartup()
                    }
                }
            }
        }
    }

    /**
     * Upgrades from degraded mode to normal mode when daemon becomes available.
     */
    private func upgradeToNormalMode() {
        startXPCTransactionWithRetry()

        // Setup status monitoring now that daemon is available
        setupStatusMonitoring()

        // Start background automation check
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.checkForIntuneAutomation()
        }

        statusLabel.stringValue = "Upgraded to normal mode - daemon is now responsive"

        // Clear the status message after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.statusLabel.isHidden = true
        }

        Logger.info("Successfully upgraded to normal mode", category: .core, toUserDirectory: true)
    }

}


