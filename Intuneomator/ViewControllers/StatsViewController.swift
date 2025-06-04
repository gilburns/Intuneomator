//
//  StatsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation
import Cocoa

/// Statistics view controller for displaying application storage and transfer metrics
/// Provides detailed information about cache usage, log storage, and data transfer volumes
/// Includes functionality to open log files and folders for detailed inspection
class StatsViewController: NSViewController {
    
    // MARK: - Interface Builder Outlets
    
    /// Label displaying the total size of the application cache folder
    @IBOutlet weak var labelCacheSize: NSTextField!
    
    /// Label displaying the total size of system log files
    @IBOutlet weak var labelLogSize: NSTextField!
    
    /// Label displaying the total size of user log files
    @IBOutlet weak var labelLogUserSize: NSTextField!

    /// Label displaying the total size of downloaded content
    @IBOutlet weak var labelDownloadSize: NSTextField!
    
    /// Label displaying the total size of uploaded content
    @IBOutlet weak var labelUploadSize: NSTextField!
    
    
    // MARK: - View Lifecycle Methods
    
    /// Called after the view controller's view is loaded into memory
    /// Initializes all statistics displays by loading size information and transfer data
    override func viewDidLoad() {
        super.viewDidLoad()
        
        getCacheSize()
        getLogSize()
        getLogFolderSize()

        let formattedDownloadSize = formattedTotalTransferSize(forLogFile: "Intuneomator_Download" )
        labelDownloadSize.stringValue = formattedDownloadSize

        let formattedUploadSize = formattedTotalTransferSize(forLogFile: "Intuneomator_Upload" )
        labelUploadSize.stringValue = formattedUploadSize
    }
    
    /// Called when the view controller's view is about to appear
    /// Restores saved window size and sets size constraints for the statistics sheet
    override func viewWillAppear() {
        super.viewWillAppear()

        // Load the saved size or use the default size
        let defaultSize = NSSize(width: 450, height: 412)
        let savedSize = loadSavedSheetSize() ?? defaultSize

        if let sheetWindow = view.window {
            sheetWindow.setContentSize(savedSize)
            sheetWindow.minSize = NSSize(width: 450, height: 412)
            sheetWindow.maxSize = NSSize(width: 500, height: 1024)
        }
    }

