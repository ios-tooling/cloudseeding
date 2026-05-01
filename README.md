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

## Dependencies

- [Suite](https://github.com/ios-tooling/Suite)
