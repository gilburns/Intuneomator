//
//  StatusNotificationManager.swift
//  IntuneomatorService
//
//  Created by Gil Burns on 6/14/25.
//

import Foundation

/// Manages status notifications and shared state between daemon and GUI
/// Provides both NSDistributedNotificationCenter notifications and persistent JSON state file
class StatusNotificationManager {
    
    // MARK: - Singleton
    
    static let shared = StatusNotificationManager()
    private init() {
        setupStateFile()
    }
    
    // MARK: - Constants
    
    /// Notification name for distributed notifications
    static let notificationName = "com.intuneomator.status.update"
    
    /// State file location
    private static let stateFileURL = AppConstants.intuneomatorOperationStatusFileURL
    
    // MARK: - Data Structures
    
    /// Current status of an operation
    enum OperationStatus: String, Codable, CaseIterable {
        case idle = "idle"
        case downloading = "downloading"
        case processing = "processing"
        case uploading = "uploading"
        case completed = "completed"
        case error = "error"
        case cancelled = "cancelled"
        
        /// Human-readable description
        var description: String {
            switch self {
            case .idle: return "Ready"
            case .downloading: return "Downloading"
            case .processing: return "Processing"
            case .uploading: return "Uploading to Intune"
            case .completed: return "Completed Successfully"
            case .error: return "Error Occurred"
            case .cancelled: return "Operation Cancelled"
            }
        }
        
        /// Whether this status indicates an operation is active
        var isActive: Bool {
            return [.downloading, .processing, .uploading].contains(self)
        }
    }
    
    /// Phase of the current operation with detailed progress
    struct OperationPhase: Codable {
        let name: String
        let progress: Double  // 0.0 to 1.0
        let detail: String?   // Optional detail message
        
        init(name: String, progress: Double = 0.0, detail: String? = nil) {
            self.name = name
            self.progress = min(max(progress, 0.0), 1.0) // Clamp between 0-1
            self.detail = detail
        }
    }
    
    /// Complete operation progress information
    struct OperationProgress: Codable {
        let operationId: String          // Unique identifier (label_guid)
        let labelName: String            // Human-readable label name
        let appName: String              // Application display name
        let status: OperationStatus      // Current overall status
        let currentPhase: OperationPhase // Current phase details
        let overallProgress: Double      // 0.0 to 1.0 overall completion
        let startTime: Date              // When operation started
        let lastUpdate: Date             // Last status update
        let errorMessage: String?        // Error details if status is error
        let estimatedTimeRemaining: TimeInterval? // Optional ETA in seconds
        
        init(operationId: String, labelName: String, appName: String, status: OperationStatus = .idle) {
            self.operationId = operationId
            self.labelName = labelName
            self.appName = appName
            self.status = status
            self.currentPhase = OperationPhase(name: "Ready", progress: 0.0)
            self.overallProgress = 0.0
            self.startTime = Date()
            self.lastUpdate = Date()
            self.errorMessage = nil
            self.estimatedTimeRemaining = nil
        }
        
        /// Full initializer for creating copies with all properties
        private init(
            operationId: String,
            labelName: String,
            appName: String,
            status: OperationStatus,
            currentPhase: OperationPhase,
            overallProgress: Double,
            startTime: Date,
            lastUpdate: Date,
            errorMessage: String?,
            estimatedTimeRemaining: TimeInterval?
        ) {
            self.operationId = operationId
            self.labelName = labelName
            self.appName = appName
            self.status = status
            self.currentPhase = currentPhase
            self.overallProgress = overallProgress
            self.startTime = startTime
            self.lastUpdate = lastUpdate
            self.errorMessage = errorMessage
            self.estimatedTimeRemaining = estimatedTimeRemaining
        }
        
