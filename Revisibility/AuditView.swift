import SwiftUI
import AppKit

struct VersionedFile: Identifiable, Comparable {
    let id = UUID()
    let name: String
    let path: String
    let date: Date
    let fileSize: Int64
    let sourceDirectory: String

    static func < (lhs: VersionedFile, rhs: VersionedFile) -> Bool {
        lhs.date > rhs.date // newest first
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

struct AuditView: View {
    @ObservedObject var directoryStore: DirectoryStore
    @State private var files: [VersionedFile] = []
    @State private var searchText = ""
    @State private var selectedDirectory = "All"

    private var directoryOptions: [String] {
        ["All"] + directoryStore.directories
    }

    var filteredFiles: [VersionedFile] {
        var result = files
        if selectedDirectory != "All" {
            result = result.filter { $0.sourceDirectory == selectedDirectory }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Version History")
                .font(.headline)

            Text("All file versions created by Revisibility.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                TextField("Search files…", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("Directory:", selection: $selectedDirectory) {
                    ForEach(directoryOptions, id: \.self) { dir in
                        Text(dir == "All" ? "All Directories" : (dir as NSString).lastPathComponent)
                            .tag(dir)
                    }
                }
                .frame(maxWidth: 200)
            }

            if filteredFiles.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text(files.isEmpty ? "No versioned files yet." : "No matching files.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                List(filteredFiles) { file in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(file.sourceDirectory)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Text(file.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(file.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)

                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting(
                                [URL(fileURLWithPath: file.path)]
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.bordered)
            }

            HStack {
                Text("\(filteredFiles.count) versioned file(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Refresh") {
                    loadFiles()
                }
                .controlSize(.small)
            }
        }
        .onAppear {
            loadFiles()
        }
    }

    private func loadFiles() {
        var result: [VersionedFile] = []
        let fm = FileManager.default
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        for dir in directoryStore.directories {
            let versionsBase = (dir as NSString).appendingPathComponent(".revisibility")
            // Each original file has its own subdirectory
            guard let subdirs = try? fm.contentsOfDirectory(atPath: versionsBase) else {
                continue
            }

            for subdir in subdirs {
                guard !subdir.hasPrefix(".") else { continue }
                let subdirPath = (versionsBase as NSString).appendingPathComponent(subdir)

                var isDirFlag: ObjCBool = false
                guard fm.fileExists(atPath: subdirPath, isDirectory: &isDirFlag), isDirFlag.boolValue else {
                    continue
                }

                guard let versionFiles = try? fm.contentsOfDirectory(atPath: subdirPath) else {
                    continue
                }

                for item in versionFiles {
                    guard !item.hasPrefix(".") else { continue }
                    let fullPath = (subdirPath as NSString).appendingPathComponent(item)

                    var isFile: ObjCBool = false
                    guard fm.fileExists(atPath: fullPath, isDirectory: &isFile), !isFile.boolValue else {
                        continue
                    }

                    var nameOnly = (item as NSString).deletingPathExtension
                    let attrs = try? fm.attributesOfItem(atPath: fullPath)
                    let fileSize = (attrs?[.size] as? Int64) ?? 0

                    // Strip _revisibility suffix for timestamp parsing
                    if nameOnly.hasSuffix("_revisibility") {
                        nameOnly = String(nameOnly.dropLast("_revisibility".count))
                    }

                    if nameOnly.count >= 19 {
                        let timestampStart = nameOnly.index(nameOnly.endIndex, offsetBy: -19)
                        let timestamp = String(nameOnly[timestampStart...])
                        if let date = dateFormatter.date(from: timestamp) {
                            result.append(VersionedFile(
                                name: item,
                                path: fullPath,
                                date: date,
                                fileSize: fileSize,
                                sourceDirectory: dir
                            ))
                            continue
                        }
                    }

                    // Fallback: use file modification date
                    if let modDate = attrs?[.modificationDate] as? Date {
                        result.append(VersionedFile(
                            name: item,
                            path: fullPath,
                            date: modDate,
                            fileSize: fileSize,
                            sourceDirectory: dir
                        ))
                    }
                }
            }
        }

        files = result.sorted()
    }
}
