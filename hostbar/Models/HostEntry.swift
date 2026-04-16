import Foundation

struct HostEntry: Identifiable, Equatable, Hashable {
    let id: UUID
    var ipAddress: String
    var hostnames: [String]
    var isEnabled: Bool
    var comment: String?

    init(id: UUID = UUID(), ipAddress: String, hostnames: [String], isEnabled: Bool = true, comment: String? = nil) {
        self.id = id
        self.ipAddress = ipAddress
        self.hostnames = hostnames
        self.isEnabled = isEnabled
        self.comment = comment
    }

    var displayHostname: String {
        hostnames.joined(separator: " ")
    }

    var isSystemEntry: Bool {
        let systemHostnames = Set(["localhost", "broadcasthost"])
        return hostnames.contains(where: { systemHostnames.contains($0) })
    }
}
