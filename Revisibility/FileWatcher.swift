import Foundation
import Combine

class FileWatcher {
    private let directoryStore: DirectoryStore
    private var cancellable: AnyCancellable?
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private var timers: [String: DispatchSourceTimer] = [:]
    private var fileSnapshots: [String: [String: Date]] = [:]
    private var debounceTimers: [String: DispatchWorkItem] = [:]

    private let versionsDirectoryName = ".revisibility"
    private let queue = DispatchQueue(label: "com.revisibility.filewatcher", qos: .utility)

    init(directoryStore: DirectoryStore) {
        self.directoryStore = directoryStore
    }

    func startWatching() {
        // React to directory list changes
        cancellable = directoryStore.$directories
            .sink { [weak self] directories in
                self?.updateWatchers(for: directories)
            }
    }

    private func updateWatchers(for directories: [String]) {
        // Remove watchers for directories no longer in the list
        let currentPaths = Set(sources.keys)
        let newPaths = Set(directories)

        for removed in currentPaths.subtracting(newPaths) {
            sources[removed]?.cancel()
            sources.removeValue(forKey: removed)
            timers[removed]?.cancel()
            timers.removeValue(forKey: removed)
            fileSnapshots.removeValue(forKey: removed)
        }

        // Add watchers for new directories
        for added in newPaths.subtracting(currentPaths) {
            watchDirectory(at: added)
        }
    }

    private func watchDirectory(at path: String) {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            print("Failed to open directory for watching: \(path)")
            return
        }

        // Take initial snapshot
        fileSnapshots[path] = snapshotDirectory(at: path)

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.handleDirectoryChange(at: path)
        }

        source.setCancelHandler {
            close(fd)
        }

        sources[path] = source
        source.resume()

        // Also set up a periodic poll as a fallback (some editors do atomic saves
        // that don't trigger the dispatch source reliably)
        startPolling(for: path)
    }

    private func startPolling(for path: String) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2.0)
        timer.setEventHandler { [weak self] in
            self?.handleDirectoryChange(at: path)
        }
        timer.resume()
        timers[path] = timer
    }

    private func handleDirectoryChange(at directoryPath: String) {
        let currentSnapshot = snapshotDirectory(at: directoryPath)
        let previousSnapshot = fileSnapshots[directoryPath] ?? [:]

        for (fileName, modDate) in currentSnapshot {
            let previousDate = previousSnapshot[fileName]
            if previousDate == nil || previousDate! < modDate {
                // File is new or modified
                let filePath = (directoryPath as NSString).appendingPathComponent(fileName)
                debouncedVersionFile(at: filePath, in: directoryPath)
            }
        }

        fileSnapshots[directoryPath] = currentSnapshot
    }

    private func debouncedVersionFile(at filePath: String, in directoryPath: String) {
        // Cancel any pending debounce for this file
        debounceTimers[filePath]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.versionFile(at: filePath, in: directoryPath)
            self?.debounceTimers.removeValue(forKey: filePath)
        }

        debounceTimers[filePath] = workItem
        queue.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func snapshotDirectory(at path: String) -> [String: Date] {
        var snapshot: [String: Date] = [:]
        let fm = FileManager.default

        guard let items = try? fm.contentsOfDirectory(atPath: path) else {
            return snapshot
        }

        for item in items {
            // Skip hidden files and the versions directory
            if item.hasPrefix(".") { continue }

            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue else {
                continue
            }

            if let attrs = try? fm.attributesOfItem(atPath: fullPath),
               let modDate = attrs[.modificationDate] as? Date {
                snapshot[item] = modDate
            }
        }

        return snapshot
    }

    private func versionFile(at filePath: String, in directoryPath: String) {
        let fm = FileManager.default
        let fileName = (filePath as NSString).lastPathComponent

        // Don't version hidden files
        guard !fileName.hasPrefix(".") else { return }

        // Don't version restored files (they end with _revisibility before extension)
        let nameCheck = (fileName as NSString).deletingPathExtension
        guard !nameCheck.hasSuffix("_revisibility") else { return }

        // Make sure the file still exists and is not a directory
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: filePath, isDirectory: &isDir), !isDir.boolValue else {
            return
        }

        // Create versions subdirectory per file: .revisibility/<filename>/
        let versionsBase = (directoryPath as NSString).appendingPathComponent(versionsDirectoryName)
        let fileSubdir = (versionsBase as NSString).appendingPathComponent(fileName)
        try? fm.createDirectory(atPath: fileSubdir, withIntermediateDirectories: true)

        // Build versioned filename: name_2026-03-12_14-30-45.ext
        let nameWithoutExt = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        var versionedName: String
        if ext.isEmpty {
            versionedName = "\(nameWithoutExt)_\(timestamp)_revisibility"
        } else {
            versionedName = "\(nameWithoutExt)_\(timestamp)_revisibility.\(ext)"
        }

        let destPath = (fileSubdir as NSString).appendingPathComponent(versionedName)

        // Don't overwrite if somehow same-second version exists
        guard !fm.fileExists(atPath: destPath) else { return }

        do {
            try fm.copyItem(atPath: filePath, toPath: destPath)
            print("Versioned: \(fileName) → \(versionedName)")
        } catch {
            print("Failed to version \(fileName): \(error.localizedDescription)")
        }
    }
}
