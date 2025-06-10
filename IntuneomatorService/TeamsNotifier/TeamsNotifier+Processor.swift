//
//  TeamsNotifier+Processor.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

import Foundation

/// Extension for TeamsNotifier that provides high-level notification processing and orchestration.
/// This module serves as the main entry point for Teams notifications, handling configuration
/// validation, message routing, and the overall notification workflow. Acts as a facade that
/// simplifies notification sending by managing all the underlying complexity of Teams integration.
extension TeamsNotifier {
                
    /// Processes and sends Teams notifications for application deployment results.
    /// 
    /// This is the primary entry point for Teams notifications, providing a unified interface
    /// for sending both success and failure notifications. Handles all configuration validation,
    /// metadata preparation, and message routing to the appropriate notification methods.
    /// 
    /// - Parameters:
    ///   - processedAppResults: Complete application processing results containing metadata
    ///   - success: Boolean indicating whether the deployment succeeded or failed
    ///   - errorMessage: Optional error message for failure notifications
    /// - Returns: `true` if notification was sent successfully, `false` if disabled or failed
    /// 
    /// **Configuration Requirements:**
    /// - `TeamsNotificationsEnabled` must be true
    /// - `TeamsNotificationsStyle` must be 0 (individual notifications)
    /// - `TeamsWebhookURL` must be configured and non-empty
    /// 
    /// **Process Flow:**
    /// 1. Validates Teams notification configuration settings
    /// 2. Extracts and formats application metadata (size, time, icon)
    /// 3. Routes to success or failure notification based on result
    /// 4. Returns status indicating notification delivery
    /// 
    /// **Metadata Handling:**
    /// - Dynamically generates icon URLs based on app label name
    /// - Calculates file sizes using ByteCountFormatter
    /// - Formats timestamps with consistent date/time styling
    /// - Preserves group assignment and deployment information
    /// 
    /// **Use Cases:**
    /// - Automated deployment result notifications
    /// - Manual deployment status reporting
    /// - Integration testing and validation
    static func processNotification(for processedAppResults: ProcessedAppResults, success: Bool, errorMessage: String? = "") async -> Bool {
        
        // Validate Teams notifications are enabled in configuration
        guard ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") == true
        else {
          return false
        }

        // Check if individual notifications are enabled (style 0)
        guard ConfigManager.readPlistValue(key: "TeamsNotificationsStyle") == 0
        else {
          return false
        }

        // Ensure Teams webhook URL is configured
        guard let urlString: String = ConfigManager.readPlistValue(key: "TeamsWebhookURL"),
              !urlString.isEmpty
        else {
          return false
        }
        
        // Prepare notification metadata and formatting
        let iconImageURL = "https://icons.intuneomator.org/\(processedAppResults.appLabelName).png"
        let appURLString: String = processedAppResults.appLocalURL
        
        // Calculate and format file size for display
        let bytes = (try? FileManager.default.attributesOfItem(atPath: appURLString)[.size] as? Int64) ?? 0
        let size = "⚖️ \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"
        
        // Format current timestamp for notification
        let time = "🕰️ \(TeamsNotifier.dateFormatter.string(from: Date()))"
        
        let assignedGroups = processedAppResults.appAssignments
        
        let uploadSucceeded = success

        // Initialize Teams notifier with webhook URL
        let teamsNotifier = TeamsNotifier(webhookURL: urlString)

        // Route to appropriate notification type based on success status
        if uploadSucceeded {
            // Send success notification with complete metadata
            await teamsNotifier.sendSuccessNotification(
                title: processedAppResults.appDisplayName,
                version: "⦿ \(processedAppResults.appVersionActual)",
                size: size,
                time: time,
                imageURL: iconImageURL,
                deploymentType: processedAppResults.deploymentTypeEmoji,
                architecture: processedAppResults.architectureEmoji,
                releaseNotesURL: nil,
                assignedGroups: assignedGroups
            )
            return true

        } else {
            // Prepare error message with fallback for empty messages
            var teamsMessage: String = ""
            if errorMessage?.isEmpty ?? true {
                teamsMessage = "Failed to upload to Intune. The automation will try again the next time it runs. If this error persists, please review the logs for more information."
            } else {
                teamsMessage = errorMessage ?? "No error message provided."
            }
            
            // Send failure notification with error details
            teamsNotifier.sendErrorNotification(
                title: processedAppResults.appDisplayName,
                version: processedAppResults.appVersionActual,
                size: size,
                time: time,
                imageURL: iconImageURL,
                deploymentType: processedAppResults.deploymentTypeEmoji,
                architecture: processedAppResults.architectureEmoji,
                errorMessage: teamsMessage
            )
            return true
        }
    }
    
    /// Shared date formatter for consistent timestamp formatting across all Teams notifications.
    /// 
    /// Configured with medium date style and short time style to provide readable timestamps
    /// while maintaining compact formatting suitable for notification cards.
    /// 
    /// **Format Example:** "Dec 25, 2023 at 2:30 PM"
    /// 
    /// **Usage:** Used by `processNotification` to format the current time for all notifications
    static let dateFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateStyle = .medium
      f.timeStyle = .short
      return f
    }()
    
}

