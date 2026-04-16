import Foundation
import SwiftUI

@Observable
final class HostsViewModel {
    var hostsFile: HostsFile = .empty
    var hasUnsavedChanges = false
    var errorMessage: String?
    var showError = false
    var isSaving = false
    var showAddEntry = false
    var showAddGroup = false
    var editingEntry: HostEntry?
    var editingGroup: HostGroup?

    private let parser = HostsFileParser()
    private let writer = HostsFileWriter()
    private let privilegedWriter = PrivilegedWriter()
    private let metadataStore = GroupMetadataStore()
    private let hostsPath = "/etc/hosts"
    private var fileMonitor: DispatchSourceFileSystemObject?

    func load() {
        do {
            hostsFile = try parser.parseFromFile(at: hostsPath)
            hasUnsavedChanges = false
            startFileMonitoring()
        } catch {
            showErrorMessage("Failed to read hosts file: \(error.localizedDescription)")
        }
    }

    func save() async {
        isSaving = true
        defer { isSaving = false }

        let content = writer.serialize(hostsFile)
        do {
            try await privilegedWriter.writeHostsFile(content: content, to: hostsPath)
            hasUnsavedChanges = false
            metadataStore.save(hostsFile)
        } catch HostBarError.userCancelled {
            // User cancelled auth dialog, do nothing
        } catch {
            showErrorMessage(error.localizedDescription)
        }
    }

    // MARK: - Entry Operations

    func toggleEntry(_ entryId: UUID) {
        for i in hostsFile.sections.indices {
            switch hostsFile.sections[i] {
            case .group(var group):
                if let j = group.entries.firstIndex(where: { $0.id == entryId }) {
                    group.entries[j].isEnabled.toggle()
                    hostsFile.sections[i] = .group(group)
                    hasUnsavedChanges = true
                    return
                }
            case .ungroupedEntry(var entry):
                if entry.id == entryId {
                    entry.isEnabled.toggle()
                    hostsFile.sections[i] = .ungroupedEntry(entry)
                    hasUnsavedChanges = true
                    return
                }
            case .rawLine:
                continue
            }
        }
    }

    func toggleGroup(_ groupId: UUID) {
        for i in hostsFile.sections.indices {
            if case .group(var group) = hostsFile.sections[i], group.id == groupId {
                let newState = !group.isAllEnabled
                for j in group.entries.indices {
                    group.entries[j].isEnabled = newState
                }
                hostsFile.sections[i] = .group(group)
                hasUnsavedChanges = true
                return
            }
        }
    }

    func addEntry(ipAddress: String, hostnames: [String], comment: String?, toGroup groupId: UUID?) {
        let entry = HostEntry(ipAddress: ipAddress, hostnames: hostnames, isEnabled: true, comment: comment)

        if let groupId = groupId {
            for i in hostsFile.sections.indices {
                if case .group(var group) = hostsFile.sections[i], group.id == groupId {
                    group.entries.append(entry)
                    hostsFile.sections[i] = .group(group)
                    hasUnsavedChanges = true
                    return
                }
            }
        }

        // Add as ungrouped entry before any trailing raw lines
        let insertIndex = hostsFile.sections.endIndex
        hostsFile.sections.insert(.ungroupedEntry(entry), at: insertIndex)
        hasUnsavedChanges = true
    }

    func updateEntry(_ entryId: UUID, ipAddress: String, hostnames: [String], comment: String?) {
        for i in hostsFile.sections.indices {
            switch hostsFile.sections[i] {
            case .group(var group):
                if let j = group.entries.firstIndex(where: { $0.id == entryId }) {
                    group.entries[j].ipAddress = ipAddress
                    group.entries[j].hostnames = hostnames
                    group.entries[j].comment = comment
                    hostsFile.sections[i] = .group(group)
                    hasUnsavedChanges = true
                    return
                }
            case .ungroupedEntry(var entry):
                if entry.id == entryId {
                    entry.ipAddress = ipAddress
                    entry.hostnames = hostnames
                    entry.comment = comment
                    hostsFile.sections[i] = .ungroupedEntry(entry)
                    hasUnsavedChanges = true
                    return
                }
            case .rawLine:
                continue
            }
        }
    }

