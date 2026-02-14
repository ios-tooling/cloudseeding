//
//  PersistedCKRecord.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 7/25/25.
//

import CloudKit
import Suite
import SwiftData

public enum PersistedCKRecordRefreshError: Error { case recordNotInserted, recordNotFound, loadRecordFailed }

public extension PersistedCKRecord {
	
	func reloadFromCloud(from database: CKDatabase? = nil, overwriteLocal: Bool = false) async throws {
		guard let modelContext else { throw PersistedCKRecordRefreshError.recordNotInserted }
		guard let container = await CloudKitInterface.instance.container else { throw CloudSeedingError.notConfigured }
		let db = database ?? container.privateCloudDatabase
		guard let cloudRecord = try await db.fetchRecords(withIDs: [ckRecordID]).first else {
			if cachedRecordData == nil {
				logger.warning("Cannot reload \(Self.self): record was never saved to cloud")
				return
			}
			throw PersistedCKRecordRefreshError.recordNotFound
		}
		
		if !overwriteLocal, let cachedModifiedAt = lastKnownRecord?.modificationDate, let serverModifiedAt = cloudRecord.modificationDate, cachedModifiedAt == serverModifiedAt {
			return			// no changes
		}
		
		if !load(fromCloud: cloudRecord, context: modelContext) {
			throw PersistedCKRecordRefreshError.loadRecordFailed
		}
		lastKnownRecord = cloudRecord
	}
}

