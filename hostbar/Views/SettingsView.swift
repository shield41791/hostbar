import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = false
    @State private var updateMessage: String? = nil
    @State private var isCheckingUpdate = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
            }

            Section {
                HStack {
                    Button("업데이트 확인") {
                        checkForUpdates()
                    }
                    .disabled(isCheckingUpdate)

                    if isCheckingUpdate {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.leading, 4)
                    }
                }

                if let message = updateMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                LabeledContent("앱 버전", value: appVersion)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .onAppear {
            launchAtLogin = getLaunchAtLoginState()
        }
    }

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
                // 실패 시 토글 복원
                launchAtLogin = getLaunchAtLoginState()
            }
        }
    }

    private func checkForUpdates() {
        isCheckingUpdate = true
        updateMessage = nil

        // 실제 업데이트 확인 로직 자리 (예: Sparkle 또는 GitHub Releases API)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCheckingUpdate = false
            updateMessage = "최신 버전을 사용 중입니다."
        }
    }
}
