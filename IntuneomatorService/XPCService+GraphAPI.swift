//
//  XPCService+GraphAPI.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

extension XPCService {
    
    // MARK: - Graph API Methods
    func fetchMobileAppCategories(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let categories = try await EntraGraphRequests.fetchMobileAppCategories(authToken: authToken)
                reply(categories)
            } catch {
                Logger.log("Failed to fetch mobile app categories: \(error.localizedDescription)", logType: "XPCService")
                reply(nil)
            }
        }
    }
    
    func fetchEntraGroups(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let categories = try await EntraGraphRequests.fetchEntraGroups(authToken: authToken)
                reply(categories)
            } catch {
                Logger.log("Failed to fetch security enabled groups: \(error.localizedDescription)", logType: "XPCService")
                reply(nil)
            }
        }
    }
    
    func fetchAssignmentFiltersForMac(reply: @escaping ([[String: Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let filters = try await EntraGraphRequests.fetchMacAssignmentFiltersAsDictionaries(authToken: authToken)
                reply(filters)
            } catch {
                Logger.log("Failed to fetch assignment filters: \(error.localizedDescription)", logType: "XPCService")
                reply(nil)
            }
        }
    }

    
}

