import SwiftUI
import ServiceManagement

struct PermissionsView: View {
    @State private var loginItemEnabled = false
    @State private var quickActionInstalled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.headline)

            Text("Ensure Revisibility has the access it needs.")
                .font(.caption)
                .foregroundColor(.secondary)

            // Login Item
            GroupBox {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start at Login")
                            .font(.body)
                        Text("Revisibility launches automatically when you log in.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if loginItemEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Enabled")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Disabled")
                            .font(.caption)
                            .foregroundColor(.red)

                        Button("Enable") {
                            enableLoginItem()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(4)
            }

            // Quick Action
            GroupBox {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Finder Quick Action")
                            .font(.body)
                        Text("Right-click any file > Quick Actions > Revisibility.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if quickActionInstalled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Installed")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Not Installed")
                            .font(.caption)
                            .foregroundColor(.red)

                        Button("Install") {
                            installQuickAction()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(4)
            }

            // Finder Extensions hint
            GroupBox {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Finder Extensions")
                            .font(.body)
                        Text("If the Quick Action doesn't appear, enable it in System Settings > Privacy & Security > Extensions > Finder.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Open Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(4)
            }

            Spacer()

            Button("Refresh Status") {
                checkStatus()
            }
            .controlSize(.small)
        }
        .onAppear {
            checkStatus()
        }
    }

    private func checkStatus() {
        loginItemEnabled = SMAppService.mainApp.status == .enabled
        quickActionInstalled = FileManager.default.fileExists(
            atPath: NSHomeDirectory() + "/Library/Services/Revisibility.workflow/Contents/document.wflow"
        )
    }

    private func enableLoginItem() {
        do {
            try SMAppService.mainApp.register()
            loginItemEnabled = true
        } catch {
            print("Failed to register login item: \(error)")
        }
    }

    private func installQuickAction() {
        let fm = FileManager.default
        let servicesDir = NSHomeDirectory() + "/Library/Services"
        let workflowDir = servicesDir + "/Revisibility.workflow/Contents"

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
        checkStatus()
    }
}
