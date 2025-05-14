//
//  StatsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation
import Cocoa


class StatsViewController: NSViewController {
    
    
    @IBOutlet weak var labelCacheSize: NSTextField!
    
    @IBOutlet weak var labelLogSize: NSTextField!
    @IBOutlet weak var labelLogUserSize: NSTextField!

    @IBOutlet weak var labelDownloadSize: NSTextField!
    @IBOutlet weak var labelUploadSize: NSTextField!
    
    
    
    // MARK: - Lifecycle
    
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
    
    
    override func viewWillAppear() {
        super.viewWillAppear()

        // Load the saved size or use the default size
        let defaultSize = NSSize(width: 450, height: 412)
        let savedSize = loadSavedSheetSize() ?? defaultSize

        if let sheetWindow = view.window {
            sheetWindow.setContentSize(savedSize) // Apply the saved or default size
            sheetWindow.minSize = NSSize(width: 450, height: 412) // Set minimum size
            sheetWindow.maxSize = NSSize(width: 500, height: 1024)
        }
    }

    // Load the size from UserDefaults
    private func loadSavedSheetSize() -> NSSize? {
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "StatsViewSheetSize") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
            return NSSize(width: width, height: height)
        }
        return nil
    }

    
    // MARK: - Actions
    
    @IBAction func openDownloadLogFile(_ sender: Any?) {
        let logFileURL = AppConstants.intuneomatorLogSystemURL
            .appendingPathComponent("Intuneomator_Download.txt")
        NSWorkspace.shared.open(logFileURL)
//        NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
        
    }
    
    @IBAction func openUploadLogFile(_ sender: Any?) {
        let logFileURL = AppConstants.intuneomatorLogSystemURL
            .appendingPathComponent("Intuneomator_Upload.txt")
        NSWorkspace.shared.open(logFileURL)
//        NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
    }
    
    @IBAction func openLogsFolder(_ sender: Any) {
        print("Opening cache folder...")
        NSWorkspace.shared.open(AppConstants.intuneomatorLogSystemURL)
    }

    @IBAction func openLogsUserFolder(_ sender: Any) {
        print("Opening cache folder...")
        NSWorkspace.shared.open(AppConstants.intuneomatorLogApplicationURL)
    }

    @IBAction func openCacheFolder(_ sender: Any) {
        print("Opening cache folder...")
        NSWorkspace.shared.open(AppConstants.intuneomatorCacheFolderURL)
    }


    // MARK: - Set GUI Elements
    
    
    func getLogFolderSize() {
        let size = LogManagerUtil.logFolderSizeInBytes(forLogFolder: "user")
        labelLogUserSize.stringValue = formatBytesToReadableSize(size)
    }

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

    
    
    
    // MARK: - Helper Functions
    func formatBytesToReadableSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1000 {
            let gb = mb / 1024
            return String(format: "%.2f GB", gb)
        } else {
            return String(format: "%.2f MB", mb)
        }
    }
    
    func totalTransferSizeMB(forLogfile logName: String) -> Double {
        let logFileURL = AppConstants.intuneomatorLogSystemURL.appendingPathComponent("\(logName).txt")
                
        let sizePosition: Int
        
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

    /*
     let totalSize = totalDownloadSizeMB()
     print("Total downloaded size: \(totalSize) MB")
     */
    
    
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

    /*
     let formattedSize = formattedTotalDownloadSize()
     print("Total Downloaded: \(formattedSize)")
     */
    
}
