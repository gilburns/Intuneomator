//
//  Constants+IntuneServiceError.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

// MARK: - Error Types
enum IntuneServiceError: Int, Error, Codable {
    case invalidURL = 1000
    case networkError = 1001
    case authenticationError = 1002
    case permissionDenied = 1003
    case decodingError = 1004
    case tokenError = 1005
    case serverError = 1006
    
    var localizedDescription: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError: return "Network connection error"
        case .authenticationError: return "Authentication failed"
        case .permissionDenied: return "Missing permissions in Enterprise App settings"
        case .decodingError: return "Failed to decode server response"
        case .tokenError: return "Failed to obtain valid token"
        case .serverError: return "Server returned an error"
        }
    }
}

