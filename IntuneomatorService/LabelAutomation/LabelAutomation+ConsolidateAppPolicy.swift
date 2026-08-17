//
//  LabelAutomation+ConsolidateAppPolicy.swift
//  Intuneomator
//
//  Created by Gil Burns on 8/15/26.
//

import Foundation

// MARK: - Single App Policy Consolidation Extension

/// Extension for handling consolidation of duplicate Intune app records down to a single
/// surviving record, in support of "single app policy" mode (reuse the same Intune app
/// record across versions instead of creating a new one each run).
extension LabelAutomation {

    // MARK: - Consolidate to Single App Policy

    /// Consolidates all existing Intune app records matching a label folder's tracking ID
    /// down to a single survivor: the newest record by `createdDateTime`. All other matching
    /// records are deleted, and the current local group assignments are reasserted on the
    /// survivor to guarantee deployment continuity regardless of which record previously
    /// carried the "live" assignments.
    ///
    /// Idempotent — safe to call when there are already 0 or 1 matching records; returns a
    /// no-op success in that case.
    ///
    /// - Parameter folderName: The managed title folder name to process (format "label_GUID")
    /// - Returns: Tuple containing the surviving app ID (if any), how many records were
    ///   deleted, whether the operation fully succeeded, and a human-readable summary message
    static func consolidateToSingleAppPolicy(named folderName: String) async
        -> (survivorAppId: String?, deletedCount: Int, success: Bool, message: String) {

        Logger.info("--------------------------------------------------------", category: .automation)
        Logger.info("🚀 Start consolidation to single app policy for: \(folderName)", category: .automation)

        guard let processedAppResults = extractDataForProcessedAppResults(from: folderName) else {
            let message = "Failed to extract ProcessedAppResults data for \(folderName)"
            Logger.error("  \(message)", category: .automation)
            return (nil, 0, false, message)
        }

        let trackingID = processedAppResults.appTrackingID

        // Determine the Intune app type string for this title's deployment type
        let intuneAppType: String
        switch processedAppResults.appDeploymentType {
        case 0:
            intuneAppType = "macOSDmgApp"
        case 1:
            intuneAppType = "macOSPkgApp"
        case 2:
            intuneAppType = "macOSLobApp"
        default:
            intuneAppType = "macOSLobApp"
        }

        do {
            let entraAuthenticator = EntraAuthenticator.shared
            let authToken = try await entraAuthenticator.getEntraIDToken()

            let appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            Logger.info("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", category: .automation)

            guard appInfo.count > 1 else {
                let message = "Nothing to consolidate — \(appInfo.count) record(s) found."
                Logger.info("  \(message)", category: .automation)
                return (appInfo.first?.id, 0, true, message)
            }

            // Newest by createdDateTime survives; the rest are deleted.
            let sorted = appInfo.sorted { $0.createdDateTime < $1.createdDateTime }
            let survivor = sorted.last!
            let toDelete = sorted.dropLast()

            Logger.info("  Survivor: \(survivor.displayName) (id: \(survivor.id), created: \(survivor.createdDateTime))", category: .automation)

            var deletedCount = 0
            var failedDeletes: [String] = []
            for app in toDelete {
                do {
                    Logger.info("  Deleting duplicate app \(app.displayName) (id: \(app.id), created: \(app.createdDateTime))", category: .automation)
                    try await EntraGraphRequests.deleteIntuneApp(authToken: authToken, appId: app.id)
                    deletedCount += 1
                } catch {
                    Logger.error("  Failed to delete duplicate app \(app.id): \(error.localizedDescription)", category: .automation)
                    failedDeletes.append(app.id)
                }
            }

            // Reassign the survivor using the current local assignments, regardless of which
            // of the N old records happened to carry the "live" assignments.
            do {
                try await EntraGraphRequests.assignGroupsToApp(
                    authToken: authToken,
                    appId: survivor.id,
                    appAssignments: processedAppResults.appAssignments,
                    appType: intuneAppType,
                    installAsManaged: processedAppResults.appIsManaged
                )
            } catch {
                let message = "Deleted \(deletedCount) duplicate record(s), but failed to reassign groups to the surviving record: \(error.localizedDescription)"
                Logger.error("  \(message)", category: .automation)
                return (survivor.id, deletedCount, false, message)
            }

            guard failedDeletes.isEmpty else {
                let message = "Deleted \(deletedCount) of \(toDelete.count) duplicate record(s); failed to delete: \(failedDeletes.joined(separator: ", "))"
                Logger.error("  \(message)", category: .automation)
                return (survivor.id, deletedCount, false, message)
            }

            let message = "Consolidated to a single app policy. Deleted \(deletedCount) duplicate record(s)."
            Logger.info("✅ \(message)", category: .automation)
            return (survivor.id, deletedCount, true, message)

        } catch {
            let message = "Failed to fetch app info from Intune: \(error.localizedDescription)"
            Logger.error("  \(message)", category: .automation)
            return (nil, 0, false, message)
        }
    }

}
