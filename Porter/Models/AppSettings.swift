//
//  AppSettings.swift
//  Porter
//
//  Created by Porter Generator
//

import Combine
import Foundation

enum PortMode: String {
    case random
    case custom
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var portMode: PortMode {
        didSet { UserDefaults.standard.set(portMode.rawValue, forKey: "portMode") }
    }

    @Published var customPort: UInt16 {
        didSet { UserDefaults.standard.set(Int(customPort), forKey: "customPort") }
    }

    @Published var lanAccessEnabled: Bool {
        didSet { UserDefaults.standard.set(lanAccessEnabled, forKey: "lanAccessEnabled") }
    }

    init() {
        let rawMode = UserDefaults.standard.string(forKey: "portMode") ?? "random"
        portMode = PortMode(rawValue: rawMode) ?? .random

        let savedPort = UserDefaults.standard.integer(forKey: "customPort")
        customPort = savedPort > 0 ? UInt16(savedPort) : 8080

        lanAccessEnabled = UserDefaults.standard.bool(forKey: "lanAccessEnabled")
    }

    /// 根据当前设置返回实际使用的端口（0 = 随机分配）
    var resolvedPort: UInt16 {
        portMode == .random ? 0 : customPort
    }
}
