import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject var directoryStore: DirectoryStore
    @State private var selection: String?
    @State private var selectedTab: Int

    init(directoryStore: DirectoryStore, initialTab: Int? = nil) {
        self.directoryStore = directoryStore
        self._selectedTab = State(initialValue: initialTab ?? 0)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DirectoriesTab(directoryStore: directoryStore, selection: $selection)
                .tabItem {
                    Label("Directories", systemImage: "folder")
                }
                .tag(0)

            AuditView(directoryStore: directoryStore)
                .tabItem {
                    Label("Audit", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)

            RevisionsView()
                .tabItem {
                    Label("Revisions", systemImage: "arrow.uturn.backward.circle")
                }
                .tag(2)

            PermissionsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
                .tag(3)
        }
        .frame(minWidth: 550, minHeight: 400)
        .padding()
    }
}

struct DirectoriesTab: View {
    @ObservedObject var directoryStore: DirectoryStore
    @Binding var selection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Watched Directories")
                .font(.headline)

            Text("Files in these directories will be automatically versioned when modified.")
                .font(.caption)
                .foregroundColor(.secondary)

            List(selection: $selection) {
                ForEach(directoryStore.directories, id: \.self) { dir in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                        Text(dir)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .tag(dir)
                }
                .onDelete { offsets in
                    directoryStore.removeDirectories(at: offsets)
                }
            }
            .listStyle(.bordered)

            HStack(spacing: 4) {
                Button(action: addDirectory) {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                }

                Button(action: removeSelected) {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 24)
                }
                .disabled(selection == nil)

                Spacer()
            }
        }
    }

    private func addDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a directory to watch"

        if panel.runModal() == .OK, let url = panel.url {
            directoryStore.addDirectory(url.path)
        }
    }

    private func removeSelected() {
        if let sel = selection {
            directoryStore.removeDirectory(sel)
            selection = nil
        }
    }
}