        /// Creates an updated copy with new values
        func updated(
            status: OperationStatus? = nil,
            currentPhase: OperationPhase? = nil,
            overallProgress: Double? = nil,
            errorMessage: String? = nil,
            estimatedTimeRemaining: TimeInterval? = nil
        ) -> OperationProgress {
            return OperationProgress(
                operationId: self.operationId,
                labelName: self.labelName,
                appName: self.appName,
                status: status ?? self.status,
                currentPhase: currentPhase ?? self.currentPhase,
                overallProgress: overallProgress ?? self.overallProgress,
                startTime: self.startTime,
                lastUpdate: Date(),
                errorMessage: errorMessage ?? self.errorMessage,
                estimatedTimeRemaining: estimatedTimeRemaining ?? self.estimatedTimeRemaining
            )
        }
    }
    
    /// Root state structure for JSON file
    private struct SystemState: Codable {
        var operations: [String: OperationProgress] = [:]
        var lastUpdate: Date = Date()
        var daemonVersion: String = VersionInfo.getVersionString()
    }
    
    // MARK: - Private Properties
    
    private let queue = DispatchQueue(label: "com.intuneomator.status", qos: .utility)
    private var currentState = SystemState()
    private let fileManager = FileManager.default
    
    // MARK: - Public Interface
    
    /// Starts tracking a new operation
    /// - Parameters:
    ///   - operationId: Unique identifier (typically label_guid)
    ///   - labelName: Installomator label name
    ///   - appName: Human-readable application name
    func startOperation(operationId: String, labelName: String, appName: String) {
        queue.async {
            let progress = OperationProgress(
                operationId: operationId,
                labelName: labelName,
                appName: appName,
                status: .idle
            )
            
            self.currentState.operations[operationId] = progress
            self.broadcastUpdate(operationId: operationId)
            
            Logger.info("Started tracking operation: \(operationId) (\(appName))", category: .automation)
        }
    }
    
    /// Updates the status and phase of an operation
    /// - Parameters:
    ///   - operationId: The operation to update
    ///   - status: New operation status
    ///   - phaseName: Name of current phase (e.g., "Downloading", "Extracting ZIP")
    ///   - phaseProgress: Progress within current phase (0.0 to 1.0)
    ///   - phaseDetail: Optional detail message for the phase
    ///   - overallProgress: Overall operation progress (0.0 to 1.0)
    ///   - errorMessage: Error message if status is .error
    ///   - estimatedTimeRemaining: Optional ETA in seconds
    func updateOperation(
        operationId: String,
        status: OperationStatus? = nil,
        phaseName: String? = nil,
        phaseProgress: Double? = nil,
        phaseDetail: String? = nil,
        overallProgress: Double? = nil,
        errorMessage: String? = nil,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        queue.async {
            guard var operation = self.currentState.operations[operationId] else {
                Logger.warning("Attempted to update unknown operation: \(operationId)", category: .automation)
                return
            }
            
            // Update phase if any phase parameters provided
            var newPhase = operation.currentPhase
            if let phaseName = phaseName {
                newPhase = OperationPhase(
                    name: phaseName,
                    progress: phaseProgress ?? newPhase.progress,
                    detail: phaseDetail ?? newPhase.detail
                )
            } else if let phaseProgress = phaseProgress {
                newPhase = OperationPhase(
                    name: newPhase.name,
                    progress: phaseProgress,
                    detail: phaseDetail ?? newPhase.detail
                )
            }
            
            // Create updated operation
            operation = operation.updated(
                status: status,
                currentPhase: newPhase,
                overallProgress: overallProgress,
                errorMessage: errorMessage,
                estimatedTimeRemaining: estimatedTimeRemaining
            )
            
            self.currentState.operations[operationId] = operation
            self.broadcastUpdate(operationId: operationId)
            
            // Log significant status changes
            if let status = status {
                let message = "Operation \(operationId): \(status.description)"
                if status == .error {
                    Logger.error("\(message) - \(errorMessage ?? "Unknown error")", category: .automation)
                } else if status == .completed {
                    Logger.info("\(message)", category: .automation)
                } else {
                    Logger.info("\(message)", category: .automation)
                }
            }
        }
    }
    
