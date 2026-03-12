import SwiftUI
import AppKit

struct FileVersion: Identifiable, Comparable {
    let id = UUID()
    let name: String
    let path: String
    let date: Date
    let fileSize: Int64

    static func < (lhs: FileVersion, rhs: FileVersion) -> Bool {
        lhs.date > rhs.date
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

struct RevisionsView: View {
    @ObservedObject private var revisionRequest = RevisionRequest.shared
    @State private var droppedFilePath: String?
    @State private var droppedFileName: String?
    @State private var versions: [FileVersion] = []
    @State private var errorMessage: String?
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revisions")
                .font(.headline)

            Text("Drag and drop a file to see its version history.")
                .font(.caption)
                .foregroundColor(.secondary)

            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(isTargeted ? .accentColor : .secondary.opacity(0.4))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                    )

                if let fileName = droppedFileName {
                    VStack(spacing: 4) {
                        Image(systemName: "doc")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        Text(fileName)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("Drop another file to replace")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Drop a file here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 120)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }

            .onReceive(revisionRequest.$filePath) { path in
                guard let path = path else { return }
                let fm = FileManager.default
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else { return }
                droppedFilePath = path
                droppedFileName = (path as NSString).lastPathComponent
                loadVersions(for: path)
                revisionRequest.filePath = nil
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if droppedFilePath != nil {
                if versions.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("No versions found for this file.")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    Spacer()
                } else {
                    List(versions) { version in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(version.name)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Text(version.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(version.date, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(version.formattedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .trailing)

                            Button("Show in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting(
                                    [URL(fileURLWithPath: version.path)]
                                )
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Restore") {
                                restoreVersion(version)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.bordered)

                    Text("\(versions.count) version(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        errorMessage = nil
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }

                DispatchQueue.main.async {
                    let path = url.path
                    let fm = FileManager.default
                    var isDir: ObjCBool = false

                    guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
                        errorMessage = "Please drop a file, not a directory."
                        return
                    }

                    droppedFilePath = path
                    droppedFileName = (path as NSString).lastPathComponent
                    loadVersions(for: path)
                }
            }
            break // only handle first file
        }
    }

    private func loadVersions(for filePath: String) {
        let fm = FileManager.default
        let fileName = (filePath as NSString).lastPathComponent
        let parentDir = (filePath as NSString).deletingLastPathComponent
        let versionsDir = (parentDir as NSString).appendingPathComponent(".revisibility")
        let fileVersionsDir = (versionsDir as NSString).appendingPathComponent(fileName)

        guard fm.fileExists(atPath: fileVersionsDir) else {
            versions = []
            errorMessage = "No .revisibility directory found for this file."
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        var result: [FileVersion] = []

        guard let items = try? fm.contentsOfDirectory(atPath: fileVersionsDir) else {
            versions = []
            return
        }

        for item in items {
            guard !item.hasPrefix(".") else { continue }
            let fullPath = (fileVersionsDir as NSString).appendingPathComponent(item)

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue else {
                continue
            }

            let attrs = try? fm.attributesOfItem(atPath: fullPath)
            let fileSize = (attrs?[.size] as? Int64) ?? 0
            var nameOnly = (item as NSString).deletingPathExtension

            // Strip _revisibility suffix for timestamp parsing
            if nameOnly.hasSuffix("_revisibility") {
                nameOnly = String(nameOnly.dropLast("_revisibility".count))
            }

            if nameOnly.count >= 19 {
                let timestampStart = nameOnly.index(nameOnly.endIndex, offsetBy: -19)
                let timestamp = String(nameOnly[timestampStart...])
                if let date = dateFormatter.date(from: timestamp) {
                    result.append(FileVersion(name: item, path: fullPath, date: date, fileSize: fileSize))
                    continue
                }
            }

            if let modDate = attrs?[.modificationDate] as? Date {
                result.append(FileVersion(name: item, path: fullPath, date: modDate, fileSize: fileSize))
            }
        }

        versions = result.sorted()
        errorMessage = nil
    }

    private func restoreVersion(_ version: FileVersion) {
        guard let originalPath = droppedFilePath else { return }
        let fm = FileManager.default
        let parentDir = (originalPath as NSString).deletingLastPathComponent
        let originalName = (originalPath as NSString).lastPathComponent
        let nameWithoutExt = (originalName as NSString).deletingPathExtension
        let ext = (originalName as NSString).pathExtension

        // Parse the version's timestamp from its name
        let versionNameOnly = (version.name as NSString).deletingPathExtension
        // Strip _revisibility suffix if present to get the timestamp
        let stripped = versionNameOnly.hasSuffix("_revisibility")
            ? String(versionNameOnly.dropLast("_revisibility".count))
            : versionNameOnly
        var timestamp = ""
        if stripped.count >= 19 {
            let start = stripped.index(stripped.endIndex, offsetBy: -19)
            timestamp = String(stripped[start...])
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            timestamp = formatter.string(from: version.date)
        }

        var restoredName: String
        if ext.isEmpty {
            restoredName = "\(nameWithoutExt)_\(timestamp)_revisibility"
        } else {
            restoredName = "\(nameWithoutExt)_\(timestamp)_revisibility.\(ext)"
        }

        let destPath = (parentDir as NSString).appendingPathComponent(restoredName)

        // Avoid overwriting
        guard !fm.fileExists(atPath: destPath) else {
            errorMessage = "File \(restoredName) already exists in the original directory."
            return
        }

        do {
            try fm.copyItem(atPath: version.path, toPath: destPath)
            errorMessage = nil
            // Reveal in Finder
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: destPath)])
        } catch {
            errorMessage = "Failed to restore: \(error.localizedDescription)"
        }
    }
}
