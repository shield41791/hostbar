import Foundation

struct HostGroup: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var entries: [HostEntry]

    init(id: UUID = UUID(), name: String, entries: [HostEntry] = []) {
        self.id = id
        self.name = name
        self.entries = entries
    }

    var isAllEnabled: Bool {
        !entries.isEmpty && entries.allSatisfy(\.isEnabled)
    }

    var isAnyEnabled: Bool {
        entries.contains(where: \.isEnabled)
    }

    var enabledCount: Int {
        entries.filter(\.isEnabled).count
    }
}
