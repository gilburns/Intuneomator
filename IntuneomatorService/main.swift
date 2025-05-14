//
//  main.swift
//  IntuneomatorService
//
//  Created by Gil Burns on 3/11/25.
//

import Foundation

// MARK: - Check Root
// Check if running as root
func verify_root() {
    let current_running_User = NSUserName()
    if current_running_User != "root" {
        print("Not running as root. Exiting...")
        exit(99)
    } else {
        return
    }
}

func startSpinner(message: String = "Processing") -> () -> Void {
    var isSpinning = true
    let spinnerQueue = DispatchQueue(label: "spinner.queue")

    spinnerQueue.async {
//        let spinnerChars = ["|/-\\", "/-\\|", "-\\|/", "\\|/-"]
        let spinnerChars = [
            "🁢-----------",
            "-🁢----------",
            "--🁢---------",
            "---🁢--------",
            "----🁢-------",
            "-----🁢------",
            "------🁢-----",
            "-------🁢----",
            "--------🁢---",
            "---------🁢--",
            "----------🁢-",
            "-----------🁢"
        ]
        var index = 0
        while isSpinning {
            print("\r\(message) \(spinnerChars[index % spinnerChars.count])", terminator: "")
            fflush(stdout)
            usleep(100_000)
            index += 1
        }
        print("\r\(message) Done!           ")
    }

    // Return a closure that stops the spinner
    return {
        print("\r\rDone!", terminator: ""); isSpinning = false
    }
}

// MARK: - Print Usage
func printUsage() {
    print("""
    Usage:
      <no arguments>          Start the XPC Service daemon
    
      scan-validate-folders   Scan all folder for automation ready labels
      process-label-script    Process .sh file generate plist for folder
      collect-plist-data      Collect data from plist for given label folder
      process-label           Fully process a given label folder
      intune-automation       Run standard automation
      label-update            Run installomator label update
    
      help                    Display this help message
    """)
}

// MARK: - Command Line Functions
// Functions that can be called via command line parameters
func scanAndValidateFolders() -> [String] {
    print("Scanning Intuneomator folders...")
    let validFolders = LabelAutomation.scanAndValidateFolders()
//    print("Valid Folders: \(validFolders)")
    return validFolders
}


func processLabelScript(withParam folderName: String) {
    let processFolder = LabelAutomation.runProcessLabelScript(for: folderName)
}

func collectPlistData(withParam folderName: String) {
    print("Collecting plist data...")
    let labelPlistData = LabelAutomation.extractDataForProcessedAppResults(from: folderName)
    print("labelPlistData: \(String(describing: labelPlistData))")
}

func processLabel(withParam folderName: String) {
    print("Processing Label...")
    print("\(folderName)")

    let stopSpinner = startSpinner(message: "Working ")

    let group = DispatchGroup()

    group.enter()
    Task {
        await LabelAutomation.processFolder(named: folderName)
        group.leave()
    }

    group.wait()
    stopSpinner()
}

func processLabelQuiet(withParam folderName: String) {
    let group = DispatchGroup()

    group.enter()
    Task {
        await LabelAutomation.processFolder(named: folderName)
        group.leave()
    }

    group.wait()
}

func runIntuneAutomation() {
    print("Running Intune Automation...")
    let validFolders = LabelAutomation.scanAndValidateFolders()
    
    print("Found -\(validFolders.count)- Intuneomator folders to process.")
    
    for (index, folder) in validFolders.enumerated() {
        print("Processing folder \(index+1)/\(validFolders.count): \(folder)")
        let folderName = folder.components(separatedBy: "_")[0]
        
        print("  Updating Installomator label data: \(folderName)")

        // Update label plist (process_label.sh)
        processLabelScript(withParam: folder)

        print("  Connecting to Intune.")
        // Run the automation for folder
        processLabelQuiet(withParam: folder)
        
    }
}


func intuneAutomation() {
    print("Full Automation Run...")

}


func labelUpdate(withParam param: String) {
    print("Running scheduled task 2 with parameter: \(param)")
    // Your scheduled task 2 code here
}


// MARK: - Command Line Argument Handling
func handleCommandLineArguments() {
    let arguments = CommandLine.arguments
    
    // MARK: - Start Main RunLoop
    // If no arguments provided or only the path argument (index 0)
    if arguments.count <= 1 {
        // Start normal XPC service
        let daemon = XPCListener()
        daemon.start()
        
        RunLoop.current.run()
        return
    }
    
    // Handle various command line options
    switch arguments[1] {
    // check which folders are ready for automation
    case "scan-validate-folders":
        let validFolders = scanAndValidateFolders()
        print(validFolders)
        
        
    // process .sh file for a given label folder
    case "process-label-script":
        if arguments.count > 2 {
            processLabelScript(withParam: arguments[2])
        } else {
            print("Error: task2 requires a parameter")
            exit(1)
        }

        
    // collect the plist data for a given label folder
    case "collect-plist-data":
        if arguments.count > 2 {
            collectPlistData(withParam: arguments[2])
        } else {
            print("Error: task2 requires a parameter")
            exit(1)
        }

        
    // full run on a given label folder
    case "process-label":
        if arguments.count > 2 {
            processLabel(withParam: arguments[2])
        } else {
            print("Error: task2 requires a parameter")
            exit(1)
        }

    case "cache-cleanup":
        CacheManagerUtil.runCleanup()
        
    case "schedule-task":
        ScheduledTaskManager.configureScheduledTask(
            label: "com.gilburns.intuneomator.cachecleaner",
            argument: "cache-cleanup",
            schedules: [
                (weekday: 2, hour: 6, minute: 0), // Monday at 6:00 AM
                (weekday: 5, hour: 6, minute: 0)  // Thursday at 6:00 AM
            ],
            completion: { success, message in
                if success {
                    print("✅ Cache cleaner scheduled successfully.")
                } else {
                    print("❌ Failed to schedule: \(message ?? "Unknown error")")
                }
            }
        )
    case "intune-automation":
        runIntuneAutomation()
        
    case "label-update":
        Task {
            let (isUpToDate, versionMessage) = await InstallomatorLabels.compareInstallomatorVersionAsync()
            Logger.log("🔍 Version Check: \(versionMessage)", logType: "LabelUpdate")

            if isUpToDate {
                Logger.log("✅ No update needed.", logType: "LabelUpdate")
                exit(EXIT_SUCCESS)
            }

            Logger.log("⬇️ Updating Installomator labels...", logType: "LabelUpdate")

            let (success, updateMessage) = await InstallomatorLabels.installInstallomatorLabelsAsync()
            if success {
                Logger.log("✅ \(updateMessage)", logType: "LabelUpdate")
                exit(EXIT_SUCCESS)
            } else {
                Logger.log("❌ \(updateMessage)", logType: "LabelUpdate")
                exit(EXIT_FAILURE)
            }
        }

        RunLoop.main.run()

    case "help":
        printUsage()
    default:
        print("Unknown command: \(arguments[1])")
        printUsage()
        exit(1)
    }
}

// Verify Running as Root
verify_root()

// Handle command line arguments
handleCommandLineArguments()
