//
//  PorterApp.swift
//  Porter
//
//  Created by Porter Generator
//

import AppKit
import SwiftUI

@available(macOS 13.0, *)
@main
struct PorterApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var viewModel = ServerViewModel()

    // 预先缓存两张图，避免每帧重绘
    private let iconRunning: NSImage = generateStatusIcon(isRunning: true)
    private let iconStopped: NSImage = generateStatusIcon(isRunning: false)

    var body: some Scene {
        MenuBarExtra {
            ServerMenuView(viewModel: viewModel)
                .environmentObject(settings)
        } label: {
            Image(nsImage: viewModel.state.isRunning ? iconRunning : iconStopped)
                // 在 @MainActor 上下文中完成依赖注入，只执行一次
                .task {
                    viewModel.configure(settings: settings)
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

// MARK: - Icon Generation Helper

/// 动态生成带状态点的自定义图标（仅调用两次，结果缓存复用）
private func generateStatusIcon(isRunning: Bool) -> NSImage {
    let iconName = "MenuBarIcon"
    var baseImage: NSImage?

    if let customImage = NSImage(named: iconName) {
        baseImage = customImage
    } else {
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        baseImage = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }

    guard let image = baseImage else { return NSImage() }

    let newImage = NSImage(size: image.size)
    newImage.lockFocus()

    image.isTemplate = true
    image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)

    let color: NSColor = isRunning ? .systemGreen : .systemRed
    color.set()

    let dotSize: CGFloat = 8.0
    let x = image.size.width - dotSize + 1
    let y = 0.0

    let dotPath = NSBezierPath(ovalIn: NSRect(x: x, y: y, width: dotSize, height: dotSize))
    dotPath.fill()

    newImage.unlockFocus()
    newImage.isTemplate = false

    return newImage
}
