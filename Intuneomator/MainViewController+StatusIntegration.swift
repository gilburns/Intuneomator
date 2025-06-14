//
//  MainViewController+StatusIntegration.swift
//  Intuneomator
//
//  Integration of StatusMonitor with existing MainViewController
//  Combines real-time progress display with existing status animations
//

import Cocoa
import Combine

/**
 * MainViewController+StatusIntegration
 *
 * This extension integrates the StatusMonitor system with the existing MainViewController
 * to provide comprehensive user feedback for both immediate actions and long-running operations.
 *
 * ## Dual Status System:
 * - **Existing animateStatusUpdate**: Quick feedback for immediate GUI actions (5-second fade)
 * - **New Progress Display**: Persistent progress for long-running daemon operations
 *
 * ## UI Strategy:
 * - Use animateStatusUpdate for: "Label added", "Settings saved", "Upload started"
 * - Use progress display for: Download/process/upload progress with percentages
 * - Seamless handoff: animateStatusUpdate can trigger, then progress takes over
 */
extension MainViewController {
    
    // MARK: - StatusMonitor Integration
    
    var cancellables: Set<AnyCancellable> {
        get {
            // Store cancellables as associated object to avoid modifying main controller
            return objc_getAssociatedObject(self, &AssociatedKeys.cancellables) as? Set<AnyCancellable> ?? Set<AnyCancellable>()
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.cancellables, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    private struct AssociatedKeys {
        static var cancellables = "cancellables"
        static var currentProgressOperation = "currentProgressOperation"
    }
    
    /// Currently displayed progress operation (to avoid conflicts with animateStatusUpdate)
    private var currentProgressOperation: String? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.currentProgressOperation) as? String
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.currentProgressOperation, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    /**
     * Sets up StatusMonitor integration with the main view controller.
     * 
     * Call this from viewDidLoad or viewWillAppear to begin monitoring
     * daemon operations and displaying progress updates.
     * 
     * This method:
     * - Starts the StatusMonitor
     * - Sets up reactive observers for status changes
     * - Configures automatic UI updates for progress display
     */
    func setupStatusMonitoring() {
        StatusMonitor.shared.startMonitoring()
        
        // Observe operations changes
        StatusMonitor.shared.$operations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] operations in
                self?.handleOperationsUpdate(operations)
            }
            .store(in: &cancellables)
        
