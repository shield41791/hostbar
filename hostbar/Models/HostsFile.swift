import Foundation

struct HostsFile: Equatable {
    var sections: [Section]

    init(sections: [Section] = []) {
        self.sections = sections
    }

    enum Section: Identifiable, Equatable {
        case group(HostGroup)
        case ungroupedEntry(HostEntry)
        case rawLine(id: UUID, text: String)

        var id: UUID {
            switch self {
            case .group(let group): return group.id
            case .ungroupedEntry(let entry): return entry.id
            case .rawLine(let id, _): return id
            }
        }
    }

    var allGroups: [HostGroup] {
        sections.compactMap {
            if case .group(let group) = $0 { return group }
            return nil
        }
    }

    var allEntries: [HostEntry] {
        sections.flatMap { section -> [HostEntry] in
            switch section {
            case .group(let group): return group.entries
            case .ungroupedEntry(let entry): return [entry]
            case .rawLine: return []
            }
        }
    }

    var groupNames: [String] {
        allGroups.map(\.name)
    }

    static let empty = HostsFile(sections: [])
}
