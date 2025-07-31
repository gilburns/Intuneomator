//
//  XPCService+AppsReporting.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/11/25.
//

import Foundation

/// XPCService extension for Microsoft Intune App management operations
/// Handles secure communication with Microsoft Graph API endpoints for Intune App operations
/// All operations use authenticated tokens and provide comprehensive error handling through async callbacks
extension XPCService {
    // MARK: - Intune App Reporting Management
 
    /// Retrieves all apps from Microsoft Intune
    /// - Parameter reply: Callback with array of Intune app dictionaries or nil on failure
    func fetchIntuneApps(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let webClips = try await EntraGraphRequests.fetchIntuneApps(authToken: authToken)
                reply(webClips)
            } catch {
                Logger.error("Failed to fetch Intune Apps: \(error.localizedDescription)", category: .reports)
                reply(nil)
            }
        }
    }
    
    func getDeviceAppInstallationStatusReport(appId: String, reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let installationStatus = try await EntraGraphRequests.getDeviceAppInstallationStatusReport(authToken: authToken, appId: appId)
                reply(installationStatus)
            } catch {
                Logger.error("Failed to fetch Intune App installation status: \(error.localizedDescription)", category: .reports)
                reply(nil)
            }
        }

    }
    
    // MARK: - Intune Configuration Profile Reporting Management

    /// Retrieves all configuration profiles from Microsoft Intune across all platforms
    /// - Parameter reply: Callback with array of Intune configuration profile dictionaries or nil on failure
    func fetchIntuneConfigurationProfiles(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let configurationProfiles = try await EntraGraphRequests.fetchIntuneConfigurationProfiles(authToken: authToken)
                reply(configurationProfiles)
            } catch {
                Logger.error("Failed to fetch Intune Configuration Profiles: \(error.localizedDescription)", category: .reports)
                reply(nil)
            }
        }
    }
    
    /// Retrieves device configuration profile deployment status report for a specific profile
    /// - Parameters:
    ///   - profileId: Unique identifier (GUID) of the configuration profile to get deployment status for
    ///   - reply: Callback with array of device deployment status dictionaries or nil on failure
    func getDeviceConfigProfileDeploymentStatusReport(profileId: String, reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                // Check if this is a compliance policy based on profile data
                // For compliance policies, use the compliance-specific reporting endpoint
                let deploymentStatus = try await EntraGraphRequests.getDeviceConfigProfileDeploymentStatusReport(authToken: authToken, profileId: profileId)
                reply(deploymentStatus)
            } catch {
                Logger.error("Failed to fetch configuration profile deployment status: \(error.localizedDescription)", category: .reports)
                reply(nil)
            }
        }
    }
    
    // MARK: - Microsoft Graph Export Jobs API
    
    /// Creates a new export job for a specific report type
    /// - Parameters:
    ///   - reportName: Name of the report to export (e.g., "DeviceInstallStatusByApp")
    ///   - filter: Optional OData filter string
    ///   - select: Optional array of column names to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - reply: Callback with export job ID or nil on failure
    func createExportJob(reportName: String, filter: String?, select: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createExportJob(
                    authToken: authToken,
                    reportName: reportName,
                    filter: filter,
                    select: select,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create export job for \(reportName): \(error.localizedDescription)", category: .reports)
                reply(nil)
            }
        }
    }
    
    /// Checks the status of an export job
    /// - Parameters:
    ///   - jobId: Export job ID to check
    ///   - reply: Callback with job status dictionary or nil on failure
    func getExportJobStatus(jobId: String, reply: @escaping ([String: Any]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobStatus = try await EntraGraphRequests.getExportJobStatus(authToken: authToken, jobId: jobId)
                reply(jobStatus)
            } catch {
                Logger.error("Failed to get export job status for \(jobId): \(error.localizedDescription)", category: .reports)
                reply(nil)
            }
        }
    }
    
    /// Downloads completed export job data
    /// - Parameters:
    ///   - downloadUrl: Download URL from completed export job
    ///   - reply: Callback with downloaded data or nil on failure
    func downloadExportJobData(downloadUrl: String, reply: @escaping (Data?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let data = try await EntraGraphRequests.downloadExportJobData(authToken: authToken, downloadUrl: downloadUrl)
                reply(data)
            } catch {
                Logger.error("Failed to download export job data from \(downloadUrl): \(error.localizedDescription)", category: .reports)
                reply(nil)
            }
        }
    }
    
    /// Polls an export job until completion and downloads the result
    /// - Parameters:
    ///   - jobId: Export job ID to poll
    ///   - maxWaitTimeSeconds: Maximum time to wait for completion (default: 300)
    ///   - pollIntervalSeconds: Interval between status checks (default: 5)
    ///   - reply: Callback with downloaded data or nil on failure
    func pollAndDownloadExportJob(jobId: String, maxWaitTimeSeconds: Int, pollIntervalSeconds: Int, reply: @escaping (Data?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let data = try await EntraGraphRequests.pollAndDownloadExportJob(
                    authToken: authToken,
                    jobId: jobId,
                    maxWaitTimeSeconds: maxWaitTimeSeconds,
                    pollIntervalSeconds: pollIntervalSeconds
                )
                reply(data)
            } catch {
                Logger.error("Failed to poll and download export job \(jobId): \(error.localizedDescription)", category: .reports)
                reply(nil)
            }
        }
    }

    // MARK: - Scheduled Reports File Management
    
    /// Saves a scheduled report configuration to the secured reports directory
    /// - Parameters:
    ///   - reportData: Encoded scheduled report data (JSON)
    ///   - fileName: Name of the report file (including .json extension)
    ///   - reply: Callback indicating if save was successful
    func saveScheduledReportConfiguration(reportData: Data, fileName: String, reply: @escaping (Bool) -> Void) {
        do {
            let scheduledReportsDirectory = AppConstants.intuneomatorScheduledReportsFolderURL
            
            // Ensure directory exists
            try FileManager.default.createDirectory(at: scheduledReportsDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // Write the report file
            let fileURL = scheduledReportsDirectory.appendingPathComponent(fileName)
            try reportData.write(to: fileURL)
            
            Logger.info("Saved scheduled report configuration: \(fileName)", category: .reports, toUserDirectory: true)
            reply(true)
            
        } catch {
            Logger.error("Failed to save scheduled report configuration '\(fileName)': \(error)", category: .reports, toUserDirectory: true)
            reply(false)
        }
    }
    
    /// Deletes a scheduled report configuration from the secured reports directory
    /// - Parameters:
    ///   - fileName: Name of the report file to delete (including .json extension)
    ///   - reply: Callback indicating if deletion was successful
    func deleteScheduledReportConfiguration(fileName: String, reply: @escaping (Bool) -> Void) {
        do {
            let scheduledReportsDirectory = AppConstants.intuneomatorScheduledReportsFolderURL
            let fileURL = scheduledReportsDirectory.appendingPathComponent(fileName)
            
            Logger.info("Attempting to delete scheduled report: \(fileName) at path: \(fileURL.path)", category: .reports, toUserDirectory: true)
            
            // Check if file exists before attempting deletion
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                Logger.warning("Attempted to delete non-existent scheduled report: \(fileName) at path: \(fileURL.path)", category: .reports, toUserDirectory: true)
                reply(false)
                return
            }
            
            // Additional logging to verify file attributes
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            Logger.info("File exists - size: \(attributes[.size] ?? "unknown"), permissions: \(attributes[.posixPermissions] ?? "unknown")", category: .reports, toUserDirectory: true)
            
            try FileManager.default.removeItem(at: fileURL)
            
            // Verify deletion was successful
            if FileManager.default.fileExists(atPath: fileURL.path) {
                Logger.error("File still exists after deletion attempt: \(fileName)", category: .reports, toUserDirectory: true)
                reply(false)
            } else {
                Logger.info("Successfully deleted scheduled report configuration: \(fileName)", category: .reports, toUserDirectory: true)
                reply(true)
            }
            
        } catch {
            Logger.error("Failed to delete scheduled report configuration '\(fileName)': \(error.localizedDescription)", category: .reports, toUserDirectory: true)
            reply(false)
        }
    }
    
    /// Updates the scheduled reports index file
    /// - Parameters:
    ///   - indexData: Encoded index data (JSON)
    ///   - reply: Callback indicating if update was successful
    func updateScheduledReportsIndex(indexData: Data, reply: @escaping (Bool) -> Void) {
        do {
            let scheduledReportsDirectory = AppConstants.intuneomatorScheduledReportsFolderURL
            
            // Ensure directory exists
            try FileManager.default.createDirectory(at: scheduledReportsDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // Write the index file
            let indexURL = scheduledReportsDirectory.appendingPathComponent("index.json")
            try indexData.write(to: indexURL)
            
            Logger.info("Updated scheduled reports index", category: .reports, toUserDirectory: true)
            reply(true)
            
        } catch {
            Logger.error("Failed to update scheduled reports index: \(error)", category: .reports, toUserDirectory: true)
            reply(false)
        }
    }
    
    // MARK: - Scheduled Report File Management
    
    /// Gets all scheduled reports from the file system
    /// - Returns: Tuple containing array of scheduled reports and success status
    private func getAllScheduledReports() -> ([ScheduledReport], Bool) {
        let reportsDirectory = AppConstants.intuneomatorScheduledReportsFolderURL
        
        Logger.info("📁 Looking for scheduled reports in: \(reportsDirectory.path)", category: .reports)
        
        do {
            // Ensure directory exists
            if !FileManager.default.fileExists(atPath: reportsDirectory.path) {
                Logger.info("📁 Reports directory doesn't exist, creating: \(reportsDirectory.path)", category: .reports)
                try FileManager.default.createDirectory(at: reportsDirectory, withIntermediateDirectories: true, attributes: nil)
                return ([], true)
            }
            
            let reportFiles = try FileManager.default.contentsOfDirectory(at: reportsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" && $0.lastPathComponent != "index.json" }
            
            Logger.info("📄 Found \(reportFiles.count) JSON report files", category: .reports)
            for file in reportFiles {
                Logger.info("📄 Report file: \(file.lastPathComponent)", category: .reports)
            }
            
            var reports: [ScheduledReport] = []
            
            for fileURL in reportFiles {
                Logger.info("📖 Loading report file: \(fileURL.lastPathComponent)", category: .reports)
                if let report = loadScheduledReportFromFile(fileURL) {
                    Logger.info("✅ Successfully loaded report: \(report.name)", category: .reports)
                    reports.append(report)
                } else {
                    Logger.error("❌ Failed to load report file: \(fileURL.lastPathComponent)", category: .reports)
                }
            }
            
            return (reports.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }, true)
            
        } catch {
            Logger.error("Failed to load scheduled reports: \(error)", category: .reports)
            return ([], false)
        }
    }
    
    /// Loads a scheduled report from a file
    /// - Parameter fileURL: The file URL to load from
    /// - Returns: The scheduled report or nil if loading failed
    private func loadScheduledReportFromFile(_ fileURL: URL) -> ScheduledReport? {
        do {
            Logger.info("🔍 Reading data from: \(fileURL.lastPathComponent)", category: .reports)
            let data = try Data(contentsOf: fileURL)
            Logger.info("📊 File size: \(data.count) bytes", category: .reports)
            
            Logger.info("🔄 Attempting JSON decode...", category: .reports)
            var report = try JSONDecoder().decode(ScheduledReport.self, from: data)
            Logger.info("✅ JSON decode successful for: \(report.name)", category: .reports)
            
            // Update next run time if it's nil or outdated (in memory only)
            if report.nextRun == nil || (report.nextRun != nil && report.nextRun! < Date()) {
                Logger.info("⏰ Updating next run time for: \(report.name)", category: .reports)
                report.nextRun = report.schedule.calculateNextRun(from: Date())
            }
            
            return report
        } catch {
            Logger.error("❌ Failed to load scheduled report from \(fileURL.lastPathComponent): \(error)", category: .reports)
            return nil
        }
    }
    
    /// Saves a scheduled report to file and updates its next run time
    /// - Parameters:
    ///   - report: The report to save
    ///   - success: Whether the last execution was successful
    private func updateReportAfterExecution(_ report: ScheduledReport, success: Bool) async {
        var updatedReport = report
        
        // Update last run information
        updatedReport.lastRun = Date()
        updatedReport.lastRunResult = RunResult(
            success: success,
            format: updatedReport.format,
            error: success ? nil : "Execution failed",
            runDuration: 0 // This could be tracked if needed
        )
        
        // Calculate next run time
        updatedReport.nextRun = updatedReport.schedule.calculateNextRun(from: Date())
        
        // Save the updated report
        do {
            let data = try JSONEncoder().encode(updatedReport)
            let fileName = updatedReport.fileName
            
            // Use XPC to save the file since we need root privileges
            await withCheckedContinuation { continuation in
                saveScheduledReportConfiguration(reportData: data, fileName: fileName) { saveSuccess in
                    if saveSuccess {
                        Logger.info("Updated scheduled report after execution: \(updatedReport.name)", category: .reports)
                    } else {
                        Logger.error("Failed to update scheduled report after execution: \(updatedReport.name)", category: .reports)
                    }
                    continuation.resume()
                }
            }
        } catch {
            Logger.error("Failed to encode updated scheduled report: \(error)", category: .reports)
        }
    }
    
    // MARK: - Scheduled Report Execution
    
    /// Static method for direct execution by command-line daemon
    /// Delegates to ScheduledReportsManager for consistency with other command-line handlers
    /// - Returns: Execution summary dictionary
    static func executeScheduledReports() async -> [String: Any] {
        return await ScheduledReportsManager.executeScheduledReportsWithSummary()
    }
    
    /// Checks for and executes any scheduled reports that are due to run
    /// This method is called periodically by the scheduler daemon
    /// - Parameter reply: Callback with execution summary (number of reports processed, successes, failures)
    func executeScheduledReports(reply: @escaping ([String: Any]) -> Void) {
        Task {
            Logger.info("🕒 Checking for scheduled reports due to run...", category: .reports)
            
            var executionSummary: [String: Any] = [
                "timestamp": Date(),
                "totalReportsChecked": 0,
                "reportsExecuted": 0,
                "successfulExecutions": 0,
                "failedExecutions": 0,
                "results": [[String: Any]]()
            ]
            
            // Load all scheduled reports
            Logger.info("🔄 About to call getAllScheduledReports()...", category: .reports)
            let (allReports, loadSuccess) = getAllScheduledReports()
            Logger.info("🔄 getAllScheduledReports() returned - count: \(allReports.count), loadSuccess: \(loadSuccess)", category: .reports)
            
            executionSummary["totalReportsChecked"] = allReports.count
            
            Logger.info("📋 Found \(allReports.count) total scheduled reports", category: .reports)
            
            guard !allReports.isEmpty else {
                Logger.info("📋 No scheduled reports found", category: .reports)
                reply(executionSummary)
                return
            }
            
            Logger.info("🔄 About to start processing reports...", category: .reports)
            let currentTime = Date()
            var executedCount = 0
            var successCount = 0
            var failureCount = 0
            var results: [[String: Any]] = []
            
            Logger.info("🔄 Starting report loop with \(allReports.count) reports...", category: .reports)
            // Check each report to see if it's due to run
            for report in allReports {
                Logger.info("📊 Checking report '\(report.name)' - Enabled: \(report.isEnabled), NextRun: \(report.nextRun?.description ?? "nil")", category: .reports)
                
                guard report.isEnabled,
                      let nextRun = report.nextRun,
                      nextRun <= currentTime else {
                    Logger.info("⏭️ Skipping report '\(report.name)' - not due yet or disabled", category: .reports)
                    continue
                }
                
                Logger.info("⚡ Executing scheduled report: \(report.name)", category: .reports)
                executedCount += 1
                
                let executionStart = Date()
                let success = await executeScheduledReport(report)
                let executionTime = Date().timeIntervalSince(executionStart)
                
                // Record execution result
                let result: [String: Any] = [
                    "reportName": report.name,
                    "reportType": report.reportType,
                    "success": success,
                    "executionTime": executionTime,
                    "timestamp": currentTime
                ]
                results.append(result)
                
                if success {
                    successCount += 1
                    Logger.info("✅ Successfully executed: \(report.name)", category: .reports)
                    
                    // Update the report's next run time and last run
                    await updateReportAfterExecution(report, success: true)
                } else {
                    failureCount += 1
                    Logger.error("❌ Failed to execute: \(report.name)", category: .reports)
                    
                    // Still update next run time even on failure to prevent constant retries
                    await updateReportAfterExecution(report, success: false)
                }
            }
            
            // Update summary
            executionSummary["reportsExecuted"] = executedCount
            executionSummary["successfulExecutions"] = successCount
            executionSummary["failedExecutions"] = failureCount
            executionSummary["results"] = results
            
            Logger.info("🔄 Finished processing all reports", category: .reports)
            
            if executedCount > 0 {
                Logger.info("📊 Scheduler summary: \(executedCount) executed, \(successCount) successful, \(failureCount) failed", category: .reports)
            } else {
                Logger.info("⏱️ No scheduled reports were due to run", category: .reports)
            }
            
            Logger.info("🔄 About to call reply() with executionSummary...", category: .reports)
            reply(executionSummary)
            Logger.info("🔄 reply() called successfully", category: .reports)
        }
    }
    
    /// Executes a single scheduled report
    /// - Parameter report: The scheduled report to execute
    /// - Returns: True if the report was executed successfully, false otherwise
    private func executeScheduledReport(_ report: ScheduledReport) async -> Bool {
        do {
            Logger.info("🔄 Starting execution of report: \(report.name) (Type: \(report.reportType))", category: .reports)
            
            // Get authentication token
            let entraAuthenticator = EntraAuthenticator.shared
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            // Build OData filter from report filters
            let filterString = buildODataFilterFromScheduledReport(report)
            
            // Get default columns for this report type
            let defaultColumns = getDefaultColumnsForReportType(report.reportType)
            
            // Create the export job
            let jobId = try await EntraGraphRequests.createExportJob(
                authToken: authToken,
                reportName: report.reportType,
                filter: filterString,
                select: defaultColumns,
                format: report.format
            )
            
            Logger.info("📋 Created export job \(jobId) for report: \(report.name)", category: .reports)
            
            // Wait for job completion (with timeout)
            let maxWaitTime: TimeInterval = 300 // 5 minutes
            let startTime = Date()
            var isComplete = false
            var downloadUrl: String?
            
            while !isComplete && Date().timeIntervalSince(startTime) < maxWaitTime {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                
                let jobStatus = try await EntraGraphRequests.getExportJobStatus(
                    authToken: authToken,
                    jobId: jobId
                )
                
                if let status = jobStatus["status"] as? String {
                    Logger.info("📊 Export job \(jobId) status: \(status)", category: .reports)
                    
                    if status == "completed" {
                        isComplete = true
                        downloadUrl = jobStatus["url"] as? String
                    } else if status == "failed" {
                        Logger.error("❌ Export job \(jobId) failed", category: .reports)
                        return false
                    }
                }
            }
            
            guard isComplete, let url = downloadUrl else {
                Logger.error("❌ Export job \(jobId) timed out or failed", category: .reports)
                return false
            }
            
            // Download the report data
            let reportData = try await EntraGraphRequests.downloadExportJobData(authToken: authToken, downloadUrl: url)
            
            // Upload to Azure Storage
            let success = await uploadReportToAzureStorage(
                reportData: reportData,
                report: report,
                jobId: jobId
            )
            
            if success {
                // Send notification if enabled
                await sendReportNotification(report: report, success: true, jobId: jobId)
                Logger.info("✅ Successfully completed scheduled report: \(report.name)", category: .reports)
                return true
            } else {
                await sendReportNotification(report: report, success: false, jobId: jobId)
                return false
            }
            
        } catch {
            Logger.error("❌ Error executing scheduled report \(report.name): \(error)", category: .reports)
            await sendReportNotification(report: report, success: false, jobId: nil, error: error)
            return false
        }
    }
    
    
    /// Uploads report data to Azure Storage based on report configuration
    private func uploadReportToAzureStorage(reportData: Data, report: ScheduledReport, jobId: String) async -> Bool {
        do {
            // Get Azure Storage configuration
            let configData = await withCheckedContinuation { continuation in
                getNamedAzureStorageConfiguration(name: report.delivery.azureStorageConfigName) { config in
                    continuation.resume(returning: config)
                }
            }
            
            guard configData != nil else {
                Logger.error("❌ Azure Storage configuration '\(report.delivery.azureStorageConfigName)' not found", category: .reports)
                return false
            }
            
            // Build file name from template
            let fileName = buildFileNameFromTemplate(report: report, jobId: jobId)
            
            // Use Azure Storage Manager for upload
            let manager = try AzureStorageManager.withNamedConfiguration(report.delivery.azureStorageConfigName)
            
            // Create a temporary file to upload
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileURL = tempDir.appendingPathComponent(fileName)
            
            try reportData.write(to: tempFileURL)
            defer {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
            
            // Upload to Azure Storage
            try await manager.uploadReport(fileURL: tempFileURL)
            let uploadSuccess = true
            
            if uploadSuccess {
                Logger.info("☁️ Uploaded report to Azure Storage: \(fileName)", category: .reports)
                
                // Create shareable link if requested
                if report.delivery.createShareableLink,
                   let expirationDays = report.delivery.linkExpirationDays {
                    // Note: Shareable link functionality would need to be implemented in AzureStorageManager
                    // For now, just log that it was requested
                    Logger.info("🔗 Shareable link requested for report: \(report.name) (expires in \(expirationDays) days)", category: .reports)
                    // TODO: Implement shareable link creation through AzureStorageManager
                }
                
                return true
            } else {
                Logger.error("❌ Failed to upload report to Azure Storage", category: .reports)
                return false
            }
            
        } catch {
            Logger.error("❌ Error uploading to Azure Storage: \(error)", category: .reports)
            return false
        }
    }
    
    /// Sends notification about report execution if notifications are enabled
    private func sendReportNotification(report: ScheduledReport, success: Bool, jobId: String?, error: Error? = nil) async {
        guard report.notifications.enabled else { return }
        
        let webhookURL: String
        if report.notifications.useGlobalWebhook {
            // Get global webhook URL from config
            webhookURL = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
        } else {
            webhookURL = report.notifications.customWebhookURL ?? ""
        }
        
        guard !webhookURL.isEmpty else {
            Logger.error("❌ No webhook URL configured for report notifications", category: .reports)
            return
        }
        
        // Build notification message
        let template = report.notifications.messageTemplate ?? NotificationConfiguration.defaultMessageTemplate
        let message = buildNotificationMessage(
            template: template,
            report: report,
            success: success,
            jobId: jobId,
            error: error
        )
        
        // Send Teams notification
        let teamsNotifier = TeamsNotifier(webhookURL: webhookURL)
        let sendSuccess = await teamsNotifier.sendCustomMessage(message)
        
        if !sendSuccess {
            Logger.error("❌ Failed to send Teams notification for report: \(report.name)", category: .reports)
        }
        
        Logger.info("📢 Sent notification for report: \(report.name)", category: .reports)
    }
    
    /// Helper methods for building file paths and notification messages
    private func buildFileNameFromTemplate(report: ScheduledReport, jobId: String) -> String {
        let template = report.delivery.fileNameTemplate
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH-mm-ss"
        
        let fileName = template
            .replacingOccurrences(of: "{reportName}", with: report.name)
            .replacingOccurrences(of: "{reportType}", with: report.reportType)
            .replacingOccurrences(of: "{date}", with: dateFormatter.string(from: now))
            .replacingOccurrences(of: "{time}", with: timeFormatter.string(from: now))
            .replacingOccurrences(of: "{jobId}", with: jobId)
            .replacingOccurrences(of: "{extension}", with: report.format.lowercased())
        
        return fileName
    }
    
    private func buildFolderPathFromTemplate(report: ScheduledReport) -> String {
        let template = report.delivery.folderPath
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let folderPath = template
            .replacingOccurrences(of: "{reportType}", with: report.reportType)
            .replacingOccurrences(of: "{reportName}", with: report.name)
            .replacingOccurrences(of: "{date}", with: dateFormatter.string(from: now))
        
        return folderPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    
    private func buildNotificationMessage(template: String, report: ScheduledReport, success: Bool, jobId: String?, error: Error?) -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let status = success ? "✅ SUCCESS" : "❌ FAILED"
        let errorText = error?.localizedDescription ?? ""
        
        let message = template
            .replacingOccurrences(of: "{reportName}", with: report.name)
            .replacingOccurrences(of: "{reportType}", with: report.reportType)
            .replacingOccurrences(of: "{status}", with: status)
            .replacingOccurrences(of: "{timestamp}", with: formatter.string(from: now))
            .replacingOccurrences(of: "{error}", with: errorText)
            .replacingOccurrences(of: "{jobId}", with: jobId ?? "N/A")
        
        return message
    }
    
    private func buildODataFilterFromScheduledReport(_ report: ScheduledReport) -> String? {
        // Use the existing ReportRegistry logic to build OData filters
        // This assumes ReportRegistry has the buildODataFilter method we created earlier
        let filters = report.filters
        guard !filters.isEmpty else { return nil }
        
        // Convert filters dictionary to OData format
        var filterComponents: [String] = []
        for (key, value) in filters {
            guard !value.isEmpty && value != "All" else { continue }
            
            // Simple OData filter building - this could be enhanced with ReportRegistry integration
            if value.contains(" ") {
                filterComponents.append("contains(\(key),'\(value)')")
            } else {
                filterComponents.append("\(key) eq '\(value)'")
            }
        }
        
        return filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
    }
    
    private func getDefaultColumnsForReportType(_ reportType: String) -> [String] {
        // Return default columns for the report type
        // This could be enhanced to integrate with ReportRegistry
        switch reportType {
        case "Devices":
            return ["DeviceName", "LastContact", "OSVersion", "ComplianceState", "PrimaryUser"]
        case "DeviceCompliance":
            return ["DeviceName", "ComplianceState", "LastContact", "OSVersion"]
        case "DefenderAgents":
            return ["DeviceName", "DefenderVersion", "LastSeen", "ThreatState"]
        default:
            return ["DeviceName", "LastContact", "OSVersion"] // Basic fallback
        }
    }
    
    // MARK: - Scheduler Status
    
    /// Gets the current scheduler status and execution statistics
    /// - Parameter reply: Callback with scheduler status dictionary
    func getSchedulerStatus(reply: @escaping ([String: Any]) -> Void) {
        Task {
            var statusInfo: [String: Any] = [:]
            
            // Check if scheduler launchd plist exists and is loaded
            let plistPath = "/Library/LaunchDaemons/com.gilburns.intuneomator.scheduledreports.plist"
            let schedulerEnabled = FileManager.default.fileExists(atPath: plistPath)
            statusInfo["schedulerEnabled"] = schedulerEnabled
            statusInfo["schedulerInterval"] = 600 // 10 minutes from plist
            
            // Get report counts
            let (allReports, _) = getAllScheduledReports()
            let enabledReports = allReports.filter { $0.isEnabled }
            statusInfo["totalReports"] = allReports.count
            statusInfo["enabledReports"] = enabledReports.count
            
            // Try to get last scheduler run time from system logs
            // This is a best-effort attempt using system logs
            if let lastRun = getLastSchedulerRunTime() {
                statusInfo["lastSchedulerRun"] = lastRun
            }
            
            // Get next due report time
            let nextDueReport = enabledReports
                .compactMap { $0.nextRun }
                .min()
            if let nextDue = nextDueReport {
                statusInfo["nextReportDue"] = nextDue
            }
            
            // Check if any reports are overdue
            let now = Date()
            let overdueReports = enabledReports.filter { report in
                guard let nextRun = report.nextRun else { return false }
                return nextRun <= now
            }
            statusInfo["overdueReports"] = overdueReports.count
            
            // Calculate average execution time from recent reports (if available)
            let recentExecutions = allReports.compactMap { $0.lastRunResult?.runDuration }.prefix(10)
            if !recentExecutions.isEmpty {
                let averageTime = recentExecutions.reduce(0, +) / Double(recentExecutions.count)
                statusInfo["averageExecutionTime"] = averageTime
            }
            
            reply(statusInfo)
        }
    }
    
    /// Attempts to get the last scheduler run time from system logs
    /// - Returns: Date of last scheduler run, or nil if not found
    private func getLastSchedulerRunTime() -> Date? {
        // Try to read from scheduler log file
        let logPath = "/var/log/com.gilburns.intuneomator.scheduledreports.out.log"
        guard FileManager.default.fileExists(atPath: logPath) else {
            return nil
        }
        
        do {
            let logContent = try String(contentsOfFile: logPath)
            let lines = logContent.components(separatedBy: .newlines)
            
            // Look for recent scheduler start messages
            for line in lines.reversed() {
                if line.contains("Starting scheduled reports check") {
                    // Extract timestamp from log line
                    // Log format typically includes timestamp at the beginning
                    if let timestampRange = line.range(of: #"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"#, options: .regularExpression) {
                        let timestampString = String(line[timestampRange])
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        return formatter.date(from: timestampString)
                    }
                }
            }
        } catch {
            Logger.error("Failed to read scheduler log: \(error)", category: .reports)
        }
        
        return nil
    }

}
