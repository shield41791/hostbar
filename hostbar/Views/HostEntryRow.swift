import SwiftUI

struct HostEntryRow: View {
    let entry: HostEntry
    let groupId: UUID?
    @Bindable var viewModel: HostsViewModel
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editIP = ""
    @State private var editHostnames = ""

    init(entry: HostEntry, viewModel: HostsViewModel, groupId: UUID? = nil) {
        self.entry = entry
        self.groupId = groupId
        self.viewModel = viewModel
    }

    private var isEditValid: Bool {
        let ip = editIP.trimmingCharacters(in: .whitespaces)
        let hosts = editHostnames.trimmingCharacters(in: .whitespaces)
        return !ip.isEmpty && !hosts.isEmpty && isValidIP(ip)
    }

    var body: some View {
        if isEditing {
            editingRow
        } else {
            displayRow
        }
    }

    // MARK: - Display Mode

    private var displayRow: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { entry.isEnabled },
                set: { _ in viewModel.toggleEntry(entry.id) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(entry.isSystemEntry)

            Text(entry.ipAddress)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 120, alignment: .leading)

            Text(entry.displayHostname)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Action buttons — always present, visibility controlled by opacity
            if !entry.isSystemEntry {
                HStack(spacing: 4) {
                    Button {
                        editIP = entry.ipAddress
                        editHostnames = entry.hostnames.joined(separator: " ")
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button {
                        viewModel.deleteEntry(entry.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.7))
                }
                .opacity(isHovered ? 1 : 0)
            }

            if entry.isSystemEntry {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .opacity(entry.isEnabled ? 1.0 : 0.5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            if !entry.isSystemEntry {
                Button(entry.isEnabled ? "Disable" : "Enable") {
                    viewModel.toggleEntry(entry.id)
                }

                Divider()

                Button("Edit...") {
                    editIP = entry.ipAddress
                    editHostnames = entry.hostnames.joined(separator: " ")
                    isEditing = true
                }

                if !viewModel.hostsFile.allGroups.isEmpty {
                    Menu("Move to Group") {
                        ForEach(viewModel.hostsFile.allGroups) { group in
                            Button(group.name) {
                                viewModel.moveEntry(entry.id, toGroup: group.id)
                            }
                        }
                        Divider()
                        Button("Ungrouped") {
                            viewModel.moveEntry(entry.id, toGroup: nil)
                        }
                    }
                }

                Divider()

                Button("Delete", role: .destructive) {
                    viewModel.deleteEntry(entry.id)
                }
            }
        }
        .accessibilityLabel("\(entry.ipAddress) \(entry.displayHostname), \(entry.isEnabled ? "enabled" : "disabled")")
    }

    // MARK: - Inline Edit Mode

    private var editingRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                InlineTextField(text: $editIP, placeholder: "IP", mono: true)
                    .frame(width: 120)

                InlineTextField(text: $editHostnames, placeholder: "Hostnames", mono: true)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    isEditing = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)

                Button("Apply") {
                    let ip = editIP.trimmingCharacters(in: .whitespaces)
                    let hostnames = editHostnames.trimmingCharacters(in: .whitespaces)
                        .split(whereSeparator: { $0.isWhitespace })
                        .map(String.init)
                    viewModel.updateEntry(entry.id, ipAddress: ip, hostnames: hostnames, comment: entry.comment)
                    isEditing = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .disabled(!isEditValid)
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

// MARK: - Inline Add Row (for adding entry inside a group)

struct InlineAddEntryRow: View {
    let groupId: UUID
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
                    viewModel.addEntry(ipAddress: ip, hostnames: hostnames, comment: nil, toGroup: groupId)
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

// MARK: - NSTextField for inline editing (minimal focus style)

struct InlineTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var mono: Bool = false

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.font = mono
            ? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            : NSFont.systemFont(ofSize: 12)
        field.controlSize = .small
        field.focusRingType = .none
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                text.wrappedValue = field.stringValue
            }
        }
    }
}

