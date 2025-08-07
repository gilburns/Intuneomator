//
//  ScheduledReportsManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/25/25.
//

import Foundation

/// Notification names for scheduled reports
extension NSNotification.Name {
    static let scheduledReportsChanged = NSNotification.Name("scheduledReportsChanged")
}

/// Manager class for handling scheduled report operations
/// Provides CRUD operations and validation for scheduled reports
class ScheduledReportsManager {
    
    // MARK: - Singleton
    static let shared = ScheduledReportsManager()
    private init() {}
    
    // MARK: - Properties
    
    /// Directory where scheduled reports are stored
    private var scheduledReportsDirectory: URL {
        return AppConstants.intuneomatorScheduledReportsFolderURL
    }
    
    /// Index file containing list of all scheduled reports
    private var indexFileURL: URL {
        return scheduledReportsDirectory.appendingPathComponent("index.json")
    }
    
    // MARK: - Public Methods
    
    /// Gets all scheduled reports
    /// - Returns: Array of scheduled reports, sorted by name
    func getAllScheduledReports() -> [ScheduledReport] {
        
        do {
            let reportFiles = try FileManager.default.contentsOfDirectory(at: scheduledReportsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" && $0.lastPathComponent != "index.json" }
            
            var reports: [ScheduledReport] = []
            
            for fileURL in reportFiles {
                if var report = loadScheduledReport(from: fileURL) {
                    // Update next run time if it's nil or outdated (in memory only)
                    if report.nextRun == nil || (report.nextRun != nil && report.nextRun! < Date()) {
                        report.nextRun = report.schedule.calculateNextRun(from: Date())
                        // Note: Not saving here to avoid blocking/deadlock - will be saved on next edit
                    }
                    reports.append(report)
                }
            }
            
            return reports.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        } catch {
            Logger.error("Failed to load scheduled reports: \(error)", category: .core, toUserDirectory: true)
            return []
        }
    }
    
    /// Gets a specific scheduled report by ID
    /// - Parameter id: The report ID
    /// - Returns: The scheduled report if found
    func getScheduledReport(withId id: UUID) -> ScheduledReport? {
        let fileURL = scheduledReportsDirectory.appendingPathComponent("\(id.uuidString).json")
        return loadScheduledReport(from: fileURL)
    }
    
    /// Saves a scheduled report via XPC service (required for root-owned directory)
    /// - Parameters:
    ///   - report: The report to save
    ///   - completion: Callback with success status
    func saveScheduledReport(_ report: ScheduledReport, completion: @escaping (Bool) -> Void) {
        var updatedReport = report
        updatedReport.markAsModified()
        
        do {
            let data = try JSONEncoder().encode(updatedReport)
            
            XPCManager.shared.saveScheduledReportConfiguration(reportData: data, fileName: updatedReport.fileName) { [weak self] success in
                DispatchQueue.main.async {
                    if let success = success, success {
                        // Add a small delay to prevent race conditions with concurrent file operations
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self?.updateIndexViaXPC()
                        }
                        Logger.info("Saved scheduled report: \(updatedReport.name)", category: .core, toUserDirectory: true)
                        completion(true)
                    } else {
                        Logger.error("Failed to save scheduled report '\(updatedReport.name)' via XPC", category: .core, toUserDirectory: true)
                        completion(false)
                    }
                }
            }
            
        } catch {
            Logger.error("Failed to encode scheduled report '\(updatedReport.name)': \(error)", category: .core, toUserDirectory: true)
            completion(false)
        }
    }
    
