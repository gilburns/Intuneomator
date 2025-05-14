//
//  TitlebarAccessoryViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/26/25.
//

import Cocoa

class TitlebarAccessoryViewController: NSTitlebarAccessoryViewController {
        
    @IBOutlet weak var daemonRunningStatusButton: NSButton!

    var heartbeatTimer: Timer?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Additional setup if needed
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Update the button title when the view appears
        daemonStatusCheck()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // Start the heartbeat
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self!.daemonStatusCheck()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        
        // Stop the heartbeat when the app is closing
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    // MARK: - Actions
    @IBAction func checkDaemonStatus(_ sender: NSButton) {
        daemonStatusCheck()
    }
    
    func daemonStatusCheck() {
        let isRunning = checkXPCServiceRunning()
        DispatchQueue.main.async {
            self.daemonRunningStatusButton.title = isRunning ? "Daemon ✅" : "Daemon ❌"
        }
    }
    
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

