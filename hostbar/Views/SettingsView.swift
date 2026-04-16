import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = false
    @State private var isCheckingUpdate = false
    @State private var updateMessage: String? = nil
    @State private var updateFailed = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            appHeader
            Divider()
            settingsForm
        }
        .frame(width: 400)
        .onAppear {
            launchAtLogin = getLaunchAtLoginState()
        }
    }

    // MARK: - Subviews

    private var appHeader: some View {
        HStack(spacing: 14) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: 60, height: 60)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("HostBar")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Version \(appVersion)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var settingsForm: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
            }

            Section("Updates") {
                HStack(spacing: 10) {
                    Button("Check for Updates") {
                        checkForUpdates()
                    }
                    .disabled(isCheckingUpdate)

                    if isCheckingUpdate {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                        Text("Checking…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else if let message = updateMessage {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(updateFailed ? .red : .secondary)
                    }

                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    // MARK: - Logic

    private func getLaunchAtLoginState() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = getLaunchAtLoginState()
            }
        }
    }

    private func checkForUpdates() {
        isCheckingUpdate = true
        updateMessage = nil
        updateFailed = false

        // TODO: Integrate with Sparkle or GitHub Releases API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCheckingUpdate = false
            updateMessage = "You're up to date."
        }
    }
}