    /// Saves a scheduled report synchronously (legacy compatibility method)
    /// - Parameter report: The report to save
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func saveScheduledReport(_ report: ScheduledReport) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        
        saveScheduledReport(report) { success in
            result = success
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    /// Deletes a scheduled report via XPC service (required for root-owned directory)
    /// - Parameters:
    ///   - id: The ID of the report to delete
    ///   - completion: Callback with success status
    func deleteScheduledReport(withId id: UUID, completion: @escaping (Bool) -> Void) {
        let fileName = "\(id.uuidString).json"
        
        XPCManager.shared.deleteScheduledReportConfiguration(fileName: fileName) { [weak self] success in
            DispatchQueue.main.async {
                if let success = success, success {
                    self?.updateIndexViaXPC()
                    Logger.info("Deleted scheduled report with ID: \(id)", category: .core, toUserDirectory: true)
                    completion(true)
                } else {
                    Logger.error("Failed to delete scheduled report \(id) via XPC", category: .core, toUserDirectory: true)
                    completion(false)
                }
            }
        }
    }
    
    /// Deletes a scheduled report synchronously (legacy compatibility method)
    /// - Parameter id: The ID of the report to delete
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func deleteScheduledReport(withId id: UUID) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        
        deleteScheduledReport(withId: id) { success in
            result = success
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    /// Validates a scheduled report configuration
    /// - Parameter report: The report to validate
    /// - Returns: Validation error message, or nil if valid
    func validateScheduledReport(_ report: ScheduledReport) -> String? {
        // Validate name
        if report.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Schedule name is required"
        }
        
        if report.name.count > 100 {
            return "Schedule name cannot exceed 100 characters"
        }
        
        // Check for duplicate names (excluding the same report if editing)
        let existingReports = getAllScheduledReports()
        if existingReports.contains(where: { $0.name == report.name && $0.id != report.id }) {
            return "A schedule with this name already exists"
        }
        
        // Validate report type
        if report.reportType.isEmpty {
            return "Report type is required"
        }
        
        // Validate format
        if !["csv", "json"].contains(report.format.lowercased()) {
            return "Format must be CSV or JSON"
        }
        
        // Validate schedule configuration
        if let scheduleError = validateScheduleConfiguration(report.schedule) {
            return scheduleError
        }
        
        // Validate delivery configuration
        if let deliveryError = validateDeliveryConfiguration(report.delivery) {
            return deliveryError
        }
        
        // Validate notification configuration
        if let notificationError = validateNotificationConfiguration(report.notifications) {
            return notificationError
        }
        
        return nil
    }
    
    /// Gets scheduled reports that are due to run
    /// - Parameter asOf: The date to check against (defaults to now)
    /// - Returns: Array of reports that should run
    func getReportsDueToRun(asOf date: Date = Date()) -> [ScheduledReport] {
        return getAllScheduledReports().filter { report in
            guard report.isEnabled else { return false }
            
            // Check if we're within the valid date range
            if date < report.schedule.startDate {
                return false
            }
            
            if let endDate = report.schedule.endDate, date > endDate {
                return false
            }
            
            // Check if it's time to run
            guard let nextRun = report.nextRun else { return false }
            return date >= nextRun
        }
    }
    
    /// Updates the next run time for a scheduled report
    /// - Parameters:
    ///   - id: The report ID
    ///   - result: The run result to record
    /// - Returns: True if successful
    @discardableResult
    func updateRunResult(for id: UUID, result: RunResult) -> Bool {
        guard var report = getScheduledReport(withId: id) else { return false }
        
        report.updateRunResult(result)
        return saveScheduledReport(report)
    }
    
    /// Disables scheduled reports by name
    /// Used when deleting Azure Storage configurations to prevent continuous failures
    /// - Parameter reportNames: Array of report names to disable
    /// - Returns: True if all reports were successfully disabled
    @discardableResult
    func disableReportsByName(_ reportNames: [String]) -> Bool {
        let reports = getAllScheduledReports()
        var successCount = 0
        
        for reportName in reportNames {
            if var report = reports.first(where: { $0.name == reportName }) {
                if report.isEnabled {
                    report.isEnabled = false
                    if saveScheduledReport(report) {
                        successCount += 1
                        Logger.info("Disabled scheduled report: \(reportName)", category: .core, toUserDirectory: true)
                    } else {
                        Logger.error("Failed to disable scheduled report: \(reportName)", category: .core, toUserDirectory: true)
                    }
                } else {
                    // Already disabled, count as success
                    successCount += 1
                    Logger.debug("Scheduled report '\(reportName)' was already disabled", category: .core, toUserDirectory: true)
                }
            } else {
                Logger.warning("Scheduled report not found for disabling: \(reportName)", category: .core, toUserDirectory: true)
            }
        }
        
        let allSuccessful = successCount == reportNames.count
        if allSuccessful {
            Logger.info("Successfully disabled \(successCount) scheduled reports", category: .core, toUserDirectory: true)
        } else {
            Logger.error("Only disabled \(successCount) of \(reportNames.count) scheduled reports", category: .core, toUserDirectory: true)
        }
        
        return allSuccessful
    }
    
    /// Gets a summary of scheduled report statistics
    /// - Returns: Dictionary with various statistics
    func getStatistics() -> [String: Any] {
        let reports = getAllScheduledReports()
        let enabled = reports.filter { $0.isEnabled }
        let disabled = reports.filter { !$0.isEnabled }
        
        let dailyReports = enabled.filter { $0.schedule.frequency == .daily }
        let weeklyReports = enabled.filter { $0.schedule.frequency == .weekly }
        let monthlyReports = enabled.filter { $0.schedule.frequency == .monthly }
        
        let recentlyRun = reports.filter { report in
            guard let lastRun = report.lastRun else { return false }
            return Date().timeIntervalSince(lastRun) < 86400 // 24 hours
        }
        
        return [
            "totalReports": reports.count,
            "enabledReports": enabled.count,
            "disabledReports": disabled.count,
            "dailyReports": dailyReports.count,
            "weeklyReports": weeklyReports.count,
            "monthlyReports": monthlyReports.count,
            "recentlyRun": recentlyRun.count
        ]
    }
    
    // MARK: - Private Methods
    
    /// Cleans up orphaned report files that aren't in the index
    /// Call this if there are discrepancies between files and index
    func cleanupOrphanedFiles() {
        do {
            let reportFiles = try FileManager.default.contentsOfDirectory(at: scheduledReportsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" && $0.lastPathComponent != "index.json" }
            
            // Get the valid file names from the index, not from loading files
            let indexValidFileNames = getIndexedReportFileNames()
            
            // SAFETY CHECK: If index is corrupted (empty result), skip cleanup to prevent data loss
            if indexValidFileNames.isEmpty && !reportFiles.isEmpty {
                Logger.error("Index appears corrupted (empty) but report files exist. Attempting to rebuild index from existing files.", category: .core, toUserDirectory: true)
                rebuildIndexFromFiles()
                return
            }
            
            let indexValidFileNamesSet = Set(indexValidFileNames)
            
            for fileURL in reportFiles {
                let fileName = fileURL.lastPathComponent
                if !indexValidFileNamesSet.contains(fileName) {
                    // Check file creation time to avoid deleting recently saved files
                    // Add a 5-second grace period for files that might have just been saved
                    do {
                        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                        if let creationDate = fileAttributes[.creationDate] as? Date {
                            let fileAge = Date().timeIntervalSince(creationDate)
                            if fileAge < 5.0 {
                                Logger.info("Skipping recent file during orphan cleanup: \(fileName) (created \(String(format: "%.1f", fileAge))s ago)", category: .core, toUserDirectory: true)
                                continue
                            }
                        }
                    } catch {
                        Logger.warning("Could not get creation date for \(fileName), treating as orphaned: \(error)", category: .core, toUserDirectory: true)
                    }
                    
                    Logger.warning("Found orphaned report file: \(fileName), requesting deletion via XPC", category: .core, toUserDirectory: true)
                    
                    // Delete orphaned file via XPC
                    XPCManager.shared.deleteScheduledReportConfiguration(fileName: fileName) { success in
                        if let success = success, success {
                            Logger.info("Cleaned up orphaned file: \(fileName)", category: .core, toUserDirectory: true)
                        } else {
                            Logger.error("Failed to clean up orphaned file: \(fileName)", category: .core, toUserDirectory: true)
                        }
                    }
                }
            }
            
        } catch {
            Logger.error("Failed to check for orphaned files: \(error)", category: .core, toUserDirectory: true)
        }
    }
    
    /// Rebuilds the index.json file from existing report files when corruption is detected
    /// This is an emergency recovery mechanism to restore functionality after index corruption
    private func rebuildIndexFromFiles() {
        Logger.info("Starting index rebuild from existing report files...", category: .core, toUserDirectory: true)
        
        do {
            let reportFiles = try FileManager.default.contentsOfDirectory(at: scheduledReportsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" && $0.lastPathComponent != "index.json" }
            
            var validReports: [ScheduledReport] = []
            var failedFiles: [String] = []
            
            // Load each report file and collect valid ones
            for fileURL in reportFiles {
                if let report = loadScheduledReport(from: fileURL) {
                    validReports.append(report)
                    Logger.debug("Recovered report: \(report.name) (\(report.id))", category: .core, toUserDirectory: true)
                } else {
                    failedFiles.append(fileURL.lastPathComponent)
                }
            }
            
            // Log recovery results
            Logger.info("Index rebuild: recovered \(validReports.count) valid reports, \(failedFiles.count) failed", category: .core, toUserDirectory: true)
            if !failedFiles.isEmpty {
                Logger.warning("Failed to recover these files (may be corrupted): \(failedFiles.joined(separator: ", "))", category: .core, toUserDirectory: true)
            }
            
            // Rebuild the index
            let index = ScheduledReportIndex(
                reports: validReports.map { ScheduledReportIndexEntry(from: $0) },
                lastUpdated: Date()
            )
            
            // Save the rebuilt index via XPC
            let indexData = try JSONEncoder().encode(index)
            XPCManager.shared.updateScheduledReportsIndex(indexData: indexData) { [weak self] success in
                if let success = success, success {
                    Logger.info("Successfully rebuilt index.json with \(validReports.count) reports", category: .core, toUserDirectory: true)
                    
                    // Trigger a refresh of the UI to show recovered reports
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .scheduledReportsChanged, object: nil)
                    }
                } else {
                    Logger.error("Failed to save rebuilt index via XPC", category: .core, toUserDirectory: true)
                }
            }
            
        } catch {
            Logger.error("Failed to rebuild index from files: \(error)", category: .core, toUserDirectory: true)
        }
    }
    
    /// Manually triggers index rebuild from existing files
    /// This can be called from UI when user suspects index corruption
    func rebuildIndex() {
        rebuildIndexFromFiles()
    }
    
    /// Checks for index corruption and attempts recovery on app startup
    /// Should be called when the view controller loads
    func validateAndRecoverIndex() {
        do {
            let reportFiles = try FileManager.default.contentsOfDirectory(at: scheduledReportsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" && $0.lastPathComponent != "index.json" }
            
            let indexValidFileNames = getIndexedReportFileNames()
            
            // Check for corruption: index empty but files exist
            if indexValidFileNames.isEmpty && !reportFiles.isEmpty {
                Logger.warning("Detected corrupted index on startup. Attempting automatic recovery.", category: .core, toUserDirectory: true)
                rebuildIndexFromFiles()
            }
        } catch {
            Logger.error("Failed to validate index on startup: \(error)", category: .core, toUserDirectory: true)
        }
    }
    
    /// Checks if the scheduled reports index file exists
    /// - Returns: True if index exists, false otherwise
    func indexExists() -> Bool {
        return FileManager.default.fileExists(atPath: indexFileURL.path)
    }
    
    /// Gets the list of file names that should exist according to the index
    /// - Returns: Array of file names from the index
    private func getIndexedReportFileNames() -> [String] {
        do {
            let data = try Data(contentsOf: indexFileURL)
            let index = try JSONDecoder().decode(ScheduledReportIndex.self, from: data)
            return index.reports.map { "\($0.id.uuidString).json" }
        } catch {
            Logger.error("Failed to load index for orphan cleanup: \(error)", category: .core, toUserDirectory: true)
            // Return empty array - caller should check if this is safe to use
            return []
        }
    }
    
    /// Loads a scheduled report from a file
    /// - Parameter fileURL: The file URL to load from
    /// - Returns: The loaded report, or nil if failed
    private func loadScheduledReport(from fileURL: URL) -> ScheduledReport? {
        do {
            let data = try Data(contentsOf: fileURL)
            let report = try JSONDecoder().decode(ScheduledReport.self, from: data)
            return report
        } catch {
            Logger.error("Failed to load scheduled report from \(fileURL.lastPathComponent): \(error)", category: .core, toUserDirectory: true)
            return nil
        }
    }
    
    /// Updates the index file via XPC service (required for root-owned directory)
    private func updateIndexViaXPC() {
        let reports = getAllScheduledReports()
        let index = ScheduledReportIndex(
            reports: reports.map { ScheduledReportIndexEntry(from: $0) },
            lastUpdated: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(index)
            XPCManager.shared.updateScheduledReportsIndex(indexData: data) { success in
                if let success = success, !success {
                    Logger.error("Failed to update scheduled reports index via XPC", category: .core, toUserDirectory: true)
                }
            }
        } catch {
            Logger.error("Failed to encode scheduled reports index: \(error)", category: .core, toUserDirectory: true)
        }
    }
    
    /// Updates the index file with current report list (legacy compatibility method)
    private func updateIndex() {
        updateIndexViaXPC()
    }
    
    /// Validates schedule configuration
    /// - Parameter schedule: The schedule to validate
    /// - Returns: Error message or nil if valid
    private func validateScheduleConfiguration(_ schedule: ScheduleConfiguration) -> String? {
        // Validate time format
        let timeParts = schedule.timeOfDay.split(separator: ":")
        guard timeParts.count == 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]),
              hour >= 0 && hour <= 23,
              minute >= 0 && minute <= 59 else {
            return "Time must be in HH:MM format (24-hour)"
        }
        
        // Validate frequency-specific requirements
        switch schedule.frequency {
        case .weekly:
            if let dayOfWeek = schedule.dayOfWeek {
                guard dayOfWeek >= 1 && dayOfWeek <= 7 else {
                    return "Day of week must be between 1 (Sunday) and 7 (Saturday)"
                }
            } else {
                return "Day of week is required for weekly schedules"
            }
            
        case .monthly:
            if let dayOfMonth = schedule.dayOfMonth {
                guard dayOfMonth >= 1 && dayOfMonth <= 31 else {
                    return "Day of month must be between 1 and 31"
                }
            } else {
                return "Day of month is required for monthly schedules"
            }
            
        case .daily:
            break // No additional validation needed
        }
        
        // Validate date range
        if let endDate = schedule.endDate, endDate <= schedule.startDate {
            return "End date must be after start date"
        }
        
        return nil
    }
    