    func deleteEntry(_ entryId: UUID) {
        for i in hostsFile.sections.indices {
            switch hostsFile.sections[i] {
            case .group(var group):
                if let j = group.entries.firstIndex(where: { $0.id == entryId }) {
                    group.entries.remove(at: j)
                    if group.entries.isEmpty {
                        hostsFile.sections.remove(at: i)
                    } else {
                        hostsFile.sections[i] = .group(group)
                    }
                    hasUnsavedChanges = true
                    return
                }
            case .ungroupedEntry(let entry):
                if entry.id == entryId {
                    hostsFile.sections.remove(at: i)
                    hasUnsavedChanges = true
                    return
                }
            case .rawLine:
                continue
            }
        }
    }

    func moveEntry(_ entryId: UUID, toGroup targetGroupId: UUID?) {
        // Find and remove the entry from its current location
        var movedEntry: HostEntry?

        for i in hostsFile.sections.indices {
            switch hostsFile.sections[i] {
            case .group(var group):
                if let j = group.entries.firstIndex(where: { $0.id == entryId }) {
                    movedEntry = group.entries.remove(at: j)
                    if group.entries.isEmpty {
                        hostsFile.sections.remove(at: i)
                    } else {
                        hostsFile.sections[i] = .group(group)
                    }
                    break
                }
            case .ungroupedEntry(let entry):
                if entry.id == entryId {
                    movedEntry = entry
                    hostsFile.sections.remove(at: i)
                    break
                }
            case .rawLine:
                continue
            }
            if movedEntry != nil { break }
        }

        guard let entry = movedEntry else { return }

        // Add to target group or as ungrouped
        if let targetGroupId = targetGroupId {
            for i in hostsFile.sections.indices {
                if case .group(var group) = hostsFile.sections[i], group.id == targetGroupId {
                    group.entries.append(entry)
                    hostsFile.sections[i] = .group(group)
                    hasUnsavedChanges = true
                    return
                }
            }
        }

        hostsFile.sections.append(.ungroupedEntry(entry))
        hasUnsavedChanges = true
    }

    // MARK: - Group Operations

    func addGroup(name: String) {
        let group = HostGroup(name: name)
        hostsFile.sections.append(.group(group))
        hasUnsavedChanges = true
    }

    func moveGroup(_ groupId: UUID, beforeSection targetSectionId: UUID?) {
        guard let sourceIndex = hostsFile.sections.firstIndex(where: {
            if case .group(let g) = $0 { return g.id == groupId }
            return false
        }) else { return }

        let section = hostsFile.sections.remove(at: sourceIndex)

        if let targetId = targetSectionId,
           let targetIndex = hostsFile.sections.firstIndex(where: { $0.id == targetId }) {
            hostsFile.sections.insert(section, at: targetIndex)
        } else {
            hostsFile.sections.append(section)
        }
        hasUnsavedChanges = true
    }

    func renameGroup(_ groupId: UUID, to newName: String) {
        for i in hostsFile.sections.indices {
            if case .group(var group) = hostsFile.sections[i], group.id == groupId {
                group.name = newName
                hostsFile.sections[i] = .group(group)
                hasUnsavedChanges = true
                return
            }
        }
    }

    func deleteGroup(_ groupId: UUID, keepEntries: Bool = true) {
        for i in hostsFile.sections.indices {
            if case .group(let group) = hostsFile.sections[i], group.id == groupId {
                if keepEntries {
                    // Move entries to ungrouped
                    let ungroupedSections = group.entries.map { HostsFile.Section.ungroupedEntry($0) }
                    hostsFile.sections.replaceSubrange(i...i, with: ungroupedSections)
                } else {
                    hostsFile.sections.remove(at: i)
                }
                hasUnsavedChanges = true
                return
            }
        }
    }

    // MARK: - Private

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func startFileMonitoring() {
        fileMonitor?.cancel()

        let fd = open(hostsPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self = self, !self.isSaving else { return }
            if !self.hasUnsavedChanges {
                self.load()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileMonitor = source
    }

    deinit {
        fileMonitor?.cancel()
    }
}
