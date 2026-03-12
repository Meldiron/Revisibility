import Foundation
import Combine

class DirectoryStore: ObservableObject {
    @Published var directories: [String] = []

    private let userDefaultsKey = "watchedDirectories"

    init() {
        directories = UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }

    func addDirectory(_ path: String) {
        guard !directories.contains(path) else { return }
        directories.append(path)
        save()
    }

    func removeDirectory(_ path: String) {
        directories.removeAll { $0 == path }
        save()
    }

    func removeDirectories(at offsets: IndexSet) {
        directories.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        UserDefaults.standard.set(directories, forKey: userDefaultsKey)
    }
}
