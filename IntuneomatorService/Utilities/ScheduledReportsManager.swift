//
//  ScheduledReportsManager.swift
//  IntuneomatorService
//
//  Created by Gil Burns on 7/27/25.
//

import Foundation

/// Helper function to add timeout to async operations
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            return try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        group.cancelAll()
        return result
    }
}

struct TimeoutError: Error {}

/// Result data from report execution for notification purposes
struct ReportExecutionResult {
    let fileSize: Int64
    let recordCount: Int?
    let format: String
    let azureLink: String?
    let linkExpirationDays: Int?
}

/// Manager class for executing scheduled reports
/// Provides static methods for command-line daemon execution
class ScheduledReportsManager {
    
    /// Executes all scheduled reports that are due to run
    /// This is the main entry point called by the command-line daemon
    static func executeScheduledReports() async {
        Logger.info("🔄 Execute scheduled reports...", category: .reports)
//        let reportSummary = await executeScheduledReportsWithSummary()
//        Logger.info("📝 Summary: \(reportSummary)", category: .reports)
        
        do {
        let reportSummary = await executeScheduledReportsWithSummary()
        Logger.info("📝 Summary: \(reportSummary)", category: .reports)
            try await Task.sleep(for: .seconds(5)) // Suspends the current task for 5 seconds
        } catch {
            Logger.info(error.localizedDescription, category: .reports)
        }

    }
    
    /// Executes all scheduled reports that are due to run and returns execution summary
    /// Used by XPC service methods that need to return summary data
    /// - Returns: Dictionary containing execution statistics and results
    static func executeScheduledReportsWithSummary() async -> [String: Any] {
        Logger.info("🔄 Checking for scheduled reports due to run...", category: .reports)
        
        var executedCount = 0
        var successCount = 0
        var failureCount = 0
        var results: [[String: Any]] = []
        
        var executionSummary: [String: Any] = [
            "timestamp": Date(),
            "totalReportsChecked": 0,
            "reportsExecuted": 0,
            "successfulExecutions": 0,
            "failedExecutions": 0,
            "results": results
        ]
        
        // Load all scheduled reports
        let (allReports, loadSuccess) = await getAllScheduledReports()
        
        guard loadSuccess else {
            Logger.error("❌ Failed to load scheduled reports", category: .reports)
            executionSummary["error"] = "Failed to load scheduled reports"
            return executionSummary
        }
        
        executionSummary["totalReportsChecked"] = allReports.count
        Logger.info("📋 Found \(allReports.count) total scheduled reports", category: .reports)
        
        guard !allReports.isEmpty else {
            Logger.info("📋 No scheduled reports found", category: .reports)
            return executionSummary
        }
        
        let currentTime = Date()
        Logger.info("🕐 Current time for comparison: \(currentTime)", category: .reports)
        
        // Check each report to see if it's due to run
        Logger.info("🔄 Starting to check \(allReports.count) reports...", category: .reports)
        for report in allReports {
            Logger.info("📊 Checking report '\(report.name)' - Enabled: \(report.isEnabled), NextRun: \(report.nextRun?.description ?? "nil")", category: .reports)
            Logger.info("📊 Current time: \(currentTime), Report nextRun: \(report.nextRun?.description ?? "nil")", category: .reports)
            
            // Debug the time comparison
            if let nextRun = report.nextRun {
                let timeComparison = nextRun <= currentTime
                Logger.info("📊 Time comparison for '\(report.name)': nextRun (\(nextRun)) <= currentTime (\(currentTime)) = \(timeComparison)", category: .reports)
            }
            
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
                Logger.info("✅ Successfully executed: \(report.name) in \(String(format: "%.2f", executionTime))s", category: .reports)
                
                // Update the report's next run time and last run
                await updateReportAfterExecution(report, success: true)
            } else {
                failureCount += 1
                Logger.error("❌ Failed to execute: \(report.name)", category: .reports)
                
                // Still update next run time even on failure to prevent constant retries
                await updateReportAfterExecution(report, success: false)
            }
        }
        