        // Observe active operation count changes
        StatusMonitor.shared.$activeOperationCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.handleActiveOperationCountChange(count)
            }
            .store(in: &cancellables)
        
        Logger.info("StatusMonitor integration setup complete", category: .core, toUserDirectory: true)
    }
    
    /**
     * Cleans up StatusMonitor integration.
     * 
     * Call this from viewWillDisappear or deinit to stop monitoring
     * and clean up observers.
     */
    func teardownStatusMonitoring() {
        StatusMonitor.shared.stopMonitoring()
        cancellables.removeAll()
        currentProgressOperation = nil
        
        // Hide progress display if showing
        hideProgressDisplay()
    }
    
    // MARK: - Hybrid Status Display Strategy
    
    /**
     * Displays a quick status update with optional progress handoff.
     * 
     * This method enhances the existing animateStatusUpdate by optionally
     * transitioning to persistent progress display for long-running operations.
     * 
     * - Parameter message: Initial status message
     * - Parameter operationId: Optional operation ID to monitor for progress
     * - Parameter showProgress: Whether to show persistent progress after initial message
     * 
     * ## Usage Examples:
     * ```swift
     * // Quick feedback only (existing behavior)
     * animateStatusUpdateWithProgress("Label deleted successfully")
     * 
     * // Quick feedback → persistent progress
     * animateStatusUpdateWithProgress("Starting download...", operationId: "firefox_123", showProgress: true)
     * ```
     */
    func animateStatusUpdateWithProgress(_ message: String, 
                                        operationId: String? = nil, 
                                        showProgress: Bool = false) {
        
        // Always show the initial quick feedback
        animateStatusUpdate(message, visibleDuration: showProgress ? 2.0 : 5.0)
        
        // If progress monitoring requested, transition to progress display
        if showProgress, let operationId = operationId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.showProgressForOperation(operationId)
            }
        }
    }
    
    /**
     * Shows persistent progress display for a specific operation.
     * 
     * Replaces the fade-out status message with a persistent progress indicator
     * that updates in real-time as the operation progresses.
     * 
     * - Parameter operationId: The operation to display progress for
     */
    func showProgressForOperation(_ operationId: String) {
        guard let operation = StatusMonitor.shared.getOperation(operationId: operationId) else {
            return
        }
        
        // Track current operation to avoid conflicts
        currentProgressOperation = operationId
        
        // Configure progress display
        updateProgressDisplay(for: operation)
        
        // Start showing progress
        showProgressDisplay()
    }
    
    /**
     * Handles updates to the operations dictionary from StatusMonitor.
     * 
     * This method processes changes in operation status and updates the UI
     * accordingly, managing the transition between different display modes.
     */
    private func handleOperationsUpdate(_ operations: [String: StatusMonitor.OperationProgress]) {
        // Update current progress operation if it's being tracked
        if let currentOpId = currentProgressOperation,
           let currentOp = operations[currentOpId] {
            
            updateProgressDisplay(for: currentOp)
            
            // Handle operation completion/failure
            if !currentOp.status.isActive {
                handleOperationCompletion(currentOp)
            }
        } else if currentProgressOperation != nil {
            // Current operation was removed, hide progress
            hideProgressDisplay()
        }
        
        // Check for new operations that might need automatic progress display
        checkForNewOperations(operations)
    }
    
    /**
     * Handles changes in active operation count.
     * 
     * Updates UI elements that reflect overall system activity,
     * such as menu bar indicators or status bar items.
     */
    private func handleActiveOperationCountChange(_ count: Int) {
        // Update any global activity indicators
        // For example, you could update the window title or add a spinner
        if count > 0 {
            // Show global activity indicator
            Logger.info("Active operations: \(count)", category: .core, toUserDirectory: true)
        } else {
            // Hide global activity indicator
            currentProgressOperation = nil
            hideProgressDisplay()
        }
    }
    
    /**
     * Handles completion of the currently displayed operation.
     * 
     * Shows appropriate completion message and manages the transition
     * back to normal status display.
     */
    private func handleOperationCompletion(_ operation: StatusMonitor.OperationProgress) {
        let completionMessage: String
        
        switch operation.status {
        case .completed:
            completionMessage = "\(operation.appName) uploaded successfully"
        case .error:
            completionMessage = "\(operation.appName) failed: \(operation.errorMessage ?? "Unknown error")"
        case .cancelled:
            completionMessage = "\(operation.appName) was cancelled"
        default:
            completionMessage = "\(operation.appName) finished"
        }
        
        // Hide progress and show completion message
        hideProgressDisplay()
        animateStatusUpdate(completionMessage)
        
        currentProgressOperation = nil
    }
    
    /**
     * Checks for new operations that should automatically show progress.
     * 
     * This method can automatically start showing progress for operations
     * that begin while the GUI is running, providing seamless feedback.
     */
    private func checkForNewOperations(_ operations: [String: StatusMonitor.OperationProgress]) {
        // Only auto-show progress if no operation is currently being displayed
        guard currentProgressOperation == nil else { return }
        
        // Find the most recent active operation
        let activeOps = operations.values.filter { $0.status.isActive }
        guard let newestOp = activeOps.max(by: { $0.startTime < $1.startTime }) else { return }
        
        // Auto-show progress for operations that are already past the initial phase
        if newestOp.overallProgress > 0.05 { // 5% threshold to avoid flicker
            showProgressForOperation(newestOp.operationId)
        }
    }
    
    // MARK: - Progress Display UI Management
    
    /**
     * Shows the persistent progress display.
     * 
     * This method assumes you have UI elements for progress display.
     * Adapt these method calls to match your actual UI structure.
     */
    private func showProgressDisplay() {
        // Hide the normal status update label to avoid conflicts
        statusUpdateLabel.isHidden = true
        
        // Show progress-specific UI elements
        // Note: You'll need to add these UI elements to your storyboard/xib
        // progressBar?.isHidden = false
        // progressLabel?.isHidden = false
        // progressDetailLabel?.isHidden = false
        
        Logger.debug("Showing persistent progress display", category: .core, toUserDirectory: true)
    }
    
    /**
     * Hides the persistent progress display.
     * 
     * Returns the UI to normal status display mode.
     */
    private func hideProgressDisplay() {
        // Hide progress-specific UI elements
        // progressBar?.isHidden = true
        // progressLabel?.isHidden = true
        // progressDetailLabel?.isHidden = true
        
        Logger.debug("Hiding persistent progress display", category: .core, toUserDirectory: true)
    }
    
    /**
     * Updates the progress display with current operation data.
     * 
     * This method updates all progress-related UI elements with the
     * latest information from the operation status.
     */
    private func updateProgressDisplay(for operation: StatusMonitor.OperationProgress) {
        // Update progress bar
        // progressBar?.doubleValue = operation.overallProgress * 100
        
        // Update main progress label
        // progressLabel?.stringValue = "\(operation.appName): \(operation.status.description)"
        
        // Update detail label with phase information
        var detailText = operation.currentPhase.name
        if let phaseDetail = operation.currentPhase.detail {
            detailText += " - \(phaseDetail)"
        }
        if let timeRemaining = operation.timeRemainingText {
            detailText += " (\(timeRemaining))"
        }
        
        // progressDetailLabel?.stringValue = detailText
        
        Logger.debug("Updated progress display: \(operation.appName) - \(operation.progressPercentage)", category: .core, toUserDirectory: true)
    }
    
    // MARK: - Convenience Methods for Common Scenarios
    
    /**
     * Shows status update when starting an automation operation.
     * 
     * Provides immediate feedback and transitions to progress monitoring.
     */
    func showOperationStarted(appName: String, operationId: String) {
        animateStatusUpdateWithProgress(
            "Starting automation for \(appName)...",
            operationId: operationId,
            showProgress: true
        )
    }
    
    /**
     * Shows quick status update for immediate actions (no progress monitoring).
     * 
     * Uses existing animateStatusUpdate for quick feedback.
     */
    func showQuickStatus(_ message: String) {
        animateStatusUpdate(message)
    }
    
    /**
     * Shows status update for manual user actions.
     * 
     * Optimized for immediate GUI feedback (add/remove/edit operations).
     */
    func showUserActionStatus(_ message: String) {
        animateStatusUpdate(message, visibleDuration: 3.0)
    }
}

