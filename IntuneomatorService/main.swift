//
//  main.swift
//  IntuneomatorService
//
//  Created by Gil Burns on 3/11/25.
//

import Foundation

// MARK: - Version Support
func printVersion() {
    let name = VersionInfo.getAppName()
    let version = VersionInfo.getVersionString()
    print("\(name) v\(version)")
}

func handleVersionArguments() -> Bool {
    let arguments = CommandLine.arguments
    
    if arguments.contains("--version") || arguments.contains("-v") {
        printVersion()
        return true
    }
    
    return false
}

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
        isSpinning = false
        print("\r\rDone!", terminator: "")
        fflush(stdout)
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

      --version, -v           Display version information
      help                    Display this help message
    """)
}

// MARK: - Label Update Teams Notifications
func sendLabelUpdateTeamsNotifications(withPreviousVersion previousLabelsVersion: String, andCurrentVersion currentLabelsVersion: String, updatedLabels: [String], isSuccess: Bool) async {
    // 🔔 Teams Notification
    
    let sendTeamNotification = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false
    let sendForUpdates = ConfigManager.readPlistValue(key: "TeamsNotificationsForLabelUpdates") ?? false
    
    if sendTeamNotification && sendForUpdates {
        let url = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
        
        if url.isEmpty {
            Logger.info("No Teams Webhook URL set in Config. Not sending notification.", category: .core)
        } else {
            Logger.info("Labels versions: \(previousLabelsVersion) \(currentLabelsVersion)", category: .core)
            let teamsNotifier = TeamsNotifier(webhookURL: url)
            await teamsNotifier.sendLabelUpdateNotification(initialVersion: previousLabelsVersion, updatedVersion: currentLabelsVersion, updatedLabels: updatedLabels, isSuccess: isSuccess)
        }
    }
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
        _ = await LabelAutomation.processFolder(named: folderName)
        group.leave()
    }

    group.wait()
    stopSpinner()
}


func processLabelQuiet(withParam folderName: String) async -> (String, String, String, Bool) {
    
    let (result, displayName, newAppID, ok) = await LabelAutomation.processFolder(named: folderName)
    return (result, displayName, newAppID, ok)
    
}

func labelUpdates() {
    Task {
        let (isUpToDate, versionMessage, sha) = await InstallomatorLabels.compareInstallomatorVersionAsync()
        Logger.info("🔍 Version Check: \(versionMessage)", category: .core)

        if isUpToDate {
            Logger.info("✅ No update needed.", category: .core)
            exit(EXIT_SUCCESS)
        }

        let localVersionString = InstallomatorLabels.getInstallomatorLocalVersion()
        let parts = versionMessage.components(separatedBy: ": ")
        let currentVersionString: String
        if let dateString = parts.last {
            currentVersionString = dateString
        } else {
            currentVersionString = "Unknown"
        }
        Logger.info("⬇️ Updating Installomator labels...", category: .core)

        let (success, updateMessage) = await InstallomatorLabels.installInstallomatorLabelsAsync(withUpdatingLabels: false)
        if success {
            Logger.info("✅ \(updateMessage)", category: .core)
            let updatedLabels: [String]
            do {
                updatedLabels = try await InstallomatorLabels.updateInUseLabels()
            } catch {
                Logger.error("❌ Failed to get updated labels: \(error.localizedDescription)", category: .core)
                await sendLabelUpdateTeamsNotifications(withPreviousVersion: localVersionString, andCurrentVersion: currentVersionString, updatedLabels: [], isSuccess: false)
                exit(EXIT_FAILURE)
            }
            Logger.info("Local version: \(localVersionString)", category: .core)
            Logger.info("Current version: \(currentVersionString)", category: .core)
            Logger.info("Updated labels: \(updatedLabels)", category: .core)

            await sendLabelUpdateTeamsNotifications(withPreviousVersion: localVersionString, andCurrentVersion: currentVersionString, updatedLabels: updatedLabels, isSuccess: success)
            exit(EXIT_SUCCESS)
        } else {
            Logger.info("❌ \(updateMessage)", category: .core)
            await sendLabelUpdateTeamsNotifications(withPreviousVersion: localVersionString, andCurrentVersion: currentVersionString, updatedLabels: [], isSuccess: success)
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
    
    let group = DispatchGroup()

    group.enter()
    Task {


        Logger.info("-------------------------------------------------------------------------", category: .core)
        Logger.info("Running Intune Automation...", category: .core)

        let validFolders = LabelAutomation.scanAndValidateFolders()
        Logger.info("Found -\(validFolders.count)- Intuneomator folders to process.", category: .core)

        // Collect results for each processed folder
        var processingResults: [(folder: String, displayName: String, text: String, newAppID: String, success: Bool)] = []
        var filteredProcessingResults: [(folder: String, displayName: String, text: String, newAppID: String, success: Bool)] = []

        for (index, folder) in validFolders.enumerated() {
            Logger.info("Processing folder \(index+1)/\(validFolders.count): \(folder)", category: .core)
            Logger.info("  Updating Installomator label data: \(folder)", category: .core)

            // Update label plist (process_label.sh)
            processLabelScript(withParam: folder)
            Logger.info("  Processing \(folder).", category: .core)
            
            // Run the automation for folder and capture the result
            let (text, displayName, newAppID, success) = await processLabelQuiet(withParam: folder)
            processingResults.append((folder: folder, displayName: displayName, text: text, newAppID: newAppID, success: success))
        }
        
        // Write full results to a file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"

        let currentDate = dateFormatter.string(from: Date())

        let lines = processingResults.map { result in
            return "\(result.success)\t\(result.folder)\t\(result.text)"
        }
        let fileContents = lines.joined(separator: "\n")
        let fileURL = AppConstants.intuneomatorLogSystemURL
            .appendingPathComponent("\(currentDate)_Automation_Run_Results.txt")
        do {
            try fileContents.write(to: fileURL, atomically: true, encoding: .utf8)
            Logger.info("Wrote results to \(fileURL.path)", category: .core)
        } catch {
            Logger.error("❌ Failed writing results file: \(error.localizedDescription)", category: .core)
        }
        
        // Filter the results for the Teams message.
        for result in processingResults {
            // Only include results where the message does not end with "already exists in Intune"
            if !result.text.hasSuffix("already exists in Intune") {
                filteredProcessingResults.append(result)
            }
        }

        // Send a Teams notification with the filtered results
        let sendTeamNotification = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false
        let teamsNotificationStyle: Int = ConfigManager.readPlistValue(key: "TeamsNotificationsStyle") ?? 0
        
        if sendTeamNotification && teamsNotificationStyle == 1 {
            let url = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
            if !url.isEmpty {
                let teamsNotifier = TeamsNotifier(webhookURL: url)
                await teamsNotifier.sendSingleSuccessNotification(processingResults: filteredProcessingResults)
            } else {
                Logger.info("No Teams Webhook URL set in Config. Skipping batch notification.", category: .core)
            }
        }

        // Check for authentication expirations before exiting
        guard let authMethod: String = ConfigManager.readPlistValue(key: "AuthMethod") else {
            return
        }

        switch authMethod {
        case "certificate":
            let expirationChecker = ExpirationChecker()
            expirationChecker.checkCertificateExpirationAndNotify()
        case "secret":
            let expirationChecker = ExpirationChecker()
            expirationChecker.checkSecretExpirationAndNotify()
        default:
            Logger.info("Unsupported authMethod: \(authMethod)", category: .core)
        }

        group.leave()
    }

    group.wait()

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
    Logger.info("🔍 Starting update check...", category: .core)
    
    // Since DaemonUpdateManager calls exit() internally, we need to run it directly
    // The current design expects to run as a standalone process
    Logger.info("📡 Calling DaemonUpdateManager.checkAndPerformUpdateIfNeeded()", category: .core)
    Logger.info("⚠️ Note: This function will exit the process when complete", category: .core)
    
    // Call directly - this will exit the process with appropriate exit code
    DaemonUpdateManager.checkAndPerformUpdateIfNeeded()
    
    // Keep the main thread alive to allow async network requests to complete
    // The DaemonUpdateManager will call exit() when done
    Logger.info("⏳ Keeping process alive for async operations...", category: .core)
    RunLoop.main.run()
    
    // This line should never be reached due to exit() calls in DaemonUpdateManager
    Logger.error("❌ Unexpected: DaemonUpdateManager returned without exiting", category: .core)
}

func testFunction() {
    print("Test function called")
    // Implementation placeholder for testing purposes
}


// MARK: - Login Command
func login() {
    print("Validating credentials...")
    let stopSpinner = startSpinner(message: "Validating credentials")
    var isValid = false
    let group = DispatchGroup()
    group.enter()
    Task {
        do {
            isValid = try await EntraAuthenticator.shared.ValidateCredentials()
        } catch {
            Logger.error("❌ Credential validation error: \(error.localizedDescription)", category: .core)
            isValid = false
        }
        stopSpinner()
        group.leave()
    }
    group.wait()
    if isValid {
        print("✅ Credentials validated successfully.")
        exit(EXIT_SUCCESS)
    } else {
        print("❌ Credentials validation failed.")
        exit(EXIT_FAILURE)
    }
}

// MARK: - Entitlements
func secCall<Result>(_ body: (_ resultPtr: UnsafeMutablePointer<Result?>) -> OSStatus  ) throws -> Result {
    var result: Result? = nil
    let err = body(&result)
    guard err == errSecSuccess else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
    }
    return result!
}

func checkEntitlements() throws {
    let me = try secCall { SecCodeCopySelf([], $0) }
    let meStatic = try secCall { SecCodeCopyStaticCode(me, [], $0) }
    let infoCF = try secCall { SecCodeCopySigningInformation(meStatic, [], $0) }
    let info = infoCF as NSDictionary
    let entitlements = info[kSecCodeInfoEntitlementsDict] as? NSDictionary
    print("entitlements: %@", entitlements ?? [:])
}

// MARK: - Command Line Argument Handling
func handleCommandLineArguments() {
    let arguments = CommandLine.arguments
    
    // Handle version arguments first
    if handleVersionArguments() {
        exit(EXIT_SUCCESS)
    }
    
    // MARK: - Start Main RunLoop
    // If no arguments provided or only the path argument (index 0)
    if arguments.count <= 1 {
        // Log version on daemon startup
        let serviceName = VersionInfo.getAppName()
        let serviceVersion = VersionInfo.getVersionString()
        Logger.info("Starting \(serviceName) version \(serviceVersion)", category: .core)
        
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
            print("Error: process-label-script requires a folder name parameter")
            exit(1)
        }

    // full run on a given label folder
    case "process-label":
        if arguments.count > 2 {
            processLabel(withParam: arguments[2])
        } else {
            print("Error: process-label requires a folder name parameter")
            exit(1)
        }

    // clean up cache and logs
    case "cache-cleanup":
        
        do {
            // cache cleanup
            CacheManagerUtil.runCleanup()
            
            // cleanup system logs
            LogManagerUtil.performLogCleanup()

            // cleanup user‐level logs
            LogManagerUtil.performLogCleanup(forLogFolder: "user")
        }


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
        
    case "test":
        testFunction()

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
