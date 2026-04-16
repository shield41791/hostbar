import Foundation

struct HostsFileParser {
    func parse(_ content: String) -> HostsFile {
        let lines = content.components(separatedBy: "\n")
        var sections: [HostsFile.Section] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            if trimmed.isEmpty {
                sections.append(.rawLine(id: UUID(), text: line))
                index += 1
                continue
            }

            // HostBar group marker: # [HostBar:GroupName]
            if let groupName = parseHostBarGroupMarker(trimmed) {
                index += 1
                let entries = collectGroupEntries(lines: lines, index: &index)
                let group = HostGroup(name: groupName, entries: entries)
                sections.append(.group(group))
                continue
            }

            // Heuristic group detection: # GroupName followed by host entries
            if trimmed.hasPrefix("#") && !trimmed.hasPrefix("##") {
                let commentText = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)

                // Check if this is a disabled host entry (# IP hostname)
                if let entry = parseHostLine(commentText, isEnabled: false) {
                    sections.append(.ungroupedEntry(entry))
                    index += 1
                    continue
                }

                // Check if next non-empty line is a host entry → treat as group header
                if !commentText.isEmpty && hasFollowingHostEntries(lines: lines, from: index + 1) {
                    let groupName = commentText
                    index += 1
                    let entries = collectGroupEntries(lines: lines, index: &index)
                    let group = HostGroup(name: groupName, entries: entries)
                    sections.append(.group(group))
                    continue
                }

                // Just a comment line
                sections.append(.rawLine(id: UUID(), text: line))
                index += 1
                continue
            }

            // Active host entry
            if let entry = parseHostLine(trimmed, isEnabled: true) {
                sections.append(.ungroupedEntry(entry))
                index += 1
                continue
            }

            // Anything else: preserve as raw
            sections.append(.rawLine(id: UUID(), text: line))
            index += 1
        }

        return HostsFile(sections: sections)
    }

    func parseFromFile(at path: String = "/etc/hosts") throws -> HostsFile {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return parse(content)
    }

    // MARK: - Private

    /// Parses "# [HostBar:GroupName]" and returns the group name, or nil.
    private func parseHostBarGroupMarker(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        let afterHash = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        guard afterHash.hasPrefix("[HostBar:") && afterHash.hasSuffix("]") else { return nil }
        let name = String(afterHash.dropFirst("[HostBar:".count).dropLast())
        return name.isEmpty ? nil : name
    }

    private func parseHostLine(_ text: String, isEnabled: Bool) -> HostEntry? {
        let components = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard components.count >= 2 else { return nil }

        let ip = components[0]
        guard isValidIP(ip) else { return nil }

        // Split hostnames and inline comment
        var hostnames: [String] = []
        var comment: String?

        for i in 1..<components.count {
            if components[i].hasPrefix("#") {
                let commentParts = components[i...].joined(separator: " ")
                comment = String(commentParts.dropFirst()).trimmingCharacters(in: .whitespaces)
                break
            }
            hostnames.append(components[i])
        }

        guard !hostnames.isEmpty else { return nil }

        return HostEntry(ipAddress: ip, hostnames: hostnames, isEnabled: isEnabled, comment: comment)
    }

    private func isValidIP(_ string: String) -> Bool {
        // IPv4
        let parts = string.split(separator: ".")
        if parts.count == 4 {
            let nums = parts.compactMap { Int($0) }
            if nums.count == 4 && nums.allSatisfy({ $0 >= 0 && $0 <= 255 }) {
                return true
            }
        }
        // IPv6 (including ::1)
        if string.contains(":") {
            var addr = in6_addr()
            return inet_pton(AF_INET6, string, &addr) == 1
        }
        return false
    }

    private func hasFollowingHostEntries(lines: [String], from startIndex: Int) -> Bool {
        var i = startIndex
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                i += 1
                continue
            }
            if parseHostLine(trimmed, isEnabled: true) != nil {
                return true
            }
            if trimmed.hasPrefix("#") {
                let afterHash = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if parseHostLine(afterHash, isEnabled: false) != nil {
                    return true
                }
            }
            return false
        }
        return false
    }

    private func collectGroupEntries(lines: [String], index: inout Int) -> [HostEntry] {
        var entries: [HostEntry] = []

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                break
            }

            if parseHostBarGroupMarker(trimmed) != nil {
                break
            }

            if let entry = parseHostLine(trimmed, isEnabled: true) {
                entries.append(entry)
                index += 1
                continue
            }

            if trimmed.hasPrefix("#") && !trimmed.hasPrefix("##") {
                let afterHash = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)

                if !afterHash.isEmpty && parseHostLine(afterHash, isEnabled: false) == nil {
                    break
                }

                if let entry = parseHostLine(afterHash, isEnabled: false) {
                    entries.append(entry)
                    index += 1
                    continue
                }
            }

            break
        }

        return entries
    }
}
