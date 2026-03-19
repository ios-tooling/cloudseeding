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
		let query = CKQuery(recordType: type, predicate: predicate)
		var count = 0
		var cursor: CKQueryOperation.Cursor?

		while true {
			let results: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)

			if let cursor {
				results = try await database.records(continuingMatchFrom: cursor)
			} else {
				results = try await database.records(matching: query, inZoneWith: zone, desiredKeys: [], resultsLimit: CKQueryOperation.maximumResults)
			}

			count += results.matchResults.count
			print("Fetched \(results.matchResults.count) (total: \(count) \(type) records")
			guard let next = results.queryCursor else { break }
			cursor = next
		}

		return count
	}
}
