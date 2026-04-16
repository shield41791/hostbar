import Foundation

struct GroupMetadata: Codable {
    var groups: [GroupInfo]

    struct GroupInfo: Codable {
        var name: String
        var entryFingerprints: [String]
    }
}

struct GroupMetadataStore {
    private var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("HostBar", isDirectory: true)
        return dir.appendingPathComponent("groups.json")
    }

    func save(_ hostsFile: HostsFile) {
        let groups = hostsFile.allGroups.map { group in
            GroupMetadata.GroupInfo(
                name: group.name,
                entryFingerprints: group.entries.map { "\($0.ipAddress)|\($0.hostnames.joined(separator: ","))" }
            )
        }

        let metadata = GroupMetadata(groups: groups)

        do {
            let dir = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(metadata)
            try data.write(to: storeURL)
        } catch {
            // Non-critical: silently fail
        }
    }

    func load() -> GroupMetadata? {
        guard let data = try? Data(contentsOf: storeURL),
              let metadata = try? JSONDecoder().decode(GroupMetadata.self, from: data) else {
            return nil
        }
        return metadata
    }
}
