//
//  TitlebarAccessoryViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/26/25.
//

import Cocoa

/// Titlebar accessory view controller for displaying XPC service status in the main window
/// Provides real-time daemon status monitoring with visual indicators in the window titlebar
/// Implements periodic status checking with timer-based heartbeat for continuous monitoring
class TitlebarAccessoryViewController: NSTitlebarAccessoryViewController {
    
    // MARK: - Interface Builder Outlets
    
    /// Button displaying current XPC daemon service status with visual indicators
    /// Shows "Daemon 🟢" when service is running, "Daemon 🔴" when not available
    @IBOutlet weak var daemonRunningStatusButton: NSButton!

    /// Timer for periodic XPC service status checking (60-second intervals)
    var heartbeatTimer: Timer?

    // MARK: - View Lifecycle Methods
    
    /// Called after the view controller's view is loaded into memory
    /// Performs initial setup for the titlebar accessory view
    override func viewDidLoad() {
        super.viewDidLoad()
        // Additional setup if needed
    }
    
    /// Called when the view controller's view is about to appear
    /// Triggers immediate daemon status check to update display
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Update the button title when the view appears
        daemonStatusCheck()
    }
    
    // MARK: - Application Lifecycle Methods
    
    /// Called when the application finishes launching
    /// Starts the periodic heartbeat timer for continuous daemon status monitoring
    /// - Parameter notification: Application launch notification (unused)
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start the heartbeat timer for 60-second status checks
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.daemonStatusCheck()
        }
    }
    
    /// Called when the application is about to terminate
    /// Cleans up the heartbeat timer to prevent memory leaks
    /// - Parameter notification: Application termination notification (unused)
    func applicationWillTerminate(_ notification: Notification) {
        // Stop the heartbeat when the app is closing
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    // MARK: - User Action Methods
    
    /// Handles manual daemon status check button click
    /// Triggers immediate status update when user clicks the daemon status button
    /// - Parameter sender: The daemon status button that triggered the action
    @IBAction func checkDaemonStatus(_ sender: NSButton) {
        daemonStatusCheck()
    }
    
    // MARK: - Status Monitoring Methods
    
    /// Performs XPC daemon status check and updates button display
    /// Called by timer heartbeat and manual refresh to maintain current status
    func daemonStatusCheck() {
        let isRunning = checkXPCServiceRunning()
        DispatchQueue.main.async {
            self.daemonRunningStatusButton.title = isRunning ? "Daemon 🟢" : "Daemon 🔴"
        }
    }
    
    /// Synchronously checks if the XPC service is running and responsive
    /// Uses semaphore to block until service responds or timeout occurs (2 seconds)
    /// - Returns: Boolean indicating XPC service availability and responsiveness
    func checkXPCServiceRunning() -> Bool {
        var isRunning = false
        let semaphore = DispatchSemaphore(value: 0)
        
        XPCManager.shared.checkXPCServiceRunning { success in
            isRunning = success ?? false
            semaphore.signal()
        }
        
        // Wait with timeout for a response
        _ = semaphore.wait(timeout: .now() + 2.0)
        
        return isRunning
    }

}

