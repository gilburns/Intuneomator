//
//  TeamsNotifier+Processor.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

import Foundation

extension TeamsNotifier {
                
    // Convience method for sending success/fail messages to teams
    static func processNotification(for processedAppResults: ProcessedAppResults, success: Bool, errorMessage: String? = "") -> Bool {
        
        guard ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") == true
        else {
            Logger.log("Notifications disabled", logType: TeamsNotifier.logType)
          return false
        }

        guard let urlString: String = ConfigManager.readPlistValue(key: "TeamsWebhookURL"),
              !urlString.isEmpty
        else {
            Logger.log("No Teams Webhook URL set. Skipping.", logType: TeamsNotifier.logType)
          return false
        }
        
        // Set the Icon for the notification
        let iconImageURL = "https://icons.intuneomator.org/\(processedAppResults.appLabelName).png"
        
        let appURLString: String = processedAppResults.appLocalURL
        
        // Get file size for Teams Notification
        // File size via ByteCountFormatter
        let bytes = (try? FileManager.default.attributesOfItem(atPath: appURLString)[.size] as? Int64) ?? 0
        let size = "⚖️ \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"

        
        // Date via static formatter
        let time = "🕰️ \(TeamsNotifier.dateFormatter.string(from: Date()))"
        
        let assignedGroups = processedAppResults.appAssignments
        
        let uploadSucceeded = success

        // Initilaize the Notifier
        let teamsNotifier = TeamsNotifier(webhookURL: urlString)

        // We were sucessful with the upload
        if uploadSucceeded {
            do {
                
                // Send the notification (Currently missing some attributes)
                teamsNotifier.sendSuccessNotification(
                    title: processedAppResults.appDisplayName,
                    version: "⦿ \(processedAppResults.appVersionActual)",
                    size: size,
                    time: time,
                    imageURL: iconImageURL,
                    deploymentType: processedAppResults.deploymentTypeEmoji,
                    architecture: processedAppResults.architectureEmoji,
                    releaseNotesURL: nil,
                    assignedGroups: assignedGroups                        )
            }
            return true

        } else {
            var teamsMessage: String = ""
            if errorMessage!.isEmpty {
                teamsMessage = "Failed to upload to Intune. The automation will try again the next time it runs. If this error persists, please review the logs for more information."
            } else {
                teamsMessage = errorMessage ?? "No error message provided."
            }
            
            do {
                // Send the notification (Currently missing some attributes)
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
            }
            return true
        }
    }
    
    private static let dateFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateStyle = .medium
      f.timeStyle = .short
      return f
    }()
    
}

extension TeamsNotifier {
  /// accepts an optional, unwraps (or uses .empty) and forwards
    static func processNotification(
    for maybeResults: ProcessedAppResults?,
    success: Bool
  ) -> Bool {
    // unwrap once; use .empty if nil
    return processNotification(
      for: maybeResults ?? .empty,
      success: success
    )
  }
}
