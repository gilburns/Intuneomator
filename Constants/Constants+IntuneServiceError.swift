//
//  Constants+IntuneServiceError.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

// MARK: - Intune Service Error Types

/// Error codes and descriptions for Microsoft Intune API operations
/// Used throughout the application for consistent error handling and user feedback
enum IntuneServiceError: Int, Error, Codable {
    /// Invalid URL provided for Microsoft Graph API request
    case invalidURL = 1000
    
    /// Network connectivity issue or timeout
    case networkError = 1001
    
    /// Authentication failure with Microsoft Entra (certificate or secret)
    case authenticationError = 1002
    
    /// Insufficient permissions in Enterprise Application configuration
    case permissionDenied = 1003
    
    /// Failed to parse JSON response from Microsoft Graph API
    case decodingError = 1004
    
    /// OAuth token acquisition or refresh failed
    case tokenError = 1005
    
    /// Microsoft Graph API returned HTTP error status
    case serverError = 1006
    
    /// Human-readable error descriptions for user interface display
    var localizedDescription: String {
        switch self {
        case .invalidURL: 
            return "Invalid URL"
        case .networkError: 
            return "Network connection error"
        case .authenticationError: 
            return "Authentication failed"
        case .permissionDenied: 
            return "Missing permissions in Enterprise App settings"
        case .decodingError: 
            return "Failed to decode server response"
        case .tokenError: 
            return "Failed to obtain valid token"
        case .serverError: 
            return "Server returned an error"
        }
    }
}

