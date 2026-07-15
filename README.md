# CloudSeeding

CloudKit utilities used as the substrate for sync-aware Swift apps. Provides:

- **`CKRecordBased`** — protocol for any class that has a `CKRecord` representation. Default `populateCloudRecord(_:)` and `lastKnownRecord` plumbing (NSKeyedArchive caching of the last server-received record so future uploads carry the right etag).
- **`CKRecordField<T>`** — typed key wrappers for `CKRecord` access (`CKRecordField.string("title")`, `.date(...)`, `.url(...)`, etc.) plus subscript ergonomics (`record[field]`, `record[codable: field]`).
- **`CloudKitInterface`** — singleton holding the active `CKContainer` and database references; owns the iCloud-availability check.
- **`SaveRecordOperation`**, **`DeferredPersistedSavable`** — helpers for save flows that need retries / debouncing.
- Error mapping (`CKError`/`CKError.Code` extensions, `CloudSeedingError`).

The higher-level sync abstraction (`PersistedCKRecord` protocol, schema-driven field mapping, conflict resolution) lives in **[SyncEngine](https://github.com/bengottlieb/SyncEngine)**, which depends on this package.

## Requirements

Swift 5.9+, iOS 14+/macOS 14+/watchOS 10+/tvOS 17+/visionOS 1+.

## Build / Test

```sh
swift build
swift test
```

## Command Line CloudKit Queries

CloudSeeding includes a small executable for inspecting CloudKit records without opening an app UI:

```sh
swift build --product cloudseeding
.build/debug/cloudseeding user --container iCloud.com.example.app
.build/debug/cloudseeding zones --container iCloud.com.example.app --database private
.build/debug/cloudseeding query ChecklistItem --container iCloud.com.example.app --zone DevCenterCatalog --predicate 'isChecked == false'
.build/debug/cloudseeding record <record-name> --container iCloud.com.example.app --zone DevCenterCatalog
```

The tool emits JSON by default. Use `--field title,isChecked` to limit fields, `--limit 25` to cap query results, `--all` to fetch every page, and `--compact` for script-friendly output.

On macOS, direct private CloudKit access requires the executable to run from a signed app bundle with a matching provisioning profile embedded. A raw SwiftPM executable can run `help`, but AMFI will reject restricted CloudKit entitlements on the bare Mach-O. Copy `Examples/cloudseeding.entitlements.example`, replace the container identifier, then package and sign the built tool:

```sh
mkdir -p /tmp/CloudSeedingTool.app/Contents/MacOS
cp .build/debug/cloudseeding /tmp/CloudSeedingTool.app/Contents/MacOS/cloudseeding
cp /path/to/profile.provisionprofile /tmp/CloudSeedingTool.app/Contents/embedded.provisionprofile
/usr/libexec/PlistBuddy \
  -c 'Add :CFBundleExecutable string cloudseeding' \
  -c 'Add :CFBundleIdentifier string com.example.app' \
  -c 'Add :CFBundleName string CloudSeedingTool' \
  -c 'Add :CFBundlePackageType string APPL' \
  /tmp/CloudSeedingTool.app/Contents/Info.plist
codesign --force --deep --sign "Apple Development: Your Name (TEAMID)" \
  --entitlements Examples/cloudseeding.entitlements \
  /tmp/CloudSeedingTool.app
/tmp/CloudSeedingTool.app/Contents/MacOS/cloudseeding user --container iCloud.com.example.app
```

## Dependencies

- [Suite](https://github.com/ios-tooling/Suite)