        // Update final summary
        executionSummary["reportsExecuted"] = executedCount
        executionSummary["successfulExecutions"] = successCount
        executionSummary["failedExecutions"] = failureCount
        executionSummary["results"] = results
        
        if executedCount > 0 {
            Logger.info("📊 Scheduler summary: \(executedCount) executed, \(successCount) successful, \(failureCount) failed", category: .reports)
        } else {
            Logger.info("⏱️ No scheduled reports were due to run", category: .reports)
        }
        
        Logger.info("🏁 Scheduler execution completed, returning summary", category: .reports)
        return executionSummary
    }
    
    // MARK: - Private Helper Methods
    
    /// Gets all scheduled reports from the file system
    /// - Returns: Tuple containing array of scheduled reports and success status
    private static func getAllScheduledReports() async -> ([ScheduledReport], Bool) {
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
            
            var reports: [ScheduledReport] = []
            
            for fileURL in reportFiles {
                Logger.info("📖 Loading report file: \(fileURL.lastPathComponent)", category: .reports)
                do {
                    if let report = await loadScheduledReportFromFile(fileURL) {
                        Logger.info("✅ Successfully loaded report: \(report.name)", category: .reports)
                        Logger.debug("Report: \(report)", category: .reports)
                        reports.append(report)
                        Logger.debug("Reports Count: \(reports.count)", category: .reports)
                    } else {
                        Logger.error("❌ Failed to load report file: \(fileURL.lastPathComponent)", category: .reports)
                    }
                    Logger.info("🎯 Completed processing file: \(fileURL.lastPathComponent)", category: .reports)
                }
            }
            
            Logger.info("🏁 Finished loading all \(reports.count) reports", category: .reports)
            
            return (reports.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }, true)
            
        } catch {
            Logger.error("Failed to load scheduled reports: \(error)", category: .reports)
            return ([], false)
        }
    }
    
    /// Loads a scheduled report from a file
    /// - Parameter fileURL: The file URL to load from
    /// - Returns: The scheduled report or nil if loading failed
    private static func loadScheduledReportFromFile(_ fileURL: URL) async -> ScheduledReport? {
        do {
            Logger.info("🔍 Reading data from: \(fileURL.lastPathComponent)", category: .reports)
            let data = try Data(contentsOf: fileURL)
            Logger.info("📊 File size: \(data.count) bytes", category: .reports)
            
            Logger.info("🔄 Attempting JSON decode...", category: .reports)
            
            // Custom JSON decoder to handle macOS Reference Date (seconds since 2001-01-01)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let timestamp = try container.decode(Double.self)
                // Convert from macOS Reference Date (2001-01-01) to Date
                Logger.info("Timestamp: \(fileURL.lastPathComponent) - \(timestamp)", category: .reports)
                return Date(timeIntervalSinceReferenceDate: timestamp)
            }
            
            var report = try decoder.decode(ScheduledReport.self, from: data)
            Logger.info("✅ JSON decode successful for: \(report.name)", category: .reports)
            Logger.info("📅 Decoded nextRun: \(report.nextRun?.description ?? "nil")", category: .reports)
            
            // Don't recalculate nextRun during loading - preserve the original scheduled time
            // The execution logic will handle whether the report should run and update nextRun afterward
            if report.nextRun == nil {
                Logger.info("⏰ No nextRun time set for \(report.name), calculating initial schedule", category: .reports)
                report.nextRun = report.schedule.calculateNextRun(from: Date())
            } else {
                Logger.info("⏰ Preserving existing nextRun time for \(report.name): \(report.nextRun?.description ?? "nil")", category: .reports)
            }
            
            return report
        } catch {
            Logger.error("❌ Failed to load scheduled report from \(fileURL.lastPathComponent): \(error)", category: .reports)
            return nil
        }
    }
    
    /// Executes a single scheduled report
    /// - Parameter report: The scheduled report to execute
    /// - Returns: True if the report was executed successfully, false otherwise
    private static func executeScheduledReport(_ report: ScheduledReport) async -> Bool {
        do {
            Logger.info("🔄 Starting execution of report: \(report.name) (Type: \(report.reportType))", category: .reports)
            
            // Get authentication token
            let entraAuthenticator = EntraAuthenticator.shared
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            // Build OData filter from report filters
            let filterString = buildODataFilterFromScheduledReport(report)
            
            // Get columns to export (custom selection or defaults)
            let columnsToExport = getColumnsForScheduledReport(report)
            
            // Create the export job
            let jobId = try await EntraGraphRequests.createExportJob(
                authToken: authToken,
                reportName: report.reportType,
                filter: filterString,
                select: columnsToExport,
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
            
            // Download the report data (ZIP file from Microsoft Graph)
            let reportZipData = try await EntraGraphRequests.downloadExportJobData(authToken: authToken, downloadUrl: url)
            
            // Extract the actual CSV/JSON content from the ZIP file
            Logger.info("📦 Extracting report content from ZIP file (format: \(report.format))", category: .reports)
            let extractedData = try extractExportDataFromZip(reportZipData, expectedFormat: report.format)
            
            // Count records in the extracted data
            let recordCount = countRecordsInData(extractedData, format: report.format)
            
            let zipSize = ByteCountFormatter.string(fromByteCount: Int64(reportZipData.count), countStyle: .file)
            let extractedSize = ByteCountFormatter.string(fromByteCount: Int64(extractedData.count), countStyle: .file)
            Logger.info("📊 Extracted report: \(zipSize) ZIP → \(extractedSize) \(report.format.uppercased()) with \(recordCount) records", category: .reports)
            
            // Upload extracted data to Azure Storage and get Azure link
            let (uploadSuccess, azureLink) = await uploadExtractedDataToAzureStorage(
                extractedData: extractedData,
                report: report,
                jobId: jobId
            )
            
            if uploadSuccess {
                // Create execution result with all the details (using extracted file size and record count)
                let executionResult = ReportExecutionResult(
                    fileSize: Int64(extractedData.count),
                    recordCount: recordCount,
                    format: report.format,
                    azureLink: azureLink,
                    linkExpirationDays: report.delivery.createShareableLink ? report.delivery.linkExpirationDays : nil
                )
                
                // Send notification if enabled
                await sendReportNotification(report: report, success: true, jobId: jobId, executionResult: executionResult)
                Logger.info("✅ Successfully completed scheduled report: \(report.name)", category: .reports)
                return true
            } else {
                await sendReportNotification(report: report, success: false, jobId: jobId, executionResult: nil)
                return false
            }
            
        } catch {
            Logger.error("❌ Error executing scheduled report \(report.name): \(error)", category: .reports)
            await sendReportNotification(report: report, success: false, jobId: nil, error: error, executionResult: nil)
            return false
        }
    }
    
    /// Saves a scheduled report to file and updates its next run time
    /// - Parameters:
    ///   - report: The report to save
    ///   - success: Whether the last execution was successful
    private static func updateReportAfterExecution(_ report: ScheduledReport, success: Bool) async {
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
            let reportsDirectory = AppConstants.intuneomatorScheduledReportsFolderURL
            let fileURL = reportsDirectory.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            Logger.info("Updated scheduled report after execution: \(updatedReport.name)", category: .reports)
        } catch {
            Logger.error("Failed to update scheduled report after execution: \(error)", category: .reports)
        }
    }
    
    /// Helper methods for building file paths and notification messages
    private static func buildODataFilterFromScheduledReport(_ report: ScheduledReport) -> String? {
        let filters = report.filters
        guard !filters.isEmpty else { return nil }
        
        // Convert filters dictionary to OData format
        var filterComponents: [String] = []
        for (key, value) in filters {
            guard !value.isEmpty && value != "All" else { continue }
            
            // Simple OData filter building
            if value.contains(" ") {
                filterComponents.append("contains(\(key),'\(value)')")
            } else {
                filterComponents.append("\(key) eq '\(value)'")
            }
        }
        
        return filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
    }
    
    private static func getColumnsForScheduledReport(_ report: ScheduledReport) -> [String] {
        // Use custom selection if available, otherwise fall back to defaults
        if let selectedColumns = report.selectedColumns, !selectedColumns.isEmpty {
            return selectedColumns
        } else {
            // Use ReportRegistry as single source of truth for column definitions
            return ReportRegistry.shared.getDefaultColumns(for: report.reportType) ?? []
        }
    }
    
    /// Uploads extracted report data to Azure Storage and returns Azure link if shareable link is enabled
    private static func uploadExtractedDataToAzureStorage(extractedData: Data, report: ScheduledReport, jobId: String) async -> (success: Bool, azureLink: String?) {
        do {
            // Build file name from template
            let fileName = buildFileNameFromTemplate(report: report, jobId: jobId)
            
            // Use Azure Storage Manager for upload
            let manager = try AzureStorageManager.withNamedConfiguration(report.delivery.azureStorageConfigName)
            
            // Create a temporary file to upload with the extracted content
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileURL = tempDir.appendingPathComponent(fileName)
            
            try extractedData.write(to: tempFileURL)
            defer {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
            
            // Upload to Azure Storage
            try await manager.uploadReport(fileURL: tempFileURL)
            Logger.info("☁️ Uploaded extracted report to Azure Storage: \(fileName)", category: .reports)
            
            // Generate shareable link if requested
            if report.delivery.createShareableLink {
                let expirationDays = report.delivery.linkExpirationDays ?? 7
                Logger.info("🔗 Generating shareable link for report: \(report.name) (expires in \(expirationDays) days)", category: .reports)
                
                let azureLinkURL = try await manager.generateDownloadLink(
                    for: fileName,
                    expiresIn: expirationDays
                )
                let azureLink = azureLinkURL.absoluteString
                Logger.info("✅ Generated Azure Storage link: \(azureLink)", category: .reports)
                return (true, azureLink)
            }
            
            return (true, nil)
            
        } catch {
            Logger.error("❌ Error uploading extracted report to Azure Storage: \(error)", category: .reports)
            return (false, nil)
        }
    }
    
    /// Uploads report data to Azure Storage based on report configuration
    private static func uploadReportToAzureStorage(reportData: Data, report: ScheduledReport, jobId: String) async -> Bool {
        do {
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
            
            Logger.info("☁️ Uploaded report to Azure Storage: \(fileName)", category: .reports)
            
            // Create shareable link if requested
            if report.delivery.createShareableLink,
               let expirationDays = report.delivery.linkExpirationDays {
                Logger.info("🔗 Shareable link requested for report: \(report.name) (expires in \(expirationDays) days)", category: .reports)
                // TODO: Implement shareable link creation through AzureStorageManager
            }
            
            return true
            
        } catch {
            Logger.error("❌ Error uploading to Azure Storage: \(error)", category: .reports)
            return false
        }
    }
    
    /// Sends notification about report execution if notifications are enabled
    private static func sendReportNotification(report: ScheduledReport, success: Bool, jobId: String?, error: Error? = nil, executionResult: ReportExecutionResult? = nil) async {
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
            error: error,
            executionResult: executionResult
        )
        
        // Send Teams notification with proper card formatting for links
        let teamsNotifier = TeamsNotifier(webhookURL: webhookURL)
        let sendSuccess: Bool
        
        if let result = executionResult, let azureLink = result.azureLink {
            Logger.info("🔗 Sending Teams card with Azure link: \(azureLink)", category: .reports)
            // Use structured card with proper action button for link
            sendSuccess = await sendScheduledReportCard(
                teamsNotifier: teamsNotifier,
                report: report,
                success: success,
                executionResult: result,
                azureLink: azureLink
            )
        } else {
            Logger.info("📧 No Azure link available, sending simple message. ExecutionResult: \(executionResult?.azureLink ?? "nil")", category: .reports)
            // Fallback to simple message
            sendSuccess = await teamsNotifier.sendCustomMessage(message)
        }
        
        if !sendSuccess {
            Logger.error("❌ Failed to send Teams notification for report: \(report.name)", category: .reports)
        } else {
            Logger.info("📢 Sent notification for report: \(report.name)", category: .reports)
        }
    }
    
    private static func buildFileNameFromTemplate(report: ScheduledReport, jobId: String) -> String {
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
    
    private static func buildNotificationMessage(template: String, report: ScheduledReport, success: Bool, jobId: String?, error: Error?, executionResult: ReportExecutionResult?) -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let status = success ? "✅ SUCCESS" : "❌ FAILED"
        let errorText = error?.localizedDescription ?? ""
        
        var message = template
            .replacingOccurrences(of: "{reportName}", with: report.name)
            .replacingOccurrences(of: "{reportType}", with: report.reportType)
            .replacingOccurrences(of: "{status}", with: status)
            .replacingOccurrences(of: "{timestamp}", with: formatter.string(from: now))
            .replacingOccurrences(of: "{error}", with: errorText)
            .replacingOccurrences(of: "{jobId}", with: jobId ?? "N/A")
        
        // Add execution result variables if available
        if let result = executionResult {
            let recordCount = result.recordCount.map { "\($0)" } ?? "Unknown"
            let fileSize = ByteCountFormatter.string(fromByteCount: result.fileSize, countStyle: .file)
            let format = result.format.uppercased()
            
            message = message
                .replacingOccurrences(of: "{recordCount}", with: recordCount)
                .replacingOccurrences(of: "{fileSize}", with: fileSize)
                .replacingOccurrences(of: "{format}", with: format)
            
            if let link = result.azureLink {
                message = message.replacingOccurrences(of: "{azureLink}", with: link)
                
                if let expirationDays = result.linkExpirationDays {
                    let expirationDate = Calendar.current.date(byAdding: .day, value: expirationDays, to: now)
                    let expirationString = expirationDate.map { formatter.string(from: $0) } ?? "Unknown"
                    message = message.replacingOccurrences(of: "{expirationDate}", with: expirationString)
                } else {
                    message = message.replacingOccurrences(of: "{expirationDate}", with: "Never")
                }
            } else {
                message = message.replacingOccurrences(of: "{azureLink}", with: "Not available")
                message = message.replacingOccurrences(of: "{expirationDate}", with: "N/A")
            }
        } else {
            // No execution result available, use defaults
            message = message
                .replacingOccurrences(of: "{recordCount}", with: "Unknown")
                .replacingOccurrences(of: "{fileSize}", with: "Unknown")
                .replacingOccurrences(of: "{format}", with: report.format.uppercased())
                .replacingOccurrences(of: "{azureLink}", with: "Not available")
                .replacingOccurrences(of: "{expirationDate}", with: "N/A")
        }
        
        return message
    }
    
    /// Extracts the actual CSV/JSON content from a ZIP file returned by Microsoft Graph export jobs
    /// - Parameters:
    ///   - zipData: The ZIP file data from the export job
    ///   - expectedFormat: The expected format (csv or json)
    /// - Returns: The extracted CSV/JSON data
    /// - Throws: Extraction or file format errors
    private static func extractExportDataFromZip(_ zipData: Data, expectedFormat: String) throws -> Data {
        // Create a temporary directory to extract the ZIP
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up temporary directory
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Write ZIP data to temporary file
        let tempZipFile = tempDir.appendingPathComponent("export.zip")
        try zipData.write(to: tempZipFile)
        
        // Extract ZIP file using unzip command
        let unzipProcess = Process()
        unzipProcess.launchPath = "/usr/bin/unzip"
        unzipProcess.arguments = ["-qq", tempZipFile.path, "-d", tempDir.path] // -j flattens directory structure
        
        // Redirect output to prevent terminal spam
        unzipProcess.standardOutput = FileHandle.nullDevice
        unzipProcess.standardError = FileHandle.nullDevice
        
        unzipProcess.launch()
        unzipProcess.waitUntilExit()
        
        guard unzipProcess.terminationStatus == 0 else {
            throw NSError(domain: "ExportExtraction", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract ZIP file"])
        }
        
        // Find the extracted file with the expected format
        let extractedFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let targetExtension = expectedFormat.lowercased()
        
        // Look for a file with the expected extension
        guard let extractedFile = extractedFiles.first(where: { $0.pathExtension.lowercased() == targetExtension }) else {
            // If no file with expected extension, try to find any CSV or JSON file
            let fallbackFile = extractedFiles.first { url in
                let ext = url.pathExtension.lowercased()
                return ext == "csv" || ext == "json"
            }
            
            guard let fallbackFile = fallbackFile else {
                throw NSError(domain: "ExportExtraction", code: 2, userInfo: [NSLocalizedDescriptionKey: "No \(targetExtension.uppercased()) file found in export ZIP"])
            }
            
            Logger.warning("Expected \(targetExtension) file not found, using \(fallbackFile.lastPathComponent)", category: .reports)
            return try Data(contentsOf: fallbackFile)
        }
        
        Logger.info("Extracted \(extractedFile.lastPathComponent) from export ZIP", category: .reports)
        return try Data(contentsOf: extractedFile)
    }
    
    /// Counts the number of records in extracted report data
    /// - Parameters:
    ///   - data: The extracted CSV/JSON data
    ///   - format: The file format ("csv" or "json")
    /// - Returns: Number of records found
    private static func countRecordsInData(_ data: Data, format: String) -> Int {
        do {
            let content = String(data: data, encoding: .utf8) ?? ""
            
            switch format.lowercased() {
            case "csv":
                // Count lines and subtract 1 for header
                let lines = content.components(separatedBy: .newlines)
                let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                return max(0, nonEmptyLines.count - 1) // Subtract header
                
            case "json":
                // Try to parse JSON and count array elements
                if let jsonData = content.data(using: .utf8) {
                    let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
                    
                    // Check if it's a dictionary with a "value" array (Microsoft Graph format)
                    if let dictionary = jsonObject as? [String: Any],
                       let valueArray = dictionary["value"] as? [Any] {
                        return valueArray.count
                    }
                    
                    // Check if it's a direct array
                    if let directArray = jsonObject as? [Any] {
                        return directArray.count
                    }
                }
                
                // If JSON parsing fails, try to count objects by counting opening braces
                let objectCount = content.components(separatedBy: "{").count - 1
                return max(0, objectCount - 1) // Subtract 1 for root object
                
            default:
                Logger.warning("Unknown format '\(format)' for record counting", category: .reports)
                return 0
            }
        } catch {
            Logger.error("Error counting records in \(format) data: \(error)", category: .reports)
            return 0
        }
    }
    
    /// Sends a structured Teams card for scheduled reports with proper action buttons
    private static func sendScheduledReportCard(
        teamsNotifier: TeamsNotifier,
        report: ScheduledReport,
        success: Bool,
        executionResult: ReportExecutionResult,
        azureLink: String
    ) async -> Bool {
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let fileSize = ByteCountFormatter.string(fromByteCount: executionResult.fileSize, countStyle: .file)
        let recordCount = executionResult.recordCount.map { "\($0)" } ?? "Unknown"
        
        // Calculate expiration date
        let expirationText: String
        if let expirationDays = executionResult.linkExpirationDays {
            let expirationDate = Calendar.current.date(byAdding: .day, value: expirationDays, to: Date())
            expirationText = expirationDate.map { formatter.string(from: $0) } ?? "Unknown"
        } else {
            expirationText = "Never"
        }
        
        let bodyContent: [[String: Any]] = [
            // Header
            [
                "type": "TextBlock",
                "text": "📊 **Scheduled Report Complete**",
                "weight": "Bolder",
                "size": "Large",
                "format": "markdown"
            ],
            // Report name
            [
                "type": "TextBlock",
                "text": "**\(report.name)** generated successfully",
                "spacing": "Medium",
                "format": "markdown"
            ],
            // Details section
            [
                "type": "FactSet",
                "facts": [
                    ["title": "Records", "value": recordCount],
                    ["title": "File Size", "value": fileSize],
                    ["title": "Format", "value": executionResult.format.uppercased()],
                    ["title": "Link Expires", "value": expirationText]
                ],
                "spacing": "Medium"
            ]
        ]
        
        // Add action button for download link
        let actions: [[String: Any]] = [
            [
                "type": "Action.OpenUrl",
                "title": "📥 Download Report",
                "url": azureLink
            ]
        ]
        
        // Create the full payload
        let payload: [String: Any] = [
            "type": "message",
            "attachments": [
                [
                    "contentType": "application/vnd.microsoft.card.adaptive",
                    "content": [
                        "type": "AdaptiveCard",
                        "version": "1.4",
                        "msteams": ["width": "full"],
                        "body": bodyContent,
                        "actions": actions
                    ]
                ]
            ]
        ]
        
        // Send the card
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            guard let url = URL(string: teamsNotifier.webhookURL) else {
                Logger.error("Invalid webhook URL: \(teamsNotifier.webhookURL)", category: .reports)
                return false
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    Logger.info("Scheduled report card sent successfully to Teams!", category: .reports)
                    return true
                } else {
                    Logger.error("Failed to send Teams card. HTTP Status: \(httpResponse.statusCode)", category: .reports)
                    return false
                }
            }
            
            return false
        } catch {
            Logger.error("Error sending scheduled report Teams card: \(error.localizedDescription)", category: .reports)
            return false
        }
    }
    
    /// Disables scheduled reports by name
    /// Used when deleting Azure Storage configurations to prevent continuous failures
    /// - Parameter reportNames: Array of report names to disable
    /// - Returns: True if all reports were successfully disabled
    static func disableReportsByName(_ reportNames: [String]) async -> Bool {
        Logger.info("🔄 Disabling \(reportNames.count) scheduled reports", category: .reports)
        
        let (reports, success) = await getAllScheduledReports()
        guard success else {
            Logger.error("❌ Failed to load scheduled reports for disabling", category: .reports)
            return false
        }
        
        var successCount = 0
        
        for reportName in reportNames {
            if var report = reports.first(where: { $0.name == reportName }) {
                if report.isEnabled {
                    report.isEnabled = false
                    
                    // Save the modified report
                    do {
                        let reportData = try JSONEncoder().encode(report)
                        let fileName = "\(report.id.uuidString).json"
                        
                        // Write directly to the file system (since we're in the privileged service)
                        let scheduledReportsDirectory = AppConstants.intuneomatorScheduledReportsFolderURL
                        let fileURL = scheduledReportsDirectory.appendingPathComponent(fileName)
                        
                        try reportData.write(to: fileURL)
                        successCount += 1
                        Logger.info("✅ Disabled scheduled report: \(reportName)", category: .reports)
                    } catch {
                        Logger.error("❌ Failed to disable scheduled report '\(reportName)': \(error)", category: .reports)
                    }
                } else {
                    // Already disabled, count as success
                    successCount += 1
                    Logger.debug("📝 Scheduled report '\(reportName)' was already disabled", category: .reports)
                }
            } else {
                Logger.warning("⚠️ Scheduled report not found for disabling: \(reportName)", category: .reports)
            }
        }
        
        let allSuccessful = successCount == reportNames.count
        if allSuccessful {
            Logger.info("✅ Successfully disabled \(successCount) scheduled reports", category: .reports)
        } else {
            Logger.error("❌ Only disabled \(successCount) of \(reportNames.count) scheduled reports", category: .reports)
        }
        
        return allSuccessful
    }
}
