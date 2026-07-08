//
//  PublishedFileStore.swift
//  CloudSeeding
//
//  Generic publish/download of files on a container's PUBLIC database: one
//  record per key, carrying the file as a CKAsset. Downloading is world-readable
//  (any build can fetch); publishing writes the record and is meant to be driven
//  from a private/admin path. The container ID is passed in, so this stays free
//  of any app-specific identity.
//
//  Record: type "PublishedFile", recordName == key, on the public database
//    • asset : CKAsset — the file
//    • name  : String  — a display label (optional)
//    • updatedAt : Date
//    • size : Int64 — the asset's byte count, so listing needn't fetch assets
//

import Foundation
import CloudKit

@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, visionOS 1.0, *)
public enum PublishedFileStore {
	public static let recordType = "PublishedFile"

	public struct DownloadedFile: Sendable {
		/// A local URL to the downloaded asset (a CloudKit temp file — copy it if
		/// it needs to persist).
		public let fileURL: URL
		public let name: String
	}

	/// One published record's metadata, without downloading its asset. `size` is
	/// the asset's on-disk byte count when CloudKit reports it, else nil.
	public struct PublishedItem: Sendable, Identifiable {
		public var id: String { key }
		public let key: String
		public let name: String
		public let updatedAt: Date?
		public let size: Int64?
	}

	/// Fetches the published file for `key` from the container's public database.
	public static func download(key: String, containerID: String) async throws -> DownloadedFile {
		let record = try await fetch(key: key, in: publicDatabase(containerID))
		guard let asset = record["asset"] as? CKAsset, let fileURL = asset.fileURL else {
			throw PublishedFileError.missingAsset(key)
		}
		return DownloadedFile(fileURL: fileURL, name: (record["name"] as? String) ?? key)
	}

	/// Publishes (creates or replaces) the file at `key`. Admin-only: writing to
	/// the public database needs an iCloud account with create/write permission.
	public static func publish(key: String, fileURL: URL, name: String, containerID: String) async throws {
		let database = publicDatabase(containerID)
		let record = (try? await fetch(key: key, in: database)) ?? CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: key))
		record["asset"] = CKAsset(fileURL: fileURL)
		record["name"] = name as CKRecordValue
		record["updatedAt"] = Date() as CKRecordValue
		if let size = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 {
			record["size"] = size as CKRecordValue
		}
		do {
			_ = try await database.save(record)
		} catch {
			throw PublishedFileError.cloud(error.localizedDescription)
		}
	}

	/// Lists every published file's metadata (no assets downloaded). Admin-only:
	/// used by our own seeding tools to see what's been pushed to the container.
	public static func list(containerID: String) async throws -> [PublishedItem] {
		let database = publicDatabase(containerID)
		// Sort client-side: server-side ordering needs the field marked Sortable
		// in the CloudKit schema, which we don't want to depend on for a tool.
		// Only scalar fields — never "asset". Including it makes CloudKit fetch
		// every CKAsset just to list them, which is slow and fails on the public
		// database (surfacing as a spurious network error).
		let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
		do {
			let (results, _) = try await database.records(matching: query, desiredKeys: ["name", "updatedAt", "size"])
			return results.compactMap { recordID, result -> PublishedItem? in
				guard let record = try? result.get() else { return nil }
				return PublishedItem(key: recordID.recordName,
				                     name: (record["name"] as? String) ?? recordID.recordName,
				                     updatedAt: record["updatedAt"] as? Date,
				                     size: record["size"] as? Int64)
			}
			.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
		} catch let error as CKError where error.code == .unknownItem {
			return []  // record type not created yet — nothing published
		} catch let error as CKError where error.code == .networkUnavailable || error.code == .networkFailure {
			throw PublishedFileError.offline
		} catch {
			throw PublishedFileError.cloud(error.localizedDescription)
		}
	}

	/// Removes the published record at `key`. Admin-only, same permission as publish.
	public static func delete(key: String, containerID: String) async throws {
		do {
			_ = try await publicDatabase(containerID).deleteRecord(withID: CKRecord.ID(recordName: key))
		} catch let error as CKError where error.code == .unknownItem {
			throw PublishedFileError.notFound(key)
		} catch {
			throw PublishedFileError.cloud(error.localizedDescription)
		}
	}

	private static func publicDatabase(_ containerID: String) -> CKDatabase {
		CKContainer(identifier: containerID).publicCloudDatabase
	}

	private static func fetch(key: String, in database: CKDatabase) async throws -> CKRecord {
		do {
			return try await database.record(for: CKRecord.ID(recordName: key))
		} catch let error as CKError where error.code == .unknownItem {
			throw PublishedFileError.notFound(key)
		} catch let error as CKError where error.code == .networkUnavailable || error.code == .networkFailure {
			throw PublishedFileError.offline
		} catch {
			throw PublishedFileError.cloud(error.localizedDescription)
		}
	}
}

public enum PublishedFileError: LocalizedError, Equatable {
	case notFound(String)
	case missingAsset(String)
	case offline
	case cloud(String)

	/// Surfaced through `localizedDescription` too, so callers that show a raw
	/// error still get a legible line instead of "operation couldn't be completed".
	public var errorDescription: String? { message }

	public var message: String {
		switch self {
		case .notFound: "This file hasn't been published yet."
		case .missingAsset: "The published record has no attached file."
		case .offline: "You appear to be offline. Try again on a connection."
		case .cloud(let detail): detail
		}
	}
}
