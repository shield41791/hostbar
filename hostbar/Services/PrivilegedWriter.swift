import Foundation

enum HostbarError: LocalizedError {
    case privilegeEscalationFailed
    case writeFailed(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .privilegeEscalationFailed:
            return "Failed to obtain administrator privileges."
        case .writeFailed(let message):
            return "Failed to write hosts file: \(message)"
        case .userCancelled:
            return "Operation cancelled by user."
        }
    }
}

struct PrivilegedWriter {
    func writeHostsFile(content: String, to path: String = "/etc/hosts") async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("hostbar_hosts_\(UUID().uuidString)")

        try content.write(to: tempFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }

        let escapedTempPath = tempFile.path.replacingOccurrences(of: "'", with: "'\\''")
        let escapedDestPath = path.replacingOccurrences(of: "'", with: "'\\''")

        let shellCommand = "cp '\(escapedTempPath)' '\(escapedDestPath)' && chmod 644 '\(escapedDestPath)'"
        let script = "do shell script \"\(shellCommand)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"

            if errorMessage.contains("User canceled") || errorMessage.contains("(-128)") {
                throw HostbarError.userCancelled
            }
            throw HostbarError.privilegeEscalationFailed
        }
    }

    func flushDNSCache() async throws {
        let script = "do shell script \"dscacheutil -flushcache && killall -HUP mDNSResponder\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try process.run()
        process.waitUntilExit()
    }
}
