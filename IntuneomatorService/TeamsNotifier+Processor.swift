//
//  TeamsNotifier+Processor.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

import Foundation

extension TeamsNotifier {
    
    static let logType = "TeamsNotifier"
    
    static func processNotification(for processedAppResults: ProcessedAppResults?, success: Bool) -> Bool {
        
        // Get the Teams notification state from Config
        let sendTeamNotification = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false

        // If we should send a notification
        if sendTeamNotification {
            // get the webhook URL
            let url = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
            
            if url.isEmpty {
                Logger.log("No Teams Webhook URL set in Config. Not sending notification.", logType: logType)
            } else {
                
                // Set the Icon for the notification
                let iconImageURL = "https://icons.intuneomator.org/\(processedAppResults?.appLabelName ?? "genericapp").png"
                
                // Get file size for Teams Notification
                var fileSizeDisplay: String = ""
                do {
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: processedAppResults?.appLocalURL ?? "")
                    let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
                    let fileSizeMB = Double(fileSizeBytes) / 1_048_576

                    if fileSizeMB >= 1000 {
                        let fileSizeGB = fileSizeMB / 1024
                        fileSizeDisplay = String(format: "%.2f GB", fileSizeGB)
                    } else {
                        fileSizeDisplay = String(format: "%.2f MB", fileSizeMB)
                    }

                    Logger.log("File size: \(fileSizeDisplay)", logType: logType)
                } catch {
                    Logger.log("Unable to get file size: \(error.localizedDescription)", logType: logType)
                }

                // Get time stamp for notification:
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                let dateString = formatter.string(from: Date())

                let friendlyDate = "🕰️ \(dateString)"

                // Set the deployment type for the notification
                let appDeploymentType: Int = processedAppResults?.appDeploymentType ?? 3
                var deploymentType: String = ""
                
                switch appDeploymentType {
                case 0:
                    deploymentType = "💾 DMG"
                case 1:
                    deploymentType = "📦 PKG"
                case 2:
                    deploymentType = "🏢 LOB"
                default:
                    deploymentType = "🔄 Unknown"
                }
                
                // Set the deployment arch for the notification
                let appDeploymentArch: Int = processedAppResults?.appDeploymentArch ?? 3
                var deploymentArch: String = ""

                switch appDeploymentArch {
                    case 0:
                    deploymentArch = "🌍 Arm64"
                case 1:
                    deploymentArch = "🌍 x86_64"
                case 2:
                    deploymentArch = "🌍 Universal"
                default:
                    deploymentArch = "🔄 Unknown"
                }
                
                let assignedGroups = processedAppResults?.appAssignments ?? []
                
                let uploadSucceeded = success
                
                // We were sucessful with the upload
                if uploadSucceeded {
                    do {
                        
                        // Initilaize the Notifier
                        let teamsNotifier = TeamsNotifier(webhookURL: url)
                        
                        // Send the notification (Currently missing some attributes)
                        teamsNotifier.sendSuccessNotification(
                            title: processedAppResults?.appDisplayName ?? "",
                            version: processedAppResults?.appVersionActual ?? "",
                            size: fileSizeDisplay,
                            time: friendlyDate,
                            imageURL: iconImageURL,
                            deploymentType: deploymentType,
                            architecture: deploymentArch,
                            releaseNotesURL: nil,
                            assignedGroups: assignedGroups                        )
                    }
                    return true

                } else {
                    do {
                        
                        // Initilaize the Notifier
                        let teamsNotifier = TeamsNotifier(webhookURL: url)
                        
                        // Send the notification (Currently missing some attributes)
                        teamsNotifier.sendErrorNotification(
                            title: processedAppResults?.appDisplayName ?? "",
                            version: processedAppResults?.appVersionActual ?? "",
                            size: fileSizeDisplay,
                            time: friendlyDate,
                            imageURL: iconImageURL,
                            deploymentType: deploymentType,
                            architecture: deploymentArch,
                            errorMessage: "Failed to upload to Intune. The automation will try again the next time it runs."
                        )
                    }
                }
                return true
            }
        } else {
            Logger.log("❌ Teams notifications are not enabled.", logType: logType)
            return false
        }
        return true
    }
}

