import SwiftUI
import ServiceManagement

@main
struct RevisibilityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var preferencesWindow: NSWindow?
    let directoryStore = DirectoryStore()
    var fileWatcher: FileWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Register as service provider
        NSApp.servicesProvider = self

        // Register as login item (start at boot)
        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = createMenuBarIcon()
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Revisibility", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu

        fileWatcher = FileWatcher(directoryStore: directoryStore)
        fileWatcher?.startWatching()

        // Install Quick Action for Finder right-click integration
        installQuickAction()
        NSUpdateDynamicServices()
    }

    private func installQuickAction() {
        let fm = FileManager.default
        let servicesDir = NSHomeDirectory() + "/Library/Services"
        let workflowDir = servicesDir + "/Revisibility.workflow/Contents"

        // Only install if not already present
        guard !fm.fileExists(atPath: workflowDir + "/document.wflow") else { return }

        try? fm.createDirectory(atPath: workflowDir, withIntermediateDirectories: true)

        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>NSServices</key>
            <array>
                <dict>
                    <key>NSMenuItem</key>
                    <dict>
                        <key>default</key>
                        <string>Revisibility</string>
                    </dict>
                    <key>NSMessage</key>
                    <string>runWorkflowAsService</string>
                    <key>NSSendFileTypes</key>
                    <array>
                        <string>public.item</string>
                    </array>
                </dict>
            </array>
        </dict>
        </plist>
        """

        let wflow = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>AMApplicationBuild</key><string>523</string>
            <key>AMApplicationVersion</key><string>2.10</string>
            <key>AMDocumentVersion</key><string>2</string>
            <key>actions</key>
            <array>
                <dict>
                    <key>action</key>
                    <dict>
                        <key>AMAccepts</key><dict><key>Container</key><string>List</string><key>Optional</key><false/><key>Types</key><array><string>com.apple.cocoa.path</string></array></dict>
                        <key>AMActionVersion</key><string>1.0.2</string>
                        <key>AMApplication</key><array><string>Automator</string></array>
                        <key>AMBundleIdentifier</key><string>com.apple.RunShellScript</string>
                        <key>AMCategory</key><array><string>AMCategoryUtilities</string></array>
                        <key>AMIconName</key><string>RunShellScript</string>
                        <key>AMName</key><string>Run Shell Script</string>
                        <key>AMProvides</key><dict><key>Container</key><string>List</string><key>Types</key><array><string>com.apple.cocoa.path</string></array></dict>
                        <key>ActionBundlePath</key><string>/System/Library/Automator/Run Shell Script.action</string>
                        <key>ActionName</key><string>Run Shell Script</string>
                        <key>ActionParameters</key>
                        <dict>
                            <key>COMMAND_STRING</key>
                            <string>for f in "$@"; do encoded=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$f"); open "revisibility://open?file=$encoded"; break; done</string>
                            <key>CheckedForUserDefaultShell</key><true/>
                            <key>inputMethod</key><integer>1</integer>
                            <key>shell</key><string>/bin/zsh</string>
                            <key>source</key><string></string>
                        </dict>
                        <key>BundleIdentifier</key><string>com.apple.RunShellScript</string>
                        <key>CFBundleVersion</key><string>1.0.2</string>
                        <key>CanShowSelectedItemsWhenRun</key><false/>
                        <key>CanShowWhenRun</key><true/>
                        <key>Category</key><array><string>AMCategoryUtilities</string></array>
                        <key>Class Name</key><string>RunShellScriptAction</string>
                        <key>InputUUID</key><string>A1B2C3D4-E5F6-7890-ABCD-EF1234567890</string>
                        <key>OutputUUID</key><string>B2C3D4E5-F6A7-8901-BCDE-F12345678901</string>
                        <key>UUID</key><string>C3D4E5F6-A7B8-9012-CDEF-123456789012</string>
                        <key>UnlocalizedApplications</key><array><string>Automator</string></array>
                    </dict>
                </dict>
            </array>
            <key>connectors</key><dict/>
            <key>workflowMetaData</key><dict><key>workflowTypeIdentifier</key><string>com.apple.Automator.servicesMenu</string></dict>
        </dict>
        </plist>
        """

        try? infoPlist.write(toFile: workflowDir + "/Info.plist", atomically: true, encoding: .utf8)
        try? wflow.write(toFile: workflowDir + "/document.wflow", atomically: true, encoding: .utf8)
    }

    // MARK: - Service handler (right-click > Services > Revisibility)

    @objc func openFileRevisions(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let items = pboard.pasteboardItems else { return }

        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString) {
                openRevisionsForFile(at: url.path)
                return
            }
        }
    }

    // MARK: - URL scheme handler (revisibility://open?file=/path/to/file)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "revisibility" else { continue }
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let fileParam = components.queryItems?.first(where: { $0.name == "file" })?.value {
                openRevisionsForFile(at: fileParam)
                return
            }
        }
    }

    // MARK: - Open Revisions tab with a specific file

    private func openRevisionsForFile(at path: String) {
        RevisionRequest.shared.requestRevision(for: path)
        openPreferencesToRevisionsTab()
    }

    @objc func openPreferences() {
        openPreferencesWindow(selectedTab: nil)
    }

    private func openPreferencesToRevisionsTab() {
        openPreferencesWindow(selectedTab: 2) // 0=Directories, 1=Audit, 2=Revisions
    }

    private func openPreferencesWindow(selectedTab: Int?) {
        // Always recreate so we get fresh state with the right tab
        let preferencesView = PreferencesView(
            directoryStore: directoryStore,
            initialTab: selectedTab
        )

        if let window = preferencesWindow {
            window.contentView = NSHostingView(rootView: preferencesView)
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 550, height: 450),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Revisibility Preferences"
            window.contentView = NSHostingView(rootView: preferencesView)
            window.center()
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            preferencesWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func createMenuBarIcon() -> NSImage {
        let s: CGFloat = 18
        let img = NSImage(size: NSSize(width: s, height: s))
        img.lockFocus()

        let color = NSColor.black
        let cx = s * 0.5, cy = s * 0.5
        let radius = s * 0.42
        let stroke: CGFloat = 1.4

        color.setStroke()
        let arc = NSBezierPath()
        arc.lineWidth = stroke
        arc.lineCapStyle = .round
        arc.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: radius,
                      startAngle: 50, endAngle: 340, clockwise: false)
        arc.stroke()

        color.setFill()
        let arrowAngle = 50.0 * CGFloat.pi / 180.0
        let ax = cx + radius * CoreGraphics.cos(arrowAngle)
        let ay = cy + radius * CoreGraphics.sin(arrowAngle)
        let asz: CGFloat = 3.5
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: ax + asz, y: ay + asz * 0.3))
        arrow.line(to: NSPoint(x: ax - asz * 0.4, y: ay + asz))
        arrow.line(to: NSPoint(x: ax - asz * 0.4, y: ay - asz * 0.4))
        arrow.close()
        arrow.fill()

        let hourEnd = NSPoint(x: cx + 1.0, y: cy + radius * 0.5)
        let hour = NSBezierPath()
        hour.lineWidth = 1.6
        hour.lineCapStyle = .round
        hour.move(to: NSPoint(x: cx, y: cy))
        hour.line(to: hourEnd)
        hour.stroke()

        let minEnd = NSPoint(x: cx + radius * 0.52, y: cy - 0.8)
        let minute = NSBezierPath()
        minute.lineWidth = 1.3
        minute.lineCapStyle = .round
        minute.move(to: NSPoint(x: cx, y: cy))
        minute.line(to: minEnd)
        minute.stroke()

        let d: CGFloat = 1.2
        NSBezierPath(ovalIn: NSRect(x: cx - d, y: cy - d, width: d * 2, height: d * 2)).fill()

        img.unlockFocus()
        img.isTemplate = true
        return img
    }
}