// MARK: - Usage Examples and Integration Points

/*
 
 ## Integration Examples:
 
 ### 1. In your existing XPC completion handlers:
 
 ```swift
 // Before (existing code):
 animateStatusUpdate("Label added successfully")
 
 // After (enhanced):
 showUserActionStatus("Label added successfully")
 ```
 
 ### 2. When starting automation:
 
 ```swift
 // New usage for long operations:
 let operationId = "\(labelName)_\(guid)"
 showOperationStarted(appName: appDisplayName, operationId: operationId)
 ```
 
 ### 3. In viewDidLoad/viewWillAppear:
 
 ```swift
 override func viewDidLoad() {
     super.viewDidLoad()
     // ... existing setup ...
     setupStatusMonitoring()
 }
 
 override func viewWillDisappear() {
     super.viewWillDisappear()
     teardownStatusMonitoring()
 }
 ```
 
 ### 4. Manual progress monitoring:
 
 ```swift
 @IBAction func showProgressForSelectedItem(_ sender: Any) {
     if let selectedItem = getSelectedItem(),
        let operation = StatusMonitor.shared.getOperation(operationId: selectedItem.operationId) {
         showProgressForOperation(selectedItem.operationId)
     }
 }
 ```
 
 ## UI Elements to Add:
 
 Add these outlets to your MainViewController for progress display:
 
 ```swift
 @IBOutlet weak var progressBar: NSProgressIndicator!
 @IBOutlet weak var progressLabel: NSTextField!
 @IBOutlet weak var progressDetailLabel: NSTextField!
 ```
 
 Position them near your existing statusUpdateLabel for seamless transitions.
 
 */
