///
///  EditViewController+SingleAppPolicy.swift
///  Intuneomator
///
///  Extension for `EditViewController` to manage the "single app policy" toggle.
///  Enabling this option reuses a single Intune app record across versions instead of
///  creating a new one for every version. Since Intuneomator previously always created a
///  new record per version, a title may already have multiple existing Intune records by
///  the time this is switched on — turning it on triggers a two-step confirmed
///  consolidation down to a single surviving record before the setting takes effect.
///

import Foundation
import AppKit

extension EditViewController {

    /// Handles the "Single Policy" checkbox toggle.
    /// Turning it ON may require consolidating existing duplicate Intune app records first;
    /// turning it OFF is forward-looking only and needs no confirmation.
    /// - Parameter sender: The checkbox that triggered this action.
    @IBAction func buttonSingleAppPolicyDidChange(_ sender: NSButton) {
        if sender.state == .on {
            progSingleAppPolicy.startAnimation(self)
            buttonSingleAppPolicy.isEnabled = false
            handleSingleAppPolicyEnabled()
        } else {
            trackChanges()
        }
    }

    /// Checks how many existing Intune app records exist for this title's tracking ID.
    /// If 0 or 1, there's nothing to consolidate and the toggle is accepted immediately.
    /// If more than 1, prompts for two-step confirmation before consolidating.
    private func handleSingleAppPolicyEnabled() {
        guard let appData = appData else { return }
        let labelFolder = "\(appData.label)_\(appData.guid)"

        XPCManager.shared.findAppsByTrackingID(appData.guid) { [weak self] apps in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let existingCount = apps?.count ?? 0
                if existingCount <= 1 {
                    self.trackChanges()
                } else {
                    self.confirmAndConsolidate(labelFolder: labelFolder, existingCount: existingCount)
                }
                self.progSingleAppPolicy.stopAnimation(self)
                self.buttonSingleAppPolicy.isEnabled = true
            }
        }
    }

    /// Shows the two-step "are you sure" confirmation for consolidating duplicate Intune app
    /// records, mirroring the destructive-action pattern used by "Delete Automations from
    /// Intune". On confirmation, calls the daemon to perform the consolidation.
    private func confirmAndConsolidate(labelFolder: String, existingCount: Int) {
        let alert = NSAlert()
        alert.messageText = "Consolidate Existing Intune Records"
        alert.informativeText = "This title currently has \(existingCount) app records in Intune. Enabling single-policy mode requires keeping only the newest record and deleting the other \(existingCount - 1). This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Consolidate")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            buttonSingleAppPolicy.state = .off
            return
        }

        let confirmAlert = NSAlert()
        confirmAlert.messageText = "Are you absolutely sure?"
        confirmAlert.informativeText = "This action cannot be undone. \(existingCount - 1) older Intune app record(s) will be permanently deleted, keeping only the newest."
        confirmAlert.alertStyle = .critical
        confirmAlert.addButton(withTitle: "Really Delete")
        confirmAlert.addButton(withTitle: "Cancel")

        guard confirmAlert.runModal() == .alertFirstButtonReturn else {
            buttonSingleAppPolicy.state = .off
            return
        }

        buttonSingleAppPolicy.isEnabled = false
        XPCManager.shared.consolidateToSingleAppPolicy(labelFolder) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.buttonSingleAppPolicy.isEnabled = true

                let success = result?["success"] as? Bool ?? false
                if success {
                    self.trackChanges()
                } else {
                    self.buttonSingleAppPolicy.state = .off
                    let message = result?["message"] as? String ?? "Unknown error"
                    let failAlert = NSAlert()
                    failAlert.messageText = "Consolidation Failed"
                    failAlert.informativeText = message
                    failAlert.alertStyle = .critical
                    failAlert.runModal()
                }
            }
        }
    }

}
