//
//  ServerViewModel.swift
//  Porter
//
//  Created by Porter Generator
//

import AppKit
import Combine
import Foundation
import Network
import OSLog
import SwiftUI

@MainActor
@available(macOS 13.0, *)
final class ServerViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var state: ServerState = .stopped
    @Published var alertItem: AlertItem?

    /// monitor 维护的原始局域网 IP，不含业务逻辑判断
    @Published private(set) var rawLanIP: String? = nil

    // MARK: - Computed Properties

    var serverURL: String {
        guard let port = state.port else { return "N/A" }
        return "http://127.0.0.1:\(port)"
    }

    /// 仅在局域网模式开启且服务运行时暴露 LAN 地址
    var lanServerURL: String? {
        guard
            let settings,
            settings.lanAccessEnabled,
            let port = state.port,
            let ip = rawLanIP else { return nil }
        return "http://\(ip):\(port)"
    }

    var isLaunchAtLoginEnabled: Bool {
        get { LaunchAtLogin.isEnabled }
        set {
            LaunchAtLogin.isEnabled = newValue
            objectWillChange.send()
        }
    }

    // MARK: - Private Properties

    private let httpServer = HTTPServer()
    private let logger = Logger(subsystem: "com.porter.viewmodel", category: "server")
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.porter.pathmonitor", qos: .utility)

    /// 延迟注入，configure(settings:) 调用后才可用
    private var settings: AppSettings?

    // MARK: - Initialization

    init() {}

    deinit {
        pathMonitor.cancel()
    }

    // MARK: - Configuration

    /// 由 PorterApp 在 @MainActor 上下文中调用，完成依赖注入并启动服务器
    func configure(settings: AppSettings) {
        guard self.settings == nil else { return } // 防止重复配置
        self.settings = settings
        Task {
            await startServer()
        }
    }

    // MARK: - Public Methods

    func startServer() async {
        guard let settings else { return }
        guard state != .starting, !state.isRunning else { return }

        withAnimation { state = .starting }

        let port = settings.resolvedPort
        let lanAccess = settings.lanAccessEnabled

        do {
            let assignedPort = try await httpServer.start(port: port, lanAccess: lanAccess)

            withAnimation {
                state = .running(port: assignedPort)
            }
            logger.info("Server started successfully on port \(assignedPort)")

            // 服务启动完成后再启动 monitor，避免时序竞争
            startPathMonitor()

        } catch let error as ServerError {
            handleError(error)
        } catch {
            handleError(ServerError.networkFailure(error.localizedDescription))
        }
    }

    func stopServer() async {
        pathMonitor.cancel()
        rawLanIP = nil
        await httpServer.stop()
        withAnimation {
            state = .stopped
        }
        logger.info("Server stopped")
    }

    func openInBrowser() {
        guard
            let port = state.port,
            let url = URL(string: "http://127.0.0.1:\(port)") else
        {
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private Methods

    private func handleError(_ error: Error) {
        withAnimation {
            state = .error(error as? ServerError ?? .networkFailure(error.localizedDescription))
        }
        logger.error("Error: \(error.localizedDescription)")
        alertItem = AlertItem(title: "Server Error", message: error.localizedDescription)
    }

    /// 启动网络路径监听
    /// monitor 只负责维护 rawLanIP，不掺杂业务设置判断
    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            // IP 计算在后台队列完成（nonisolated 纯函数，不阻塞主线程）
            let ip: String? = path.status == .satisfied
                ? path.availableInterfaces
                .filter { $0.type == .wifi || $0.type == .wiredEthernet }
                .compactMap { Self.ipAddress(for: $0) }
                .first
                : nil

            // 仅将结果值回传主线程
            Task { @MainActor in
                if self.rawLanIP != ip {
                    self.rawLanIP = ip
                    self.logger.info("LAN IP updated: \(ip ?? "none")")
                }
            }
        }

        pathMonitor.start(queue: monitorQueue)
    }

    /// 纯计算函数，通过接口名精确匹配 IPv4 局域网地址
    /// nonisolated：在后台队列安全调用，不占用主线程
    private nonisolated static func ipAddress(for interface: NWInterface) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let ifa = ptr {
            defer { ptr = ifa.pointee.ifa_next }

            guard
                String(cString: ifa.pointee.ifa_name) == interface.name,
                ifa.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard
                getnameinfo(
                    ifa.pointee.ifa_addr,
                    socklen_t(ifa.pointee.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil, 0,
                    NI_NUMERICHOST) == 0 else { continue }

            let ip = String(cString: hostname)

            // 过滤 link-local 地址（169.254.x.x）
            if !ip.hasPrefix("169.254") {
                return ip
            }
        }
        return nil
    }
}
