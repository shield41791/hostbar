import SwiftUI

/// Stable ID for the virtual "Ungrouped" group
private let ungroupedGroupId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

/// A display-level group (real or virtual)
private struct DisplayGroup: Identifiable {
    let id: UUID
    let name: String
    let entries: [HostEntry]
    let isVirtual: Bool // true for the "Ungrouped" virtual group

    var enabledCount: Int { entries.filter(\.isEnabled).count }
    var isAllEnabled: Bool { !entries.isEmpty && entries.allSatisfy(\.isEnabled) }
}

struct HostListView: View {
    @Bindable var viewModel: HostsViewModel
    var searchText: String = ""

    // System entries (localhost, broadcasthost) — always at top
    private var systemEntries: [HostEntry] {
        let all = viewModel.hostsFile.allEntries.filter(\.isSystemEntry)
        guard !searchText.isEmpty else { return all }
        let query = searchText.lowercased()
        return all.filter { matches($0, query: query) }
    }

    // Real groups + virtual "Ungrouped" group
    private var displayGroups: [DisplayGroup] {
        let query = searchText.lowercased()
        var groups: [DisplayGroup] = []

        // Real groups
        for section in viewModel.hostsFile.sections {
            if case .group(let group) = section {
                let entries: [HostEntry]
                if searchText.isEmpty {
                    entries = group.entries
                } else {
                    entries = group.entries.filter { matches($0, query: query) }
                }
                if !entries.isEmpty || searchText.isEmpty {
                    groups.append(DisplayGroup(
                        id: group.id,
                        name: group.name,
                        entries: entries,
                        isVirtual: false
                    ))
                }
            }
        }

        // Virtual "Ungrouped" group (non-system ungrouped entries)
        let ungrouped = viewModel.hostsFile.sections.compactMap { section -> HostEntry? in
            if case .ungroupedEntry(let entry) = section, !entry.isSystemEntry {
                if searchText.isEmpty { return entry }
                return matches(entry, query: query) ? entry : nil
            }
            return nil
        }
        if !ungrouped.isEmpty || (searchText.isEmpty && hasRealGroups) {
            groups.append(DisplayGroup(
                id: ungroupedGroupId,
                name: "Ungrouped",
                entries: ungrouped,
                isVirtual: true
            ))
        }

        return groups
    }

    private var hasRealGroups: Bool {
        viewModel.hostsFile.sections.contains { if case .group = $0 { return true }; return false }
    }

    private func matches(_ entry: HostEntry, query: String) -> Bool {
        entry.ipAddress.lowercased().contains(query) ||
        entry.hostnames.contains(where: { $0.lowercased().contains(query) })
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            // 1) System entries at top
            if !systemEntries.isEmpty {
                ForEach(systemEntries) { entry in
                    HostEntryRow(entry: entry, viewModel: viewModel)
                        .padding(.vertical, 1)
                }

                if !displayGroups.isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                }
            }

            // 2) Groups
            ForEach(displayGroups) { group in
                GroupSection(
                    displayGroup: group,
                    viewModel: viewModel
                )
                .padding(.vertical, 1)
            }

