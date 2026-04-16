import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// NSTextField wrapper to properly handle keyboard input in MenuBarExtra
private struct FocusableTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.font = NSFont.systemFont(ofSize: 12)
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

struct MenuBarView: View {
    @Bindable var viewModel: HostsViewModel
    @State private var contentHeight: CGFloat = 0
    @State private var searchText = ""
    @State private var showSaveSuccess = false
    @State private var isAddingGroup = false
    @State private var renamingGroup: HostGroup?
    private let maxContentHeight: CGFloat = 520

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            VStack(spacing: 6) {
                HStack {
                    Text("HostBar")
                        .font(.headline)

                    Spacer()

                    Button(action: { isAddingGroup = true }) {
                        Image(systemName: "folder.badge.plus")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.borderless)
                    .help("Add Group")
                    .accessibilityLabel("Add Group")
                }

                // Search field
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FocusableTextField(placeholder: "Filter hosts...", text: $searchText)
                        .frame(height: 18)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Inline add group form
            if isAddingGroup {
                InlineAddGroupRow(viewModel: viewModel) {
                    isAddingGroup = false
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
            }

            if let group = renamingGroup {
                InlineRenameGroupRow(viewModel: viewModel, group: group) {
                    renamingGroup = nil
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
            }

            // Content
            if viewModel.hostsFile.sections.isEmpty && !isAddingGroup {
                ContentUnavailableView {
                    Label("No Host Entries", systemImage: "server.rack")
                } description: {
                    Text("Add entries to manage your /etc/hosts file")
                }
                .frame(height: 150)
            } else if contentHeight > 0 && contentHeight <= maxContentHeight {
                HostListView(viewModel: viewModel, searchText: searchText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                        }
                    )
            } else {
                ScrollView {
                    HostListView(viewModel: viewModel, searchText: searchText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                            }
                        )
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: maxContentHeight)
            }

            Divider()

            // Footer
            HStack(spacing: 6) {
                if viewModel.hasUnsavedChanges {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                        .opacity(pulseOpacity)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: viewModel.hasUnsavedChanges)
                    Text("\(viewModel.hostsFile.allEntries.count) entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if showSaveSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()

                if viewModel.isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }

                Button("Apply") {
                    Task {
                        await viewModel.save()
                        showSaveSuccess = true
                        try? await Task.sleep(for: .seconds(1.5))
                        showSaveSuccess = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(width: 420)
        .onPreferenceChange(ContentHeightKey.self) { height in
            contentHeight = height
        }
        .onAppear {
            viewModel.load()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .onChange(of: viewModel.showAddGroup) { _, newValue in
            if newValue {
                isAddingGroup = true
                viewModel.showAddGroup = false
            }
        }
        .onChange(of: viewModel.editingGroup) { _, newValue in
            if let group = newValue {
                renamingGroup = group
                viewModel.editingGroup = nil
            }
        }
    }

    private var pulseOpacity: Double {
        viewModel.hasUnsavedChanges ? 0.6 : 1.0
    }
}

// MARK: - Inline Add Group

private struct InlineAddGroupRow: View {
    @Bindable var viewModel: HostsViewModel
    let onDismiss: () -> Void

    @State private var name = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                InlineTextField(text: $name, placeholder: "New group name")
            }
            HStack {
                Spacer()
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Button("Create") {
                    viewModel.addGroup(name: name.trimmingCharacters(in: .whitespaces))
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
}

// MARK: - Inline Rename Group

private struct InlineRenameGroupRow: View {
    @Bindable var viewModel: HostsViewModel
    let group: HostGroup
    let onDismiss: () -> Void

    @State private var name = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                InlineTextField(text: $name, placeholder: "Group name")
            }
            HStack {
                Spacer()
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Button("Save") {
                    viewModel.renameGroup(group.id, to: name.trimmingCharacters(in: .whitespaces))
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
        .onAppear {
            name = group.name
        }
    }
}
