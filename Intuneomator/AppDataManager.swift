//
//  AppDataManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/10/25.
//

import Foundation

@MainActor
class AppDataManager {
    
    var currentAppType: String = ""
    
    static let shared = AppDataManager()
    
    private(set) var mobileAppCategories: [[String: Any]] = []
    private(set) var entraGroups: [[String: Any]] = []
    private(set) var entraFilters: [[String: Any]] = []

    private let syncQueue = DispatchQueue(label: "com.appdatamanager.sync", attributes: .concurrent)

    private init() {}

    func fetchMobileAppCategories() async throws {
        XPCManager.shared.fetchMobileAppCategories { [weak self] categories in
            self?.mobileAppCategories = categories ?? []
        }
    }

    func fetchEntraGroups() async throws {
        XPCManager.shared.fetchEntraGroups { [weak self] groups in
            self?.entraGroups = groups ?? []
        }
    }
    
//    func fetchEntraFilters() async throws {
//        XPCManager.shared.fetchAssignmentFiltersForMac { [weak self] filters in
//            self?.entraFilters = filters ?? []
//        }
//    }

    
    func fetchEntraFilters() async throws {
        try await withCheckedThrowingContinuation { continuation in
            XPCManager.shared.fetchAssignmentFiltersForMac { [weak self] filters in
                self?.entraFilters = filters ?? []
                continuation.resume()
            }
        }
    }
    
    // MARK: - Thread-Safe Accessors
    func getMobileAppCategories() -> [[String: Any]] {
        syncQueue.sync {
            return mobileAppCategories
        }
    }

    func getEntraGroups() -> [[String: Any]] {
        syncQueue.sync {
            return entraGroups
        }
    }
    
    func getEntraFilters() -> [[String: Any]] {
        syncQueue.sync {
            return entraFilters
        }
    }
    
}
