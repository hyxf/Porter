//
//  ServerState.swift
//  Porter
//
//  Created by Porter Generator
//

import Foundation
import SwiftUI

/// 服务器状态枚举
enum ServerState: Equatable {
    case stopped
    case starting
    case running(port: UInt16)
    case error(ServerError)

    var displayText: String {
        switch self {
        case .stopped:
            "Server Stopped"
        case .starting:
            "Starting..."
        case let .running(port):
            "Running on :\(port)"
        case let .error(error):
            "Error: \(error.localizedDescription)"
        }
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var port: UInt16? {
        if case let .running(port) = self { return port }
        return nil
    }

    var systemImage: String {
        switch self {
        case .running: "circle.fill"
        case .stopped: "circle.fill"
        case .starting: "circle.dashed"
        case .error: "exclamationmark.circle.fill"
        }
    }

    var statusColor: Color {
        switch self {
        case .running: .green
        case .stopped: .red
        case .starting: .orange
        case .error: .red
        }
    }
}