    /// Convenience method for updating download progress
    /// - Parameters:
    ///   - operationId: The operation to update
    ///   - downloadedBytes: Bytes downloaded so far
    ///   - totalBytes: Total bytes to download
    ///   - downloadURL: Optional URL being downloaded
    func updateDownloadProgress(operationId: String, downloadedBytes: Int64, totalBytes: Int64, downloadURL: String? = nil) {
        let progress = totalBytes > 0 ? Double(downloadedBytes) / Double(totalBytes) : 0.0
        let detail = downloadURL.map { "Downloading from \(URL(string: $0)?.host ?? $0)" }
        
        updateOperation(
            operationId: operationId,
            status: .downloading,
            phaseName: "Downloading",
            phaseProgress: progress,
            phaseDetail: detail,
            overallProgress: progress * 0.3 // Download is ~30% of total operation
        )
    }
    
    /// Convenience method for updating processing progress
    /// - Parameters:
    ///   - operationId: The operation to update
    ///   - processingStep: Current processing step description
    ///   - stepProgress: Progress within current step (0.0 to 1.0)
    func updateProcessingProgress(operationId: String, processingStep: String, stepProgress: Double = 0.0) {
        updateOperation(
            operationId: operationId,
            status: .processing,
            phaseName: "Processing",
            phaseProgress: stepProgress,
            phaseDetail: processingStep,
            overallProgress: 0.3 + (stepProgress * 0.4) // Processing is ~40% of operation (30-70%)
        )
    }
    
    /// Convenience method for updating upload progress
    /// - Parameters:
    ///   - operationId: The operation to update
    ///   - uploadedBytes: Bytes uploaded so far
    ///   - totalBytes: Total bytes to upload
    func updateUploadProgress(operationId: String, uploadedBytes: Int64, totalBytes: Int64) {
        let progress = totalBytes > 0 ? Double(uploadedBytes) / Double(totalBytes) : 0.0
        
        updateOperation(
            operationId: operationId,
            status: .uploading,
            phaseName: "Uploading to Intune",
            phaseProgress: progress,
            phaseDetail: "Uploading to Microsoft Intune",
            overallProgress: 0.7 + (progress * 0.3) // Upload is ~30% of operation (70-100%)
        )
    }
    
    /// Marks an operation as completed successfully
    /// - Parameter operationId: The operation to complete
    func completeOperation(operationId: String) {
        updateOperation(
            operationId: operationId,
            status: .completed,
            phaseName: "Completed",
            phaseProgress: 1.0,
            phaseDetail: "Operation completed successfully",
            overallProgress: 1.0
        )
        
        // Remove completed operation after a delay to allow GUI to see completion
        queue.asyncAfter(deadline: .now() + 10.0) {
            self.removeOperation(operationId: operationId)
        }
    }
    
    /// Marks an operation as failed with an error
    /// - Parameters:
    ///   - operationId: The operation that failed
    ///   - errorMessage: Description of the error
    func failOperation(operationId: String, errorMessage: String) {
        updateOperation(
            operationId: operationId,
            status: .error,
            phaseName: "Error",
            phaseProgress: 0.0,
            phaseDetail: "Operation failed",
            errorMessage: errorMessage
        )
        
        // Schedule automatic cleanup of this error operation after 10 minutes
        queue.asyncAfter(deadline: .now() + 600.0) {
            self.removeOperation(operationId: operationId)
        }
    }
    
    /// Cancels an operation
    /// - Parameter operationId: The operation to cancel
    func cancelOperation(operationId: String) {
        updateOperation(
            operationId: operationId,
            status: .cancelled,
            phaseName: "Cancelled",
            phaseProgress: 0.0,
            phaseDetail: "Operation was cancelled"
        )
        
        // Remove cancelled operation after a delay
        queue.asyncAfter(deadline: .now() + 5.0) {
            self.removeOperation(operationId: operationId)
        }
    }
    
