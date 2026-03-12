#!/usr/bin/env swift

import Foundation

// Create a Quick Action (.workflow) that calls our URL scheme
let servicesDir = NSHomeDirectory() + "/Library/Services"
let workflowDir = servicesDir + "/Revisibility.workflow/Contents"

let fm = FileManager.default
try? fm.removeItem(atPath: servicesDir + "/Revisibility.workflow")
try fm.createDirectory(atPath: workflowDir, withIntermediateDirectories: true)

// Info.plist for the workflow
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
try infoPlist.write(toFile: workflowDir + "/Info.plist", atomically: true, encoding: .utf8)

// document.wflow - Automator workflow that runs a shell script
let wflow = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>523</string>
    <key>AMApplicationVersion</key>
    <string>2.10</string>
    <key>AMDocumentVersion</key>
    <string>2</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Optional</key>
                    <false/>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.path</string>
                    </array>
                </dict>
                <key>AMActionVersion</key>
                <string>1.0.2</string>
                <key>AMApplication</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>AMBundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>AMCategory</key>
                <array>
                    <string>AMCategoryUtilities</string>
                </array>
                <key>AMIconName</key>
                <string>RunShellScript</string>
                <key>AMKeywords</key>
                <array>
                    <string>Shell</string>
                    <string>Script</string>
                </array>
                <key>AMName</key>
                <string>Run Shell Script</string>
                <key>AMProvides</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.path</string>
                    </array>
                </dict>
                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Run Shell Script.action</string>
                <key>ActionName</key>
                <string>Run Shell Script</string>
                <key>ActionParameters</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <string>for f in "$@"; do
    encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$f")
    open "revisibility://open?file=$encoded"
    break
done</string>
                    <key>CheckedForUserDefaultShell</key>
                    <true/>
                    <key>inputMethod</key>
                    <integer>1</integer>
                    <key>shell</key>
                    <string>/bin/zsh</string>
                    <key>source</key>
                    <string></string>
                </dict>
                <key>BundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>CFBundleVersion</key>
                <string>1.0.2</string>
                <key>CanShowSelectedItemsWhenRun</key>
                <false/>
                <key>CanShowWhenRun</key>
                <true/>
                <key>Category</key>
                <array>
                    <string>AMCategoryUtilities</string>
                </array>
                <key>Class Name</key>
                <string>RunShellScriptAction</string>
                <key>InputUUID</key>
                <string>A1B2C3D4-E5F6-7890-ABCD-EF1234567890</string>
                <key>Keywords</key>
                <array>
                    <string>Shell</string>
                    <string>Script</string>
                </array>
                <key>OutputUUID</key>
                <string>B2C3D4E5-F6A7-8901-BCDE-F12345678901</string>
                <key>UUID</key>
                <string>C3D4E5F6-A7B8-9012-CDEF-123456789012</string>
                <key>UnlocalizedApplications</key>
                <array>
                    <string>Automator</string>
                </array>
            </dict>
        </dict>
    </array>
    <key>connectors</key>
    <dict/>
    <key>workflowMetaData</key>
    <dict>
        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict>
</plist>
"""
try wflow.write(toFile: workflowDir + "/document.wflow", atomically: true, encoding: .utf8)

print("Quick Action installed at ~/Library/Services/Revisibility.workflow")
print("It should appear in right-click > Quick Actions > Revisibility")

// Refresh services
let task = Process()
task.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
task.arguments = ["-flush"]
try? task.run()
task.waitUntilExit()

print("Services refreshed.")
