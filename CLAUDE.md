# Revisibility

macOS menu bar application that watches directories for file changes and automatically creates versioned backups.

## Build

```bash
cd /Users/matejbaco/Desktop/Revisibility
xcodebuild -project Revisibility.xcodeproj -scheme Revisibility -configuration Release clean build CONFIGURATION_BUILD_DIR=/Users/matejbaco/Desktop/Revisibility/build
```

To distribute:
```bash
cd build && ditto -c -k --keepParent Revisibility.app /Users/matejbaco/Desktop/Revisibility.zip
```

Unsigned app — recipient must right-click > Open to bypass Gatekeeper.

## Regenerate App Icon

Source icon is `icon.svg` (pink clock+rewind on white background). Convert to PNGs:
```bash
swift svg_to_png.swift
```
This generates correctly-sized PNGs into `Assets.xcassets/AppIcon.appiconset/`. After regenerating, do a **clean build** (`rm -rf build` first) to ensure the `.icns` is recompiled. macOS caches icons aggressively — re-register with LaunchServices if needed:
```bash
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f build/Revisibility.app
```

## Architecture

### Files

- **RevisibilityApp.swift** — App entry point + AppDelegate. Menu bar setup, service handler for Finder right-click integration, URL scheme handler (`revisibility://open?file=...`), login item registration, Quick Action auto-install, menu bar icon drawing.
- **DirectoryStore.swift** — Observable store of watched directories, persisted in UserDefaults.
- **FileWatcher.swift** — Watches directories using GCD dispatch sources + 2s polling fallback. On file change, debounces (0.5s) then copies to `.revisibility/<filename>/`. Skips hidden files and files ending with `_revisibility` (restored files).
- **PreferencesView.swift** — Main preferences window with TabView (Directories, Audit, Revisions, Permissions). Accepts `initialTab` parameter for programmatic tab selection.
- **AuditView.swift** — Lists all versioned files across all watched directories. Search bar + directory filter dropdown. Shows filename, date, time, size, "Show in Finder" button.
- **RevisionsView.swift** — Drag & drop a file (or receive via service/URL scheme) to see its version history. Lists versions with date, size, "Show in Finder", and "Restore" buttons. Listens to `RevisionRequest.shared` for external file selection.
- **RevisionRequest.swift** — Singleton `ObservableObject` for passing file paths from service handler / URL scheme to the Revisions tab.
- **PermissionsView.swift** — Shows status of: Start at Login (SMAppService), Finder Quick Action (.workflow installed), Finder Extensions (link to System Settings).

### Versioning Structure

```
<watched-directory>/
├── myfile.txt
└── .revisibility/
    └── myfile.txt/
        ├── myfile_2026-03-12_14-30-45_revisibility.txt
        └── myfile_2026-03-12_15-00-12_revisibility.txt
```

- Each watched file gets its own subdirectory inside `.revisibility/`
- Version filenames: `<original-name>_<yyyy-MM-dd_HH-mm-ss>_revisibility.<ext>`
- `_revisibility` suffix ensures restored files are **not** re-versioned by the watcher
- Only top-level files are watched (not nested/recursive)
- Hidden files (`.` prefix) are skipped

### Finder Integration

- **Quick Action** — Installed as `~/Library/Services/Revisibility.workflow` on first launch. Appears in right-click > Quick Actions > Revisibility. Calls `revisibility://open?file=<encoded-path>`.
- **NSServices** — Also registered in Info.plist (appears under Services submenu).
- **URL Scheme** — `revisibility://open?file=/path/to/file` opens app to Revisions tab with file pre-loaded.

### Xcode Project

Hand-crafted `project.pbxproj`. When adding new Swift files:
1. Add `PBXBuildFile` entry (e.g., `AA00000X /* File.swift in Sources */`)
2. Add `PBXFileReference` entry
3. Add to the Revisibility group children list
4. Add to `PBXSourcesBuildPhase` files list

Asset catalog is in `PBXResourcesBuildPhase` (ID: `AA000055`).

## User Preferences

- User pre-approves all `xcodebuild` commands — run without asking.
