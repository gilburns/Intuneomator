//
//  XPCManager+Settings.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

extension XPCManager {
    
    // MARK: - Set Methods
    func setFirstRunCompleted(_ completed: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setFirstRunStatus(completed, reply: $1) }, completion: completion)
    }
    
    func setAppsToKeep(_ appCount: Int, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setAppsToKeep(appCount, reply: $1) }, completion: completion)
    }

    func setAuthMethod(_ method: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setAuthMethod(method, reply: $1) }, completion: completion)
    }

    
    func setSecretExpirationDate(_ expirationDate: Date, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setSecretExpirationDate(expirationDate, reply: $1) }, completion: completion)
    }

    func setTenantID(_ tenantID: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTenantID(tenantID, reply: $1) }, completion: completion)
    }
    
    func setApplicationID(_ appID: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setApplicationID(appID, reply: $1) }, completion: completion)
    }
    
    func setTeamsNotificationsEnabled(_ enabled: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsEnabled(enabled, reply: $1) }, completion: completion)
    }
    
    func setTeamsWebhookURL(_ url: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsWebhookURL(url, reply: $1) }, completion: completion)
    }
    
    func setTeamsNotificationsForCleanup(_ enabled: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsForCleanup(enabled, reply: $1) }, completion: completion)
    }

    func setTeamsNotificationsForCVEs(_ enabled: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsForCVEs(enabled, reply: $1) }, completion: completion)
    }

    func setTeamsNotificationsForGroups(_ enabled: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsForGroups(enabled, reply: $1) }, completion: completion)
    }

    func setTeamsNotificationsForLabelUpdates(_ enabled: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsForLabelUpdates(enabled, reply: $1) }, completion: completion)
    }

    func setTeamsNotificationsForUpdates(_ enabled: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsForUpdates(enabled, reply: $1) }, completion: completion)
    }

    func setTeamsNotificationsStyle(_ enabled: Int, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsStyle(enabled, reply: $1) }, completion: completion)
    }
    
    func setLogAgeMax(_ logAgeMax: Int, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setLogAgeMax(logAgeMax, reply: $1) }, completion: completion)
    }

    func setLogSizeMax(_ logSizeMax: Int, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setLogSizeMax(logSizeMax, reply: $1) }, completion: completion)
    }

    func setIntuneomatorUpdateMode(_ updateMode: Int, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setIntuneomatorUpdateMode(updateMode, reply: $1) }, completion: completion)
    }

    // MARK: - Get Methods
    func getFirstRunCompleted(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getFirstRunStatus(reply: $1) }, completion: completion)
    }
    
    func getAppsToKeep(completion: @escaping (Int?) -> Void) {
        sendRequest({ $0.getAppsToKeep(reply: $1) }, completion: completion)
    }

    func getAuthMethod(completion: @escaping (String?) -> Void) {
        sendRequest({ $0.getAuthMethod(reply: $1) }, completion: completion)
    }
    
    func getTenantID(completion: @escaping (String?) -> Void) {
        sendRequest({ $0.getTenantID(reply: $1) }, completion: completion)
    }
    
    func getApplicationID(completion: @escaping (String?) -> Void) {
        sendRequest({ $0.getApplicationID(reply: $1) }, completion: completion)
    }
    
    func getTeamsNotificationsEnabled(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsEnabled(reply: $1) }, completion: completion)
    }
    
    func getTeamsWebhookURL(completion: @escaping (String?) -> Void) {
        sendRequest({ $0.getTeamsWebhookURL(reply: $1) }, completion: completion)
    }

    func getTeamsNotificationsForCleanup(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsForCleanup(reply: $1) }, completion: completion)
    }

    func getTeamsNotificationsForCVEs(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsForCVEs(reply: $1) }, completion: completion)
    }

    func getTeamsNotificationsForGroups(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsForGroups(reply: $1) }, completion: completion)
    }

    func getTeamsNotificationsForLabelUpdates(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsForLabelUpdates(reply: $1) }, completion: completion)
    }

    func getTeamsNotificationsForUpdates(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsForUpdates(reply: $1) }, completion: completion)
    }

    func getTeamsNotificationsStyle(completion: @escaping (Int?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsStyle(reply: $1) }, completion: completion)
    }

    func getCertThumbprint(completion: @escaping (String?) -> Void) {
        sendRequest({ $0.getCertThumbprint(reply: $1) }, completion: completion)
    }

    func getCertExpiration(completion: @escaping (Date?) -> Void) {
        sendRequest({ $0.getCertExpiration(reply: $1) }, completion: completion)
    }

    func getSecretExpirationDate(completion: @escaping (Date?) -> Void) {
        sendRequest({ $0.getSecretExpirationDate(reply: $1) }, completion: completion)
    }

    
    func getClientSecret(completion: @escaping (String?) -> Void) {
        sendRequest({ $0.getClientSecret(reply: $1) }, completion: completion)
    }

    
    func getLogFolderSize(completion: @escaping (Int64?) -> Void) {
        sendRequest({ $0.getLogFolderSize(completion: $1) }, completion: completion)
    }

    func getCacheFolderSize(completion: @escaping (Int64?) -> Void) {
        sendRequest({ $0.getCacheFolderSize(completion: $1) }, completion: completion)
    }
    
    func getLogAgeMax(completion: @escaping (Int?) -> Void) {
        sendRequest({ $0.getLogAgeMax(reply: $1) }, completion: completion)
    }

    func getLogSizeMax(completion: @escaping (Int?) -> Void) {
        sendRequest({ $0.getLogSizeMax(reply: $1) }, completion: completion)
    }

    func getIntuneomatorUpdateMode(completion: @escaping (Int?) -> Void) {
        sendRequest({ $0.getIntuneomatorUpdateMode(reply: $1) }, completion: completion)
    }

}