    /// Removes an operation from tracking
    /// - Parameter operationId: The operation to remove
    func removeOperation(operationId: String) {
        queue.async {
            self.currentState.operations.removeValue(forKey: operationId)
            self.saveStateFile()
            
            // Send notification about removal
            let userInfo: [String: Any] = [
                "operationId": operationId,
                "action": "removed"
            ]
            self.sendNotification(userInfo: userInfo)
            
            Logger.info("Removed operation tracking: \(operationId)", category: .automation)
        }
    }
    
    /// Gets current progress for an operation
    /// - Parameter operationId: The operation to query
    /// - Returns: Current operation progress, or nil if not found
    func getOperationProgress(operationId: String) -> OperationProgress? {
        return queue.sync {
            return currentState.operations[operationId]
        }
    }
    
    /// Gets all currently tracked operations
    /// - Returns: Dictionary of all operations keyed by operationId
    func getAllOperations() -> [String: OperationProgress] {
        return queue.sync {
            return currentState.operations
        }
    }
    
    /// Gets count of active operations
    /// - Returns: Number of operations that are currently active
    func getActiveOperationCount() -> Int {
        return queue.sync {
            return currentState.operations.values.filter { $0.status.isActive }.count
        }
    }
    
    /// Cleans up stale operations based on age and status
    /// - Parameters:
    ///   - maxAge: Maximum age for any operation (default: 1 hour)
    ///   - errorMaxAge: Maximum age for error operations (default: 10 minutes)
    ///   - completedMaxAge: Maximum age for completed operations (default: 30 seconds)
    func cleanupStaleOperations(
        maxAge: TimeInterval = 3600,           // 1 hour for any operation
        errorMaxAge: TimeInterval = 600,       // 10 minutes for errors
        completedMaxAge: TimeInterval = 30     // 30 seconds for completed
    ) {
        queue.async {
            let now = Date()
            let oldOperationsCount = self.currentState.operations.count
            
            self.currentState.operations = self.currentState.operations.filter { _, operation in
                let age = now.timeIntervalSince(operation.lastUpdate)
                
                switch operation.status {
                case .error:
                    // Remove error operations after errorMaxAge
                    return age <= errorMaxAge
                case .completed:
                    // Remove completed operations after completedMaxAge
                    return age <= completedMaxAge
                case .cancelled:
                    // Remove cancelled operations after a short delay
                    return age <= 60 // 1 minute
                default:
                    // Remove any other operations after maxAge
                    return age <= maxAge
                }
            }
            
            let newOperationsCount = self.currentState.operations.count
            let removedCount = oldOperationsCount - newOperationsCount
            
            if removedCount > 0 {
                self.saveStateFile()
                Logger.info("Cleaned up \(removedCount) stale operations (kept \(newOperationsCount))", category: .automation)
                
                // Send notification about cleanup
                let userInfo: [String: Any] = [
                    "action": "cleanup",
                    "removedCount": removedCount,
                    "remainingCount": newOperationsCount
                ]
                self.sendNotification(userInfo: userInfo)
            }
        }
    }
    
