//
//  XPCManager+EntraID.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

extension XPCManager {
    
    // MARK: - Graph API
    // Fetch Methods for Graph API

    func fetchMobileAppCategories(completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.fetchMobileAppCategories(reply: $1) }, completion: completion)
    }
    
    func fetchEntraGroups(completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.fetchEntraGroups(reply: $1) }, completion: completion)
    }
    
    func fetchAssignmentFiltersForMac(completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.fetchAssignmentFiltersForMac(reply: $1) }, completion: completion)
    }
    
    
    func fetchDiscoveredMacApps(completion: @escaping ([DetectedApp]?) -> Void) {
        sendRequest({ service, reply in
            service.fetchDiscoveredMacApps(reply: reply)
        }) { (data: Data?) in
            guard let data = data else {
                completion(nil)
                return
            }
            do {
                let apps = try JSONDecoder().decode([DetectedApp].self, from: data)
                completion(apps)
            } catch {
                print("Failed to decode DetectedApp array: \(error)")
                completion(nil)
            }
        }
    }
    
    
    func fetchDevices(forAppID appID: String, completion: @escaping ([DeviceInfo]?) -> Void) {
        sendRequest({ service, reply in
            service.fetchDevices(forAppID: appID, reply: reply)
        }) { (data: Data?) in
            guard let data = data else {
                completion(nil)
                return
            }
            do {
                let devices = try JSONDecoder().decode([DeviceInfo].self, from: data)
                completion(devices)
            } catch {
                print("⚠️ Failed to decode devices: \(error)")
                completion(nil)
            }
        }
    }

}

