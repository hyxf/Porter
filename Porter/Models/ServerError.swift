//
//  ServerError.swift
//  Porter
//
//  Created by Porter Generator
//

import Foundation

/// 服务器错误类型
enum ServerError: LocalizedError, Equatable {
    case alreadyRunning(port: UInt16)
    case portUnavailable
    case networkFailure(String)
    case bundleResourceNotFound(String)
    case invalidRequest

    var errorDescription: String? {
        switch self {
        case let .alreadyRunning(port):
            "Server is already running on port \(port)"
        case .portUnavailable:
            "Unable to bind to port"
        case let .networkFailure(message):
            "Network error: \(message)"
        case let .bundleResourceNotFound(resource):
            "Resource not found: \(resource)"
        case .invalidRequest:
            "Invalid HTTP request"
        }
    }
}
