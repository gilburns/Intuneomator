//
//  CVEFetcherError.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/31/25.
//

import Foundation

extension CVEFetcherError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The provided URL is invalid."
        case .networkError(let networkError):
            return networkError.localizedDescription
        case .httpError(let statusCode):
            return "HTTP request failed with status code \(statusCode)."
        case .emptyResponse:
            return "The server returned an empty response."
        case .decodeError(let decodeError):
            return decodeError.localizedDescription
        case .cpeSearchFailed(let message):
            return message
        }
    }
}

