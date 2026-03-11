//
//  ServerMenuView.swift
//  Porter
//
//  Created by Porter Generator
//

import SwiftUI

@available(macOS 13.0, *)
struct ServerMenuView: View {
    @ObservedObject var viewModel: ServerViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            // 1. Header Area
            headerView

            // 2. Info Dashboard
            if viewModel.state.isRunning {
                dashboardView
            }

            Divider()
                .padding(.vertical, 8)

            // 3. Controls Area
            controlsView

            // 4. Footer
            footerView
        }
        .frame(width: 320)
        .background(Material.regular)
        .alert(item: $viewModel.alertItem) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Porter")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(viewModel.state.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusIndicatorView(state: viewModel.state)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.clear],
                startPoint: .top,
                endPoint: .bottom))
    }

    private var dashboardView: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Label("Status", systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                    Text("Active")
                        .foregroundStyle(.green)
                        .fontWeight(.medium)
                }

                GridRow {
                    Label("Local", systemImage: "network")
                        .foregroundStyle(.secondary)
                    Text(viewModel.serverURL)
                        .textSelection(.enabled)
                        .font(.system(.body, design: .monospaced))
                }

                if let lanURL = viewModel.lanServerURL {
                    GridRow {
                        Label("LAN", systemImage: "wifi")
                            .foregroundStyle(.secondary)
                        Text(lanURL)
                            .textSelection(.enabled)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .font(.caption)
            .padding(4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var controlsView: some View {
        VStack(spacing: 12) {
            if viewModel.state.isRunning {
                HStack(spacing: 12) {
                    Button(action: { viewModel.openInBrowser() }) {
                        Label("Dashboard", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button(action: {
                        Task { await viewModel.stopServer() }
                    }) {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button(action: {
                    Task { await viewModel.startServer() }
                }) {
                    Label(
                        viewModel.state == .starting ? "Starting..." : "Start Server",
                        systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(viewModel.state == .starting)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var footerView: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { viewModel.isLaunchAtLoginEnabled },
                set: { viewModel.isLaunchAtLoginEnabled = $0 }))
            {
                Text("Launch at Login")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Spacer()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings (⌘,)")

            Divider()
                .frame(height: 12)
                .padding(.horizontal, 6)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.black.opacity(0.03))
    }
}

// MARK: - Components

@available(macOS 13.0, *)
struct StatusIndicatorView: View {
    let state: ServerState

    var body: some View {
        ZStack {
            if case .running = state {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 36, height: 36)
            }

            Group {
                switch state {
                case .starting:
                    Image(systemName: "gearshape.2")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.orange)

                case .running:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.green)
                        .symbolRenderingMode(.hierarchical)

                case .stopped:
                    Image(systemName: "power.circle")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.secondary)

                case .error:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.red)
                        .symbolRenderingMode(.multicolor)
                }
            }
        }
        .frame(width: 32, height: 32)
    }
}
