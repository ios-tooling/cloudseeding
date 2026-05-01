# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this package is

CloudKit *utilities* — a thin layer over Apple's CloudKit that makes it nicer to use, but not itself a sync engine. Reach for it when you need:

- A typed wrapper around `CKRecord` field access (`CKRecordField`).
- A protocol (`CKRecordBased`) for "this class round-trips through a `CKRecord`."
- Last-known-record caching (so upload retries carry the right server etag).
- An iCloud availability/error-handling layer (`CloudKitInterface`, `CKError` extensions).

The full **sync** abstraction — `PersistedCKRecord` protocol, schema-driven field mapping, conflict resolution, change tracking — lives in **SyncEngine**, which depends on this package.

## Source layout

```
Sources/CloudSeeding/
  CKDatabase.swift              CKDatabase helpers (record fetching)
  CKError.swift                 CKError + CKError.Code extensions
  CKRecord.swift                CKRecord helpers
  CKRecordBased.swift           protocol + lastKnownRecord caching
  CKRecordField.swift           typed field wrappers + record subscripts
  CloudComms.swift              shared comms helpers
  CloudKitInterface.swift       container/database singleton, availability
  CloudKitNotAvailableView.swift placeholder UI
  CloudKitStats.swift           aggregate counts
  CloudSeedingError.swift       error type + module logger
  DeferredPersistedSavable.swift debounced save helper
  Error.swift                   misc error helpers
  SaveRecordOperation.swift     save operation with retry
  [CKRecord].swift              array-of-records helpers
```

## Key types

- `CKRecordBased` — class protocol; conformers expose `populateCloudRecord(_:)`, `ckRecordName`, `ckRecordType`, `ckRecordZoneID`. Default extensions provide `ckRecord` (computed from `populate` + the cached `lastKnownRecord`) and `lastKnownRecord` (NSKeyedArchive-backed via `cachedRecordData: Data?`).
- `CKRecordField<T>` — typed key descriptor. `record[CKRecordField.string("title")]` returns `String?`. The `[codable:]` overload JSON-encodes/decodes a `Codable` payload to a single field.
- `CloudKitInterface.instance` — `@MainActor @Observable` singleton holding the active `CKContainer` and convenience databases.

## Conventions

- **Module logger:** `let logger = Logger(subsystem: "CloudSeeding", category: "sync")` in `CloudSeedingError.swift`. New files reuse it.
- **No SyncEngine dependency.** This package is the lower layer; nothing here references `PersistedCKRecord` or anything from SyncEngine.
- **Targeting:** the protocol-style `@available(iOS 17.0, macOS 14, *)` annotation appears on types that touch SwiftData (none currently here, but historically `PersistedCKRecord` lived here with that gate).

## Build / Test

```sh
swift build
swift test
```

Tests live under `Tests/CloudSeedingTests/` and use **Swift Testing**.

## When making changes

- If you add a new `CKRecordField<T>` factory, mirror the style in `CKRecordField.swift`: a generic-constrained extension exposing a static `func`.
- If you touch `CKRecordBased`, remember that conformers in client packages (e.g. SyncEngine's `PersistedCKRecord`) build on it — don't add requirements that would force a breaking change without coordinating.
- Avoid pulling SwiftData into this package; it stays here as a CloudKit-only library.
