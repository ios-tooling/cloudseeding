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
		do {
			_ = try await database.save(record)
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

public enum PublishedFileError: Error, Equatable {
	case notFound(String)
	case missingAsset(String)
	case offline
	case cloud(String)

	public var message: String {
		switch self {
		case .notFound: "This file hasn't been published yet."
		case .missingAsset: "The published record has no attached file."
		case .offline: "You appear to be offline. Try again on a connection."
		case .cloud(let detail): detail
		}
	}
}
