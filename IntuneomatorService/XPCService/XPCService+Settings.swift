//
//  XPCService+Settings.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

extension XPCService {
    
    // MARK: - Plist GET Methods
    func getFirstRunStatus(reply: @escaping (Bool) -> Void) {
        let completed = ConfigManager.readPlistValue(key: "FirstRunGUICompleted") ?? false
        reply(completed)
    }
    
    func getAppsToKeep(reply: @escaping (Int) -> Void) {
        let appsToKeep = ConfigManager.readPlistValue(key: "AppsVersionsToKeep") ?? 2
        reply(appsToKeep)
    }

    func getTenantID(reply: @escaping (String) -> Void) {
        let tenantID = ConfigManager.readPlistValue(key: "TenantID") ?? ""
        reply(tenantID)
    }
    
    func getApplicationID(reply: @escaping (String) -> Void) {
        let applicationID = ConfigManager.readPlistValue(key: "ApplicationID") ?? ""
        reply(applicationID)
    }
    
    
    func getTeamsNotificationsEnabled(reply: @escaping (Bool) -> Void) {
        let enabled = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false
        reply(enabled)
    }
    
    func getTeamsWebhookURL(reply: @escaping (String) -> Void) {
        let url = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
        reply(url)
    }
    
    func getCertThumbprint(reply: @escaping (String?) -> Void) {
        let certDetails = ConfigManager.readPlistValue(key: "CertificateDetails") ?? [:]
        let certThumbprint = certDetails["Thumbprint"] as? String
        reply(certThumbprint)
    }

    func getCertExpiration(reply: @escaping (Date?) -> Void) {
        let certDetails = ConfigManager.readPlistValue(key: "CertificateDetails") ?? [:]
        let expirationDate = certDetails["ExpirationDate"] as? Date
        reply(expirationDate)
    }

    func getClientSecret(reply: @escaping (String?) -> Void) {
        let clientSecret = KeychainManager.retrieveEntraIDSecretKey()
        reply(clientSecret)
    }

        
    func getLogAgeMax(reply: @escaping (Int) -> Void) {
        let logAgeMax = ConfigManager.readPlistValue(key: "LogRetentionDays") ?? 0
        reply(logAgeMax)
    }
    
    func getLogSizeMax(reply: @escaping (Int) -> Void) {
        let logSizeMax = ConfigManager.readPlistValue(key: "LogMaxSizeMB") ?? 0
        reply(logSizeMax)
    }
    


    func getLogFolderSize(completion: @escaping (Int64) -> Void) {
        let size = LogManagerUtil.logFolderSizeInBytes()
        completion(size)
    }

    func getCacheFolderSize(completion: @escaping (Int64) -> Void) {
        let size = CacheManagerUtil.cacheFolderSizeInBytes()
        completion(size)
    }
    
    // MARK: - Plist SET Methods
    func setFirstRunStatus(_ completed: Bool, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "FirstRunGUICompleted", value: completed)
        reply(success)
    }
    
    
    func setAppsToKeep(_ appCount: Int, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "AppsVersionsToKeep", value: appCount)
        reply(success)
    }

    func setAuthMethod(_ method: String, reply: @escaping (Bool) -> Void) {
        let validMethods = ["certificate", "secret"]
        guard validMethods.contains(method) else {
            Logger.log("Invalid auth method: \(method)", logType: "XPCService")
            reply(false)
            return
        }
        let success = ConfigManager.writePlistValue(key: "AuthMethod", value: method)
        reply(success)
    }
    
    func setTenantID(_ tenantID: String, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "TenantID", value: tenantID)
        reply(success)
    }
    
    func setApplicationID(_ applicationID: String, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "ApplicationID", value: applicationID)
        reply(success)
    }
    
    func setTeamsNotificationsEnabled(_ enabled: Bool, reply: @escaping (Bool) -> Void) {
        Logger.log("setTeamsNotificationsEnabled: \(enabled)", logType: "XPCService")
        let success = ConfigManager.writePlistValue(key: "TeamsNotificationsEnabled", value: enabled)
        reply(success)
    }
    
    func setTeamsWebhookURL(_ url: String, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "TeamsWebhookURL", value: url)
        reply(success)
    }

    func setLogAgeMax(_ logAgeMax: Int, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "LogRetentionDays", value: logAgeMax)
        reply(success)
    }
    
    func setLogSizeMax(_ logSizeMax: Int, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "LogMaxSizeMB", value: logSizeMax)
        reply(success)
    }

    
}
