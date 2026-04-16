import SwiftUI

struct GroupHeaderRow: View {
    let group: HostGroup
    @Binding var isExpanded: Bool
    @Bindable var viewModel: HostsViewModel
    var onAddEntry: () -> Void = {}
    @State private var isHovered = false

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

            // Group name
            Text(group.name)
                .font(.system(size: 13, weight: .semibold))

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

            // Hover action: add entry to group (always present, visibility via opacity)
            Button {
                onAddEntry()
            } label: {
                Image(systemName: "plus")
                    .font(.caption2)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
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
                viewModel.editingGroup = group
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
}
