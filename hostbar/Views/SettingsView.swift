import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = false
    @State private var isCheckingUpdate = false
    @State private var isUpdating = false
    @State private var updateMessage: String? = nil
    @State private var updateFailed = false
    @State private var updateAssetURL: URL? = nil
    @State private var updatePageURL: URL? = nil

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
            copyrightFooter
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
                Text("Hostbar")
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

    private var copyrightFooter: some View {
        Text("© 2026 Yohan Joo. MIT License.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 14)
            .padding(.top, 4)
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
                    if updateAssetURL != nil {
                        Button("Update") {
                            performUpdate()
                        }
                        .disabled(isUpdating)
                    } else if let pageURL = updatePageURL {
                        Button("Update") {
                            NSWorkspace.shared.open(pageURL)
                        }
                    } else {
                        Button("Check for Updates") {
                            checkForUpdates()
                        }
                        .disabled(isCheckingUpdate)
                    }

                    if isCheckingUpdate {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                        Text("Checking…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else if isUpdating {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                        Text(updateMessage ?? "Updating…")
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
        updateAssetURL = nil
        updatePageURL = nil

        let url = URL(string: "https://api.github.com/repos/shield41791/hostbar/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isCheckingUpdate = false

                if let error = error {
                    updateFailed = true
                    updateMessage = "Failed to check for updates: \(error.localizedDescription)"
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    updateFailed = true
                    updateMessage = "Unable to retrieve update information."
                    return
                }

                let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

                if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                    updateMessage = "New version \(latestVersion) is available."

                    // .zip 에셋 URL 탐색
                    if let assets = json["assets"] as? [[String: Any]] {
                        let zipAsset = assets.first {
                            ($0["name"] as? String ?? "").hasSuffix(".zip")
                        }
                        if let downloadStr = zipAsset?["browser_download_url"] as? String {
                            updateAssetURL = URL(string: downloadStr)
                            return
                        }
                    }

                    // 에셋 없으면 릴리즈 페이지 폴백
                    if let htmlUrl = json["html_url"] as? String {
                        updatePageURL = URL(string: htmlUrl)
                    }
                } else {
                    updateMessage = "You are on the latest version."
                }
            }
        }.resume()
    }

    private func performUpdate() {
        guard let assetURL = updateAssetURL else { return }
        isUpdating = true
        updateMessage = "Downloading…"

        URLSession.shared.downloadTask(with: assetURL) { tempURL, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    isUpdating = false
                    updateFailed = true
                    updateMessage = "Download failed: \(error.localizedDescription)"
                    return
                }
                guard let tempURL = tempURL else {
                    isUpdating = false
                    updateFailed = true
                    updateMessage = "Download failed."
                    return
                }
                installUpdate(from: tempURL)
            }
        }.resume()
    }

    private func installUpdate(from zipURL: URL) {
        updateMessage = "Installing…"

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzip.arguments = ["-q", zipURL.path, "-d", tempDir.path]
            try unzip.run()
            unzip.waitUntilExit()

            let contents = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
                throw NSError(domain: "Update", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "No .app found in archive."])
            }

            let currentApp = Bundle.main.bundleURL

            // quarantine 속성 제거 후 앱 교체하고 재실행하는 스크립트
            let script = """
            #!/bin/bash
            sleep 2
            xattr -r -d com.apple.quarantine "\(newApp.path)" 2>/dev/null
            rm -rf "\(currentApp.path)"
            cp -rf "\(newApp.path)" "\(currentApp.path)"
            open "\(currentApp.path)"
            """

            let scriptURL = tempDir.appendingPathComponent("update.sh")
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let launcher = Process()
            launcher.executableURL = URL(fileURLWithPath: "/bin/bash")
            launcher.arguments = [scriptURL.path]
            try launcher.run()

            NSApplication.shared.terminate(nil)
        } catch {
            isUpdating = false
            updateFailed = true
            updateMessage = "Installation failed: \(error.localizedDescription)"
        }
    }
}