    /// Loads the previously saved sheet size from UserDefaults
    /// Returns nil if no saved size exists, triggering default size usage
    /// - Returns: Optional NSSize with saved dimensions, or nil if not found
    private func loadSavedSheetSize() -> NSSize? {
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "StatsViewSheetSize") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
            return NSSize(width: width, height: height)
        }
        return nil
    }

    
    // MARK: - User Action Methods
    
    /// Opens the download log file in the system's default text editor
    /// Provides direct access to detailed download activity records
    /// - Parameter sender: The button or control that triggered the action
    @IBAction func openDownloadLogFile(_ sender: Any?) {
        let logFileURL = AppConstants.intuneomatorLogSystemURL
            .appendingPathComponent("Intuneomator_Download.txt")
        NSWorkspace.shared.open(logFileURL)
    }
    
    /// Opens the upload log file in the system's default text editor
    /// Provides direct access to detailed upload activity records
    /// - Parameter sender: The button or control that triggered the action
    @IBAction func openUploadLogFile(_ sender: Any?) {
        let logFileURL = AppConstants.intuneomatorLogSystemURL
            .appendingPathComponent("Intuneomator_Upload.txt")
        NSWorkspace.shared.open(logFileURL)
    }
    
    /// Opens the system logs folder in Finder
    /// Allows browsing of all system-level log files and directories
    /// - Parameter sender: The button or control that triggered the action
    @IBAction func openLogsFolder(_ sender: Any) {
        print("Opening system logs folder...")
        NSWorkspace.shared.open(AppConstants.intuneomatorLogSystemURL)
    }

    /// Opens the user logs folder in Finder
    /// Allows browsing of user-level log files and application logs
    /// - Parameter sender: The button or control that triggered the action
    @IBAction func openLogsUserFolder(_ sender: Any) {
        print("Opening user logs folder...")
        NSWorkspace.shared.open(AppConstants.intuneomatorLogApplicationURL)
    }

    /// Opens the application cache folder in Finder
    /// Allows inspection of cached application files and temporary data
    /// - Parameter sender: The button or control that triggered the action
    @IBAction func openCacheFolder(_ sender: Any) {
        print("Opening cache folder...")
        NSWorkspace.shared.open(AppConstants.intuneomatorCacheFolderURL)
    }


    // MARK: - Statistics Collection Methods
    
    /// Retrieves and displays the size of the user log folder
    /// Uses LogManagerUtil to calculate total size of user-level log files
    func getLogFolderSize() {
        let size = LogManagerUtil.logFolderSizeInBytes(forLogFolder: "user")
        labelLogUserSize.stringValue = formatBytesToReadableSize(size)
    }

    /// Retrieves and displays the size of the application cache folder via XPC
    /// Updates the cache size label asynchronously on the main queue
    func getCacheSize() {
        XPCManager.shared.getCacheFolderSize { size in
            DispatchQueue.main.async {
                if let size = size {
                    self.labelCacheSize.stringValue = self.formatBytesToReadableSize(size)
                } else {
                    self.labelCacheSize.stringValue = "Unavailable"
                }
            }
        }
    }

    /// Retrieves and displays the size of system log files via XPC
    /// Updates the system log size label asynchronously on the main queue
    func getLogSize() {
        XPCManager.shared.getLogFolderSize { size in
            DispatchQueue.main.async {
                if let size = size {
                    self.labelLogSize.stringValue = self.formatBytesToReadableSize(size)
                } else {
                    self.labelLogSize.stringValue = "Unavailable"
                }
            }
        }
    }

    
    
    // MARK: - Formatting Helper Methods
    
    /// Converts byte count to human-readable size format (MB or GB)
    /// Automatically selects appropriate unit based on size magnitude
    /// - Parameter bytes: Size in bytes as Int64
    /// - Returns: Formatted string with MB or GB suffix
    func formatBytesToReadableSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1000 {
            let gb = mb / 1024
            return String(format: "%.2f GB", gb)
        } else {
            return String(format: "%.2f MB", mb)
        }
    }
    
    /// Calculates total transfer size from log file by parsing tab-delimited entries
    /// Reads download or upload log files and sums size values from appropriate columns
    /// - Parameter logName: Name of the log file to analyze ("Intuneomator_Download" or "Intuneomator_Upload")
    /// - Returns: Total transfer size in megabytes as Double
    func totalTransferSizeMB(forLogfile logName: String) -> Double {
        let logFileURL = AppConstants.intuneomatorLogSystemURL.appendingPathComponent("\(logName).txt")
                
        let sizePosition: Int
        
        // Determine which column contains size data based on log type
        switch logName {
        case "Intuneomator_Download":
            sizePosition = 4
        case "Intuneomator_Upload":
            sizePosition = 5
        default:
            return 0.0
        }
        
        guard FileManager.default.fileExists(atPath: logFileURL.path) else {
            print("Log file not found.")
            return 0.0
        }
        
        do {
            let contents = try String(contentsOf: logFileURL, encoding: .utf8)
            let lines = contents.split(separator: "\n")
            
            var total: Double = 0.0
            
            // Parse each line and extract size values from the appropriate column
            for line in lines {
                let columns = line.components(separatedBy: "\t")
                if columns.count >= sizePosition {
                    let sizeString = columns[sizePosition - 1].replacingOccurrences(of: " MB", with: "")
                    if let size = Double(sizeString) {
                        total += size
                    }
                }
            }
            
            return total
        } catch {
            print("Error reading log file: \(error.localizedDescription)")
            return 0.0
        }
    }
    
    /// Formats total transfer size with appropriate unit (MB or GB)
    /// Converts raw megabyte values to human-readable format with proper scaling
    /// - Parameter logName: Name of the log file to analyze for transfer totals
    /// - Returns: Formatted string with transfer total and appropriate unit
    func formattedTotalTransferSize(forLogFile logName: String) -> String {
        let totalMB = totalTransferSizeMB(forLogfile: logName)
        
        if totalMB >= 1000 {
            let totalGB = totalMB / 1024
            let formattedGB = String(format: "%.2f GB", totalGB)
            return formattedGB
        } else {
            let formattedMB = String(format: "%.2f MB", totalMB)
            return formattedMB
        }
    }
    
}
