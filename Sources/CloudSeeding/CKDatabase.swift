//
//  CKDatabase.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 7/26/25.
//

import Suite
import CloudKit

@available(iOS 17.0, macOS 14, *)
public enum CKRecordConflictHandlerResult: Sendable { case ignore, replace(CKRecord) }

/// CloudKit lets anyone read the public database, signed in or not; only the
/// private and shared scopes need an account. Gating public reads on account
/// status makes a signed-out user look like an empty catalog.
///
/// Split out from `requireAccountUnlessPublic()` so the rule itself is testable:
/// constructing a real `CKDatabase` needs container entitlements a test binary
/// can't carry.
@available(iOS 17.0, macOS 14, *)
enum CloudSeedingAccountRequirement {
	static func requiresAccount(scope: CKDatabase.Scope, status: CloudKitInterface.Status) -> Bool {
		guard scope != .public else { return false }
		return status == .notAvailable
	}
}

@available(iOS 17.0, macOS 14, *)
extension CKDatabase {
	func requireAccountUnlessPublic() async throws {
		let status = await CloudKitInterface.instance.status
		if CloudSeedingAccountRequirement.requiresAccount(scope: databaseScope, status: status) {
			throw CloudSeedingError.notAvailable
		}
	}
}

@available(iOS 17.0, macOS 14, *)
public extension CKDatabase {
	func save(record: CKRecord) async throws -> CKRecord {
		try await save(record: record) { _, _ in .ignore}
	}

	func save(record: CKRecord, conflicts: @escaping (CKRecord, Error) async -> CKRecordConflictHandlerResult) async throws -> CKRecord {
		let op = SaveRecordOperation(record: record)
		do {
			return try await op.save(to: self)
		} catch let error as CKError {
			switch error.code {
			case .serverRecordChanged:
				if let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
					switch await conflicts(serverRecord, error) {
					case .ignore: return serverRecord
					case .replace(let newRecord): return try await save(record: newRecord)
					}
				}
				
			default: break
			}
			throw error
		} catch {
			throw error
		}
	}
	
	func recordExists(withID id: CKRecord.ID) async throws -> Bool {
		try await withCheckedThrowingContinuation { continuation in
			let operation = CKFetchRecordsOperation(recordIDs: [id])
			operation.desiredKeys = []
			var recordResult: Result<CKRecord, Error>?
			operation.perRecordResultBlock = { _, result in
				recordResult = result
			}
			operation.fetchRecordsResultBlock = { _ in
				switch recordResult {
				case .success: continuation.resume(returning: true)
				case .failure(let error):
					if let ckError = error as? CKError, ckError.code == .unknownItem {
						continuation.resume(returning: false)
					} else {
						continuation.resume(throwing: error)
					}
				case .none: continuation.resume(returning: false)
				}
			}
			self.add(operation)
		}
	}

	func fetchRecords(withIDs ids: [CKRecord.ID?]) async throws -> [CKRecord] {
		let all = try await records(for: ids.compactMap { $0 })
		return all.values.compactMap { value in
			switch value {
			case .success(let record): record
			case .failure: nil
			}
		}
	}
	
	func fetchRecord(ofType type: String, matching predicate: NSPredicate, inZone: CKRecordZone.ID? = nil) async throws -> CKRecord {
		try await requireAccountUnlessPublic()
		let query = CKQuery(recordType: type, predicate: predicate)
		let results = try await self.records(matching: query, inZoneWith: inZone, desiredKeys: nil, resultsLimit: 1).matchResults
		
		guard let found = results.first else { throw CloudSeedingError.recordNotFound }
		
		switch found.1 {
		case .success(let record): return record
		case .failure(let error): throw error
		}
	}
	
	func fetchRecords(ofType type: CKRecord.RecordType, matching predicate: NSPredicate = .init(value: true), sortedBy: [NSSortDescriptor]? = nil, inZone: CKRecordZone.ID? = nil, keys: [CKRecord.FieldKey]? = nil, limit: Int = CKQueryOperation.maximumResults) async throws -> [CKRecord] {
		try await requireAccountUnlessPublic()
		if await Reachability.instance.isOffline { throw CloudSeedingError.offline }
		let query = CKQuery(recordType: type, predicate: predicate)
		query.sortDescriptors = sortedBy

		var allResults: [CKRecord] = []
		var cursor: CKQueryOperation.Cursor?

		while true {
			let results: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)

			if let cursor {
				results = try await self.records(continuingMatchFrom: cursor)
			} else {
				results = try await self.records(matching: query, inZoneWith: inZone, desiredKeys: keys, resultsLimit: limit)
			}

			allResults += results.matchResults.compactMap { result in
				switch result.1 {
				case .success(let record): return record
				case .failure: return nil
				}
			}

			guard let next = results.queryCursor, (limit == 0 || allResults.count < limit) else { break }
			cursor = next
		}
		return allResults
	}
}
