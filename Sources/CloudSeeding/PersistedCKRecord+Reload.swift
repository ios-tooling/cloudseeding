//
//  PersistedCKRecord.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 7/25/25.
//

import CloudKit
import Suite
import SwiftData

enum PersistedCKRecordRefreshError: Error { case recordNotInserted, recordNotFound, loadRecordFailed }

public extension PersistedCKRecord {
	
	func reloadFromCloud(overwriteLocal: Bool = false) async throws {
		guard let modelContext else { throw PersistedCKRecordRefreshError.recordNotInserted }
		guard let cloudRecord = try await CloudKitInterface.instance.container.privateCloudDatabase.fetchRecords(withIDs: [ckRecordID]).first else {
			if cachedRecordData == nil {
				print("Never saved, cannot reload")
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