    /// Validates delivery configuration
    /// - Parameter delivery: The delivery config to validate
    /// - Returns: Error message or nil if valid
    private func validateDeliveryConfiguration(_ delivery: DeliveryConfiguration) -> String? {
        if delivery.azureStorageConfigName.isEmpty {
            return "Azure Storage configuration is required"
        }
        
        // TODO: Validate that the Azure Storage configuration exists
        // This validation will need to be done asynchronously through XPC
        // For now, we'll skip this validation as it requires async handling
        
        if delivery.folderPath.isEmpty {
            return "Folder path is required"
        }
        
        if delivery.fileNameTemplate.isEmpty {
            return "File name template is required"
        }
        
        // Validate file name template contains required placeholders
        if !delivery.fileNameTemplate.contains("{extension}") {
            return "File name template must include {extension} placeholder"
        }
        
        // Validate link expiration if enabled
        if delivery.createShareableLink {
            if let expDays = delivery.linkExpirationDays {
                guard expDays > 0 && expDays <= 365 else {
                    return "Link expiration must be between 1 and 365 days"
                }
            }
        }
        
        return nil
    }
    
    /// Validates notification configuration
    /// - Parameter notifications: The notification config to validate
    /// - Returns: Error message or nil if valid
    private func validateNotificationConfiguration(_ notifications: NotificationConfiguration) -> String? {
        if notifications.enabled && !notifications.useGlobalWebhook {
            if let customURL = notifications.customWebhookURL {
                if customURL.isEmpty {
                    return "Custom webhook URL is required when not using global webhook"
                }
                
                if !customURL.hasPrefix("https://") {
                    return "Webhook URL must use HTTPS"
                }
                
                // Basic webhook domain validation
                let validDomains = [
                    "webhook.office.com",
                    "logic.azure.com", 
                    "outlook.office.com",
                    "teams.microsoft.com"
                ]
                
                let hasValidDomain = validDomains.contains { domain in
                    customURL.contains(domain)
                }
                
                if !hasValidDomain {
                    return "Invalid webhook URL domain"
                }
            } else {
                return "Custom webhook URL is required when not using global webhook"
            }
        }
        
        return nil
    }
}

// MARK: - Index Data Structures

/// Index file structure for quick loading of scheduled report metadata
private struct ScheduledReportIndex: Codable {
    let reports: [ScheduledReportIndexEntry]
    let lastUpdated: Date
}

/// Lightweight representation of a scheduled report for index file
private struct ScheduledReportIndexEntry: Codable {
    let id: UUID
    let name: String
    let reportType: String
    let isEnabled: Bool
    let nextRun: Date?
    let lastRun: Date?
    
    init(from report: ScheduledReport) {
        self.id = report.id
        self.name = report.name
        self.reportType = report.reportType
        self.isEnabled = report.isEnabled
        self.nextRun = report.nextRun
        self.lastRun = report.lastRun
    }
}
