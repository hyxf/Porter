//
//  SettingsView.swift
//  Porter
//
//  Created by Porter Generator
//

import SwiftUI

@available(macOS 13.0, *)
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    @State private var customPortText: String = ""
    @State private var portError: String? = nil
    @State private var hasChanges: Bool = false

    var body: some View {
        Form {
            // MARK: Network

            Section {
                Toggle("LAN Access", isOn: $settings.lanAccessEnabled)
                Text("Allow devices on the same local network to connect to the server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Network")
            }

            // MARK: Port

            Section {
                Picker("Mode", selection: $settings.portMode) {
                    Text("Random").tag(PortMode.random)
                    Text("Custom").tag(PortMode.custom)
                }
                .pickerStyle(.inline)

                if settings.portMode == .custom {
                    HStack {
                        TextField("Port", text: $customPortText)
                            .frame(width: 100)
                            .onChange(of: customPortText) {
                                validateAndSavePort(customPortText)
                            }

                        if let error = portError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Text(settings.portMode == .random
                    ? "A free port will be assigned automatically on each start."
                    : "The server will always try to bind to this port.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            } header: {
                Text("Port")
            }

            // MARK: Restart

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apply Changes")
                            .font(.body)
                        Text("Restart the app to apply your new settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Restart App") {
                        restartApp()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(!hasChanges)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .onAppear {
            customPortText = "\(settings.customPort)"
        }
        .onChange(of: settings.lanAccessEnabled) { hasChanges = true }
        .onChange(of: settings.portMode) { hasChanges = true }
        .onChange(of: settings.customPort) { hasChanges = true }
    }

    // MARK: - Helpers

    private func validateAndSavePort(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = UInt16(trimmed), value >= 1024 else {
            portError = "Enter a value between 1024 and 65535"
            return
        }
        portError = nil
        settings.customPort = value
    }

    private func restartApp() {
        guard let bundleURL = Bundle.main.bundleURL as URL? else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
