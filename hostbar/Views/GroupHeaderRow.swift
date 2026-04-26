import SwiftUI

struct GroupHeaderRow: View {
    let group: HostGroup
    @Binding var isExpanded: Bool
    @Bindable var viewModel: HostsViewModel
    var onAddEntry: () -> Void = {}
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedName = ""

    var body: some View {
        HStack(spacing: 8) {
            // Disclosure triangle with rotation animation
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 14)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .buttonStyle(.plain)

            // Folder icon
            Image(systemName: "folder.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Group name / Inline Editor
            if isEditing {
                HStack(spacing: 4) {
                    InlineTextField(
                        text: $editedName,
                        placeholder: "Group name",
                        onCommit: commitRename,
                        onCancel: cancelRename
                    )
                    .frame(maxWidth: 200)

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
                Text(group.name)
                    .font(.system(size: 13, weight: .semibold))
            }

            // Entry count badge
            Text("\(group.enabledCount)/\(group.entries.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(.secondary.opacity(0.1))
                )

            Spacer()

            // Hover actions: rename + add entry
            HStack(spacing: 2) {
                Button {
                    editedName = group.name
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    onAddEntry()
                } label: {
                    Image(systemName: "plus")
                        .font(.caption2)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .opacity(isHovered ? 1 : 0)

            // Group toggle
            Toggle("", isOn: Binding(
                get: { group.isAllEnabled },
                set: { _ in viewModel.toggleGroup(group.id) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(isHovered ? 0.1 : 0.06))
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Rename...") {
                editedName = group.name
                isEditing = true
            }

            Button("Add Entry to Group...") {
                onAddEntry()
            }

            Divider()

            Button("Delete Group (keep entries)") {
                viewModel.deleteGroup(group.id, keepEntries: true)
            }

            Button("Delete Group and Entries", role: .destructive) {
                viewModel.deleteGroup(group.id, keepEntries: false)
            }
        }
        .accessibilityLabel("Group \(group.name), \(group.enabledCount) of \(group.entries.count) enabled, \(isExpanded ? "expanded" : "collapsed")")
        .accessibilityAction(named: "Toggle All") {
            viewModel.toggleGroup(group.id)
        }
    }

    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            viewModel.renameGroup(group.id, to: trimmed)
        }
        isEditing = false
    }

    private func cancelRename() {
        isEditing = false
    }
}
