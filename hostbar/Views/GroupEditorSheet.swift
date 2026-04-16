import SwiftUI

struct GroupEditorSheet: View {
    @Bindable var viewModel: HostsViewModel
    let group: HostGroup?

    @State private var name = ""
    @FocusState private var isNameFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { group != nil }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Rename Group" : "New Group")
                .font(.headline)

            TextField("Group Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFocused)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Save" : "Create") {
                    saveGroup()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 260)
        .onAppear {
            if let group = group {
                name = group.name
            }
            isNameFocused = true
        }
    }

    private func saveGroup() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let group = group {
            viewModel.renameGroup(group.id, to: trimmedName)
        } else {
            viewModel.addGroup(name: trimmedName)
        }
    }
}
