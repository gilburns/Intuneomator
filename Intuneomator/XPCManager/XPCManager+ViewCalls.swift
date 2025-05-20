//
//  XPCManager+ViewCalls.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

extension XPCManager {
    
    // Main View Controller
    func scanAllInstallomatorManagedLabels(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.scanAllManagedLabels(reply: $1) }, completion: completion)
    }
    
    func updateAppMetaData(_ labelFolder: String, _ displayName: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.updateAppMetadata(labelFolder, displayName, reply: $1) }, completion: completion)
    }

    func updateAppScripts(_ labelFolder: String, _ displayName: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.updateAppScripts(labelFolder, displayName, reply: $1) }, completion: completion)
    }

    func updateAppAssigments(_ labelFolder: String, _ displayName: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.updateAppAssignments(labelFolder, displayName, reply: $1) }, completion: completion)
    }

    func deleteAutomationsFromIntune(_ labelFolder: String, _ displayName: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.deleteAutomationsFromIntune(labelFolder, displayName, reply: $1) }, completion: completion)
    }


    func onDemandLabelAutomation(_ labelFolder: String, _ displayName: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.onDemandLabelAutomation(labelFolder, displayName, reply: $1) }, completion: completion)
    }

    
    func checkIntuneForAutomation(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.checkIntuneForAutomation(reply: $1) }, completion: completion)
    }

    
    // Installomator Labels
    func addNewLabel(_ newLabel: String, _ source: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.addNewLabelContent(newLabel, source, reply: $1) }, completion: completion)
    }
    
    func updateLabelsFromGitHub(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.updateLabelsFromGitHub(reply: $1) }, completion: completion)
    }
    
    func removeLabelContent(_ labelDirectory: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.removeLabelContent(labelDirectory, reply: $1) }, completion: completion)
    }
    
    // TabView Settings
    func saveLabelContent(_ labelFolder: String, _ content: NSDictionary, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.saveLabelContent(labelFolder, content, reply: $1) }, completion: completion)
    }
    
    func toggleCustomLabel(_ labelDirectory: String, _ toggle: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.toggleCustomLabel(labelDirectory, toggle, reply: $1) }, completion: completion)
    }

    
    // Label Edit Window
    func importIconToLabel(_ iconPath: String, _ labelFolder: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.importIconToLabel(iconPath, labelFolder, reply: $1) }, completion: completion)
    }
    
    func importGenericIconToLabel(_ labelFolder: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.importGenericIconToLabel(labelFolder, reply: $1) }, completion: completion)
    }
    
    func saveMetadataForLabel(_ script: String, _ labelFolder: String, reply: @escaping (Bool?) -> Void) {
        sendRequest({ $0.saveMetadataForLabel(script, labelFolder, reply: $1) }, completion: reply)
    }
    
    // Script View Controller
    func savePreInstallScriptToLabel(_ script: String, _ labelFolder: String, reply: @escaping (Bool?) -> Void) {
        sendRequest({ $0.savePreInstallScriptForLabel(script, labelFolder, reply: $1) }, completion: reply)
    }
    
    func savePostInstallScriptToLabel(_ script: String, _ labelFolder: String, reply: @escaping (Bool?) -> Void) {
        sendRequest({ $0.savePostInstallScriptForLabel(script, labelFolder, reply: $1) }, completion: reply)
    }
    
    
    // Group Assignemnt
    func assignGroupsToLabel(_ groupAssignments: [[String : Any]], _ labelFolder: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.saveGroupAssignmentsForLabel(groupAssignments, labelFolder, reply: $1) }, completion: completion)
    }

}
