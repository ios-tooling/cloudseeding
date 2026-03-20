//
//  CloudKitStats.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 3/18/26.
//

import CloudKit

public final class CloudKitStats: Sendable {
	public enum DatabaseType: Sendable {
		case `public`, `private`, shared
	}

	public let container: CKContainer
	public let database: CKDatabase

	public init(containerName: String, databaseType: DatabaseType = .private) {
		self.container = CKContainer(identifier: containerName)
		switch databaseType {
		case .public: self.database = container.publicCloudDatabase
		case .private: self.database = container.privateCloudDatabase
		case .shared: self.database = container.sharedCloudDatabase
		}
	}

	public func availableRecordZones() async throws -> [CKRecordZone] {
		try await database.allRecordZones()
	}

	public func availableRecordTypes() async throws -> [CKRecord.RecordType] {
		let zones = try await availableRecordZones()
		var recordTypes: Set<CKRecord.RecordType> = []

		for zone in zones {
			let types = try await recordTypesInZone(zone.zoneID)
			recordTypes.formUnion(types)
		}

		return recordTypes.sorted()
	}

	private func recordTypesInZone(_ zoneID: CKRecordZone.ID) async throws -> Set<CKRecord.RecordType> {
		var recordTypes: Set<CKRecord.RecordType> = []

		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: .init(previousServerChangeToken: nil)])
			operation.recordWasChangedBlock = { _, result in
				if case .success(let record) = result {
					recordTypes.insert(record.recordType)
				}
			}
			operation.fetchRecordZoneChangesResultBlock = { result in
				switch result {
				case .success: continuation.resume()
				case .failure(let error): continuation.resume(throwing: error)
				}
			}
			database.add(operation)
		}

		return recordTypes
	}

	public func recordCount(ofType type: CKRecord.RecordType, matching predicate: NSPredicate = .init(value: true), inZone zone: CKRecordZone.ID? = nil) async throws -> Int {
		var count = 0
		var cursor: CKQueryOperation.Cursor?

		repeat {
			let (batchCount, nextCursor) = try await fetchBatch(
				query: cursor == nil ? CKQuery(recordType: type, predicate: predicate) : nil,
				cursor: cursor,
				zone: zone
			)
			count += batchCount
			cursor = nextCursor
		} while cursor != nil

		return count
	}

	private func fetchBatch(query: CKQuery?, cursor: CKQueryOperation.Cursor?, zone: CKRecordZone.ID?) async throws -> (Int, CKQueryOperation.Cursor?) {
		try await withCheckedThrowingContinuation { continuation in
			let operation: CKQueryOperation
			if let cursor {
				operation = CKQueryOperation(cursor: cursor)
			} else if let query {
				operation = CKQueryOperation(query: query)
				operation.zoneID = zone
			} else {
				continuation.resume(returning: (0, nil))
				return
			}

			operation.desiredKeys = []
			operation.resultsLimit = CKQueryOperation.maximumResults

			var batchCount = 0
			operation.recordMatchedBlock = { _, result in
				if case .success = result { batchCount += 1 }
			}
			
			operation.queryResultBlock = { result in
				switch result {
				case .success(let nextCursor): continuation.resume(returning: (batchCount, nextCursor))
				case .failure(let error): continuation.resume(throwing: error)
				}
			}

			database.add(operation)
		}
	}
}
