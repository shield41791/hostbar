import SwiftUI

struct EntryEditorSheet: View {
    @Bindable var viewModel: HostsViewModel
    let entry: HostEntry?
    let groupId: UUID?

    @State private var ipAddress = ""
    @State private var hostnamesText = ""
    @State private var comment = ""
    @State private var selectedGroupId: UUID?
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss

    private enum Field { case ip, hostnames, comment }

    private var isEditing: Bool { entry != nil }
    private var isValid: Bool {
        !ipAddress.trimmingCharacters(in: .whitespaces).isEmpty &&
        !hostnamesText.trimmingCharacters(in: .whitespaces).isEmpty &&
        isValidIP(ipAddress.trimmingCharacters(in: .whitespaces))
    }

    private var ipValidationColor: Color {
        let trimmed = ipAddress.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .secondary.opacity(0.3) }
        return isValidIP(trimmed) ? .green.opacity(0.5) : .red.opacity(0.5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Edit Entry" : "Add Entry")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            // IP Address
            VStack(alignment: .leading, spacing: 4) {
                Text("IP Address")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. 127.0.0.1", text: $ipAddress)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .ip)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(ipValidationColor, lineWidth: 1)
                    )
            }

            // Hostnames
            VStack(alignment: .leading, spacing: 4) {
                Text("Hostnames")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. example.com api.example.com", text: $hostnamesText)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .hostnames)
            }

            // Comment
            VStack(alignment: .leading, spacing: 4) {
                Text("Comment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Optional", text: $comment)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .comment)
            }

            // Group picker
            if !viewModel.hostsFile.allGroups.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Group")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $selectedGroupId) {
                        Text("Ungrouped").tag(nil as UUID?)
                        ForEach(viewModel.hostsFile.allGroups) { group in
                            Text(group.name).tag(group.id as UUID?)
                        }
                    }
                    .labelsHidden()
                }
            }

            // Buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Save" : "Add") {
                    saveEntry()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            if let entry = entry {
                ipAddress = entry.ipAddress
                hostnamesText = entry.hostnames.joined(separator: " ")
                comment = entry.comment ?? ""
                selectedGroupId = groupId
            } else {
                selectedGroupId = groupId
            }
            focusedField = .ip
        }
    }

    private func saveEntry() {
        let ip = ipAddress.trimmingCharacters(in: .whitespaces)
        let hostnames = hostnamesText.trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        let commentValue = comment.trimmingCharacters(in: .whitespaces)
        let finalComment = commentValue.isEmpty ? nil : commentValue

        if let entry = entry {
            viewModel.updateEntry(entry.id, ipAddress: ip, hostnames: hostnames, comment: finalComment)
            if selectedGroupId != groupId {
                viewModel.moveEntry(entry.id, toGroup: selectedGroupId)
            }
        } else {
            viewModel.addEntry(ipAddress: ip, hostnames: hostnames, comment: finalComment, toGroup: selectedGroupId)
        }
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