            // Search empty state
            if !searchText.isEmpty && systemEntries.isEmpty && displayGroups.isEmpty {
                Text("No matching entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }
}

// MARK: - Group Section

private struct GroupSection: View {
    let displayGroup: DisplayGroup
    @Bindable var viewModel: HostsViewModel
    @State private var isExpanded = true
    @State private var isAddingEntry = false

    private var realGroupId: UUID? {
        displayGroup.isVirtual ? nil : displayGroup.id
    }

    var body: some View {
        VStack(spacing: 0) {
            GroupSectionHeader(
                displayGroup: displayGroup,
                isExpanded: $isExpanded,
                viewModel: viewModel,
                onAddEntry: {
                    isExpanded = true
                    isAddingEntry = true
                }
            )

            if isExpanded {
                ForEach(displayGroup.entries) { entry in
                    HostEntryRow(entry: entry, viewModel: viewModel, groupId: realGroupId)
                        .padding(.leading, 16)
                }

                if isAddingEntry {
                    if let gid = realGroupId {
                        InlineAddEntryRow(groupId: gid, viewModel: viewModel) {
                            isAddingEntry = false
                        }
                        .padding(.leading, 16)
                    } else {
                        // Adding to ungrouped
                        InlineAddUngroupedRow(viewModel: viewModel) {
                            isAddingEntry = false
                        }
                        .padding(.leading, 16)
                    }
                }
            }
        }
    }
}

// MARK: - Group Section Header (supports both real and virtual groups)

private struct GroupSectionHeader: View {
    let displayGroup: DisplayGroup
    @Binding var isExpanded: Bool
    @Bindable var viewModel: HostsViewModel
    var onAddEntry: () -> Void
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedName = ""

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 14)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .buttonStyle(.plain)

            Image(systemName: displayGroup.isVirtual ? "tray.fill" : "folder.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Group name / Inline Editor
            if isEditing && !displayGroup.isVirtual {
                HStack(spacing: 4) {
                    InlineTextField(
                        text: $editedName,
                        placeholder: "Group name",
                        onCommit: commitRename,
                        onCancel: cancelRename
                    )
                    .frame(maxWidth: 160)

                    Button(action: commitRename) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button(action: cancelRename) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(displayGroup.name)
                    .font(.system(size: 13, weight: .semibold))
            }

            Text("\(displayGroup.enabledCount)/\(displayGroup.entries.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(.secondary.opacity(0.1)))

            Spacer()

            // Hover action buttons
            HStack(spacing: 2) {
                if !displayGroup.isVirtual {
                    Button {
                        editedName = displayGroup.name
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Button { onAddEntry() } label: {
                    Image(systemName: "plus")
                        .font(.caption2)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .opacity(isHovered ? 1 : 0)

            if !displayGroup.isVirtual {
                Toggle("", isOn: Binding(
                    get: { displayGroup.isAllEnabled },
                    set: { _ in viewModel.toggleGroup(displayGroup.id) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(isHovered ? 0.1 : 0.06))
        )
        .onHover { isHovered = $0 }
        .contextMenu {
            if !displayGroup.isVirtual {
                Button("Rename...") {
                    editedName = displayGroup.name
                    isEditing = true
                }

                Button("Add Entry to Group...") { onAddEntry() }

                Divider()

                Button("Delete Group (keep entries)") {
                    viewModel.deleteGroup(displayGroup.id, keepEntries: true)
                }

                Button("Delete Group and Entries", role: .destructive) {
                    viewModel.deleteGroup(displayGroup.id, keepEntries: false)
                }
            } else {
                Button("Add Entry...") { onAddEntry() }
            }
        }
    }

    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            viewModel.renameGroup(displayGroup.id, to: trimmed)
        }
        isEditing = false
    }

    private func cancelRename() {
        isEditing = false
    }
}

// MARK: - Inline add for ungrouped

private struct InlineAddUngroupedRow: View {
    @Bindable var viewModel: HostsViewModel
    let onDismiss: () -> Void

    @State private var ipAddress = ""
    @State private var hostnamesText = ""

    private var isValid: Bool {
        let ip = ipAddress.trimmingCharacters(in: .whitespaces)
        let hosts = hostnamesText.trimmingCharacters(in: .whitespaces)
        return !ip.isEmpty && !hosts.isEmpty && isValidIP(ip)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                InlineTextField(text: $ipAddress, placeholder: "IP Address", mono: true)
                    .frame(width: 120)
                InlineTextField(text: $hostnamesText, placeholder: "Hostnames", mono: true)
            }
            HStack {
                Spacer()
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Button("Add") {
                    let ip = ipAddress.trimmingCharacters(in: .whitespaces)
                    let hostnames = hostnamesText.trimmingCharacters(in: .whitespaces)
                        .split(whereSeparator: { $0.isWhitespace })
                        .map(String.init)
                    viewModel.addEntry(ipAddress: ip, hostnames: hostnames, comment: nil, toGroup: nil)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .disabled(!isValid)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor.opacity(0.06))
        )
    }

    private func isValidIP(_ string: String) -> Bool {
        let parts = string.split(separator: ".")
        if parts.count == 4 {
            return parts.allSatisfy { part in
                if let num = Int(part) { return num >= 0 && num <= 255 }
                return false
            }
        }
        if string.contains(":") {
            var addr = in6_addr()
            return inet_pton(AF_INET6, string, &addr) == 1
        }
        return false
    }
}
