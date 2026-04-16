import Foundation

struct HostsFileWriter {
    func serialize(_ hostsFile: HostsFile) -> String {
        var lines: [String] = []

        for (i, section) in hostsFile.sections.enumerated() {
            switch section {
            case .group(let group):
                lines.append("# [HostBar:\(group.name)]")
                for entry in group.entries {
                    lines.append(formatEntry(entry))
                }
                // Add blank line after group if next section exists and isn't a raw empty line
                if i + 1 < hostsFile.sections.count {
                    if case .rawLine(_, let text) = hostsFile.sections[i + 1], text.trimmingCharacters(in: .whitespaces).isEmpty {
                        // Next line is already blank, don't add extra
                    } else {
                        lines.append("")
                    }
                }

            case .ungroupedEntry(let entry):
                lines.append(formatEntry(entry))

            case .rawLine(_, let text):
                lines.append(text)
            }
        }

        // Ensure file ends with newline
        let result = lines.joined(separator: "\n")
        if result.hasSuffix("\n") {
            return result
        }
        return result + "\n"
    }

    private func formatEntry(_ entry: HostEntry) -> String {
        var line = "\(entry.ipAddress)\t\(entry.hostnames.joined(separator: " "))"
        if let comment = entry.comment, !comment.isEmpty {
            line += " # \(comment)"
        }
        if !entry.isEnabled {
            line = "# " + line
        }
        return line
    }
}