    /// Removes all error operations regardless of age
    func clearAllErrorOperations() {
        queue.async {
            let oldCount = self.currentState.operations.count
            let errorOperations = self.currentState.operations.filter { _, operation in
                operation.status == .error
            }
            
            self.currentState.operations = self.currentState.operations.filter { _, operation in
                operation.status != .error
            }
            
            let removedCount = errorOperations.count
            
            if removedCount > 0 {
                self.saveStateFile()
                Logger.info("Cleared \(removedCount) error operations", category: .automation)
                
                // Send notification about cleanup
                let userInfo: [String: Any] = [
                    "action": "clearErrors",
                    "removedCount": removedCount,
                    "remainingCount": self.currentState.operations.count
                ]
                self.sendNotification(userInfo: userInfo)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Sets up the state file and directory
    private func setupStateFile() {
        let stateFileDir = Self.stateFileURL.deletingLastPathComponent()
        
        // Ensure directory exists
        if !fileManager.fileExists(atPath: stateFileDir.path) {
            do {
                try fileManager.createDirectory(
                    at: stateFileDir,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o755]
                )
            } catch {
                Logger.error("Failed to create status directory: \(error)", category: .automation)
            }
        }
        
        // Load existing state if available
        loadStateFile()
        
        Logger.info("StatusNotificationManager initialized", category: .automation)
    }
    
    /// Broadcasts an update via both notification center and state file
    private func broadcastUpdate(operationId: String) {
        guard let operation = currentState.operations[operationId] else { return }
        
        // Update state timestamp
        currentState.lastUpdate = Date()
        
        // Save to file
        saveStateFile()
        
        // Send distributed notification
        var userInfo: [String: Any] = [
            "operationId": operationId,
            "status": operation.status.rawValue,
            "phaseName": operation.currentPhase.name,
            "phaseProgress": operation.currentPhase.progress,
            "overallProgress": operation.overallProgress,
            "appName": operation.appName,
            "labelName": operation.labelName,
            "lastUpdate": operation.lastUpdate.timeIntervalSince1970,
            "action": "updated"
        ]
        
        if let errorMessage = operation.errorMessage {
            userInfo["errorMessage"] = errorMessage
        }
        
        sendNotification(userInfo: userInfo)
    }
    
    /// Sends distributed notification
    private func sendNotification(userInfo: [String: Any]) {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(Self.notificationName),
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }
    
    /// Saves current state to JSON file with file locking
    private func saveStateFile() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let jsonData = try encoder.encode(currentState)
            
            // Write atomically to prevent corruption
            let tempURL = Self.stateFileURL.appendingPathExtension("tmp")
            try jsonData.write(to: tempURL)
            
            // Atomic move
            _ = try fileManager.replaceItem(
                at: Self.stateFileURL,
                withItemAt: tempURL,
                backupItemName: nil,
                options: [],
                resultingItemURL: nil
            )
            
        } catch {
            Logger.error("Failed to save status file: \(error)", category: .automation)
        }
    }
    
    /// Loads state from JSON file
    private func loadStateFile() {
        guard fileManager.fileExists(atPath: Self.stateFileURL.path) else {
            // File doesn't exist yet, start with empty state
            currentState = SystemState()
            return
        }
        
        do {
            let jsonData = try Data(contentsOf: Self.stateFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            currentState = try decoder.decode(SystemState.self, from: jsonData)
            
            Logger.info("Loaded \(currentState.operations.count) operations from state file", category: .automation)
            
            // Clean up stale operations using the new cleanup method
            cleanupStaleOperations()
            
        } catch {
            Logger.error("Failed to load status file, starting fresh: \(error)", category: .automation)
            currentState = SystemState()
        }
    }
}

// MARK: - Extensions for Convenience

extension StatusNotificationManager {
    
    /// Quick status update for common download scenarios
    func updateDownloadStatus(_ operationId: String, _ status: String, progress: Double = 0.0) {
        updateOperation(
            operationId: operationId,
            status: .downloading,
            phaseName: "Downloading",
            phaseProgress: progress,
            phaseDetail: status,
            overallProgress: progress * 0.3
        )
    }
    
    /// Quick status update for common processing scenarios
    func updateProcessingStatus(_ operationId: String, _ status: String, progress: Double = 0.0) {
        updateOperation(
            operationId: operationId,
            status: .processing,
            phaseName: "Processing",
            phaseProgress: progress,
            phaseDetail: status,
            overallProgress: 0.3 + (progress * 0.4)
        )
    }
    
    /// Quick status update for common upload scenarios
    func updateUploadStatus(_ operationId: String, _ status: String, progress: Double = 0.0) {
        updateOperation(
            operationId: operationId,
            status: .uploading,
            phaseName: "Uploading",
            phaseProgress: progress,
            phaseDetail: status,
            overallProgress: 0.7 + (progress * 0.3)
        )
    }
}
