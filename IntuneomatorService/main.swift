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
    
      cache-cleanup           Run this to clean the cache
      label-update            Run installomator label update
      intune-automation       Triggered by daemon for full automation on all ready labels
      intune-upload           Run the full automation on all ready labels
      ondemand                Triggered by the daemon for processing individual items
      process-label           Fully process a given label folder
      scan-validate-folders   Scan all folder to check with are automation ready
      process-label-script    Process .sh file generate plist for folder
      login                   Validate Microsoft Entra ID credentials

      help                    Display this help message
    """)
}

// MARK: - Command Line Functions
// Functions that can be called via command line parameters
func scanAndValidateFolders() -> [String] {
    let validFolders = LabelAutomation.scanAndValidateFolders()
    return validFolders
}


func processLabelScript(withParam folderName: String) {
    _ = LabelAutomation.runProcessLabelScript(for: folderName)
}

func collectPlistData(withParam folderName: String) {
    _ = LabelAutomation.extractDataForProcessedAppResults(from: folderName)
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

func labelUpdates() {
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
}

// full automation for live runs
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
        processLabel(withParam: folder)
        
    }
}

// full automation daemon
func runIntuneAutomationQuiet() {
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

// individual ondemaindQueue processing for daemon
func onDemandProcessLabels() {
    let group = DispatchGroup()
    
    group.enter()
    Task {
        await OnDemandTaskRunner.start()
        group.leave()
    }

    group.wait()
}


// Check for updates and update self
func checkForUpdates() {
    let group = DispatchGroup()
    
    group.enter()
    Task {
        DaemonUpdateManager.checkAndPerformUpdateIfNeeded()
    }

    group.wait()

}


// MARK: - Login Command
func login() {
//    print("Validating credentials...")
//    let stopSpinner = startSpinner(message: "Validating credentials")
//    var isValid = false
//    let group = DispatchGroup()
//    group.enter()
//    Task {
//        isValid = await EntraAuthenticator().ValidateCredentials()
//        stopSpinner()
//        group.leave()
//    }
//    group.wait()
//    if isValid {
//        print("✅ Credentials validated successfully.")
//        exit(EXIT_SUCCESS)
//    } else {
//        print("❌ Credentials validation failed.")
//        exit(EXIT_FAILURE)
//    }
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

    // full run on a given label folder
    case "process-label":
        if arguments.count > 2 {
            processLabel(withParam: arguments[2])
        } else {
            print("Error: task2 requires a parameter")
            exit(1)
        }

    // clean up cache
    case "cache-cleanup":
        CacheManagerUtil.runCleanup()

    case "label-update":
        labelUpdates()

    // full run for all ready labels
    case "intune-automation":
        runIntuneAutomationQuiet()

    // full run for all ready labels
    case "intune-upload":
        runIntuneAutomation()

    // process a single automation run ondemand
    case "ondemand":
        onDemandProcessLabels()
        
    // Check for self updates
    case "update-check":
        checkForUpdates()
    case "login":
        login()

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
