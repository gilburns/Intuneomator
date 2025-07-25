//
//  StatusMonitor.swift
//  Intuneomator
//
//  Monitors status notifications from IntuneomatorService daemon
//  Provides real-time updates on operation progress for GUI display
//

import Foundation
import Combine
import AppKit

/// GUI-side monitor for daemon status notifications
/// Receives updates via NSDistributedNotificationCenter and state file polling
class StatusMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = StatusMonitor()
    
    // MARK: - Published Properties for SwiftUI
    
    @Published var operations: [String: OperationProgress] = [:]
    @Published var activeOperationCount: Int = 0
    @Published var lastUpdate: Date = Date(timeIntervalSince1970: 0)
    @Published var isMonitoring: Bool = false
    
    // MARK: - Private Properties
    
    private var notificationObserver: Any?
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private let queue = DispatchQueue(label: "com.intuneomator.gui.status", qos: .utility)
    
    /// State file location (same as daemon)
    private let stateFileURL = AppConstants.intuneomatorOperationStatusFileURL
    
    // MARK: - Data Structures (Mirror of daemon)
    
    enum OperationStatus: String, Codable, CaseIterable {
        case idle = "idle"
        case downloading = "downloading" 
        case processing = "processing"
        case uploading = "uploading"
        case completed = "completed"
        case error = "error"
        case cancelled = "cancelled"
        
        var description: String {
            switch self {
            case .idle: return "Ready"
            case .downloading: return "Downloading"
            case .processing: return "Processing"
            case .uploading: return "Uploading"
            case .completed: return "Completed Successfully"
            case .error: return "Error Occurred"
            case .cancelled: return "Operation Cancelled"
            }
        }
        
        var isActive: Bool {
            return [.downloading, .processing, .uploading].contains(self)
        }
        
        /// Color for UI display
        var displayColor: NSColor {
            switch self {
            case .idle: return .secondaryLabelColor
            case .downloading: return .systemBlue
            case .processing: return .systemOrange
            case .uploading: return .systemPurple
            case .completed: return .systemGreen
            case .error: return .systemRed
            case .cancelled: return .systemGray
            }
        }
    }
    
    struct OperationPhase: Codable {
        let name: String
        let progress: Double
        let detail: String?
        
        // Custom initializer to handle missing detail field
        init(name: String, progress: Double, detail: String? = nil) {
            self.name = name
            self.progress = progress
            self.detail = detail
        }
        
        // Custom decoder to handle missing detail field
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            name = try container.decode(String.self, forKey: .name)
            progress = try container.decode(Double.self, forKey: .progress)
            detail = try container.decodeIfPresent(String.self, forKey: .detail)
        }
        
        enum CodingKeys: String, CodingKey {
            case name, progress, detail
        }
    }
    
    struct OperationProgress: Codable, Identifiable {
        // Note: id is computed property, not stored, to avoid JSON encoding issues
        var id: String { return operationId }
        
        let operationId: String
        let labelName: String
        let appName: String
        let status: OperationStatus
        let currentPhase: OperationPhase
        let overallProgress: Double
        let startTime: Date
        let lastUpdate: Date
        let errorMessage: String?
        let estimatedTimeRemaining: TimeInterval?
        
        // Regular initializer for creating operations in code
        init(
            operationId: String,
            labelName: String,
            appName: String,
            status: OperationStatus,
            currentPhase: OperationPhase,
            overallProgress: Double,
            startTime: Date,
            lastUpdate: Date,
            errorMessage: String? = nil,
            estimatedTimeRemaining: TimeInterval? = nil
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
        
        // Custom decoder to handle missing optional fields
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            operationId = try container.decode(String.self, forKey: .operationId)
            labelName = try container.decode(String.self, forKey: .labelName)
            appName = try container.decode(String.self, forKey: .appName)
            status = try container.decode(OperationStatus.self, forKey: .status)
            currentPhase = try container.decode(OperationPhase.self, forKey: .currentPhase)
            overallProgress = try container.decode(Double.self, forKey: .overallProgress)
            startTime = try container.decode(Date.self, forKey: .startTime)
            lastUpdate = try container.decode(Date.self, forKey: .lastUpdate)
            
            // Handle optional fields that might be missing
            errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
            estimatedTimeRemaining = try container.decodeIfPresent(TimeInterval.self, forKey: .estimatedTimeRemaining)
        }
        
        enum CodingKeys: String, CodingKey {
            case operationId, labelName, appName, status, currentPhase
            case overallProgress, startTime, lastUpdate, errorMessage, estimatedTimeRemaining
        }
        
        /// Formatted progress percentage
        var progressPercentage: String {
            return "\(Int(overallProgress * 100))%"
        }
        
        /// Formatted time remaining
        var timeRemainingText: String? {
            guard let eta = estimatedTimeRemaining, eta > 0 else { return nil }
            
            if eta < 60 {
                return "\(Int(eta))s remaining"
            } else if eta < 3600 {
                return "\(Int(eta/60))m remaining"
            } else {
                return "\(Int(eta/3600))h \(Int((eta.truncatingRemainder(dividingBy: 3600))/60))m remaining"
            }
        }
        
        /// Time elapsed since start
        var elapsedTime: String {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed < 60 {
                return "\(Int(elapsed))s"
            } else if elapsed < 3600 {
                return "\(Int(elapsed/60))m \(Int(elapsed.truncatingRemainder(dividingBy: 60)))s"
            } else {
                return "\(Int(elapsed/3600))h \(Int((elapsed.truncatingRemainder(dividingBy: 3600))/60))m"
            }
        }
    }
    
    private struct SystemState: Codable {
        var operations: [String: OperationProgress] = [:]
        var lastUpdate: Date = Date()
        var daemonVersion: String = ""
    }
    
    // MARK: - Initialization
    
    private init() {
        Logger.info("StatusMonitor initialized", category: .core, toUserDirectory: true)
    }
    
    // MARK: - Public Interface
    
    /// Starts monitoring for status updates
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        Logger.info("Starting status monitoring with state file path: \(stateFileURL.path)", category: .core, toUserDirectory: true)
        
        // Setup distributed notification observer
        setupNotificationObserver()
        
        // Setup file system watcher
        setupFileWatcher()
        
        // Setup polling timer as fallback
        setupPollingTimer()
        
        // Initial state load
        Logger.info("Loading initial state...", category: .core, toUserDirectory: true)
        loadCurrentState()
        
        Logger.info("Started status monitoring", category: .core, toUserDirectory: true)
    }
    
    /// Stops monitoring for status updates
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        // Clean up notification observer
        if let observer = notificationObserver {
            DistributedNotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        
        // Clean up file watcher
        fileWatcher?.cancel()
        fileWatcher = nil
        
        // Clean up timer
        pollTimer?.invalidate()
        pollTimer = nil
        
        Logger.info("Stopped status monitoring", category: .core, toUserDirectory: true)
    }
    
    /// Gets current operation by ID
    /// - Parameter operationId: The operation to retrieve
    /// - Returns: Operation progress if found
    func getOperation(operationId: String) -> OperationProgress? {
        return operations[operationId]
    }
    
    /// Gets all active operations
    /// - Returns: Array of active operations
    func getActiveOperations() -> [OperationProgress] {
        return operations.values.filter { $0.status.isActive }.sorted { $0.startTime < $1.startTime }
    }
    
    /// Gets all operations (active and completed)
    /// - Returns: Array of all operations
    func getAllOperations() -> [OperationProgress] {
        return Array(operations.values).sorted { $0.lastUpdate > $1.lastUpdate }
    }
    
    /// Manually refreshes state from file
    func refreshState() {
        loadCurrentState()
    }
    
    // MARK: - Private Methods
    
    /// Sets up distributed notification observer
    private func setupNotificationObserver() {
        Logger.info("Setting up distributed notification observer for: com.intuneomator.status.update", category: .core, toUserDirectory: true)
        
        notificationObserver = DistributedNotificationCenter.default.addObserver(
            forName: NSNotification.Name("com.intuneomator.status.update"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Logger.info("Received distributed notification: \(notification.name)", category: .core, toUserDirectory: true)
            self?.handleNotification(notification)
        }
        
        Logger.info("Distributed notification observer setup complete", category: .core, toUserDirectory: true)
    }
    
    /// Sets up file system watcher for state file
    private func setupFileWatcher() {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            // File doesn't exist yet, polling will handle it
            return
        }
        
        let fileDescriptor = open(stateFileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            Logger.warning("Failed to open state file for watching", category: .core, toUserDirectory: true)
            return
        }
        
        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: queue
        )
        
        fileWatcher?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.loadCurrentState()
            }
        }
        
        fileWatcher?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileWatcher?.resume()
    }
    
    /// Sets up polling timer as fallback
    private func setupPollingTimer() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.loadCurrentState()
        }
        Logger.info("Setup polling timer with 1 second interval", category: .core, toUserDirectory: true)
    }
    
    /// Handles incoming distributed notifications
    private func handleNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        // Extract notification data
        guard let operationId = userInfo["operationId"] as? String else { return }
        
        if let action = userInfo["action"] as? String, action == "removed" {
            // Operation was removed
            operations.removeValue(forKey: operationId)
            updatePublishedProperties()
            Logger.info("Received removal notification for operation: \(operationId)", category: .core, toUserDirectory: true)
            return
        }
        
        // Update operation from notification data
        if let existingOperation = operations[operationId] {
            // Update existing operation with notification data
            if let statusString = userInfo["status"] as? String,
               let status = OperationStatus(rawValue: statusString) {
                
                let phaseName = userInfo["phaseName"] as? String ?? existingOperation.currentPhase.name
                let phaseProgress = userInfo["phaseProgress"] as? Double ?? existingOperation.currentPhase.progress
                let overallProgress = userInfo["overallProgress"] as? Double ?? existingOperation.overallProgress
                let errorMessage = userInfo["errorMessage"] as? String
                
                // Create updated operation
                let updatedOperation = OperationProgress(
                    operationId: existingOperation.operationId,
                    labelName: existingOperation.labelName,
                    appName: existingOperation.appName,
                    status: status,
                    currentPhase: OperationPhase(name: phaseName, progress: phaseProgress, detail: existingOperation.currentPhase.detail),
                    overallProgress: overallProgress,
                    startTime: existingOperation.startTime,
                    lastUpdate: Date(),
                    errorMessage: errorMessage,
                    estimatedTimeRemaining: existingOperation.estimatedTimeRemaining
                )
                
                operations[operationId] = updatedOperation
                updatePublishedProperties()
                
                Logger.info("Updated operation from notification: \(operationId) - \(status.description)", category: .core, toUserDirectory: true)
            }
        } else {
            // New operation, load from state file to get complete data
            loadCurrentState()
        }
    }
    
    /// Loads current state from JSON file
    private func loadCurrentState() {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            // File doesn't exist, clear operations
            if !operations.isEmpty {
                operations.removeAll()
                updatePublishedProperties()
            }
            return
        }
        
        do {
            let jsonData = try Data(contentsOf: stateFileURL)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let systemState = try decoder.decode(SystemState.self, from: jsonData)
            
            Logger.debug("Decoded \(systemState.operations.count) operations from state file", category: .core, toUserDirectory: true)
            
            // Update operations if state is newer
            if systemState.lastUpdate > lastUpdate {
                operations = systemState.operations
                updatePublishedProperties()
                
                Logger.debug("Updated GUI with \(operations.count) operations from state file", category: .core, toUserDirectory: true)
            }
            
        } catch {
            Logger.error("Failed to decode status file: \(error)", category: .core, toUserDirectory: true)
        }
    }
    
    /// Updates published properties for SwiftUI
    private func updatePublishedProperties() {
        activeOperationCount = operations.values.filter { $0.status.isActive }.count
        lastUpdate = Date()
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Convenience Extensions

extension StatusMonitor {
    
    /// Gets a user-friendly summary of current operations
    var statusSummary: String {
        let active = getActiveOperations()
        
        if active.isEmpty {
            return "No active operations"
        } else if active.count == 1 {
            let op = active[0]
            return "\(op.appName): \(op.status.description) (\(op.progressPercentage))"
        } else {
            return "\(active.count) operations running"
        }
    }
    
    /// Checks if any operations are currently active
    var hasActiveOperations: Bool {
        return activeOperationCount > 0
    }
    
    /// Gets the most recent operation (active or completed)
    var mostRecentOperation: OperationProgress? {
        return operations.values.max { $0.lastUpdate < $1.lastUpdate }
    }
}

// MARK: - SwiftUI Integration Example

/*
 
 // Example SwiftUI View using StatusMonitor
 
 import SwiftUI
 
 struct OperationStatusView: View {
     @StateObject private var statusMonitor = StatusMonitor.shared
     
     var body: some View {
         VStack(alignment: .leading) {
             HStack {
                 Text("Operations")
                     .font(.headline)
                 Spacer()
                 if statusMonitor.hasActiveOperations {
                     Text("\(statusMonitor.activeOperationCount) running")
                         .foregroundColor(.secondary)
                 }
             }
             
             if statusMonitor.operations.isEmpty {
                 Text("No operations")
                     .foregroundColor(.secondary)
                     .italic()
             } else {
                 ForEach(statusMonitor.getAllOperations()) { operation in
                     OperationRowView(operation: operation)
                 }
             }
         }
         .onAppear {
             statusMonitor.startMonitoring()
         }
         .onDisappear {
             statusMonitor.stopMonitoring()
         }
     }
 }
 
 struct OperationRowView: View {
     let operation: StatusMonitor.OperationProgress
     
     var body: some View {
         VStack(alignment: .leading, spacing: 4) {
             HStack {
                 Text(operation.appName)
                     .font(.subheadline)
                     .fontWeight(.medium)
                 Spacer()
                 Text(operation.progressPercentage)
                     .font(.caption)
                     .foregroundColor(.secondary)
             }
             
             HStack {
                 Circle()
                     .fill(Color(operation.status.displayColor))
                     .frame(width: 8, height: 8)
                 Text(operation.currentPhase.name)
                     .font(.caption)
                     .foregroundColor(.secondary)
                 Spacer()
                 if let timeRemaining = operation.timeRemainingText {
                     Text(timeRemaining)
                         .font(.caption)
                         .foregroundColor(.secondary)
                 }
             }
             
             if operation.status.isActive {
                 ProgressView(value: operation.overallProgress)
                     .progressViewStyle(LinearProgressViewStyle())
             }
             
             if let errorMessage = operation.errorMessage {
                 Text(errorMessage)
                     .font(.caption)
                     .foregroundColor(.red)
             }
         }
         .padding(.vertical, 4)
     }
 }
 
 */
