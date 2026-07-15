import CloudKit
import Foundation

public extension CloudSeedingDatabaseScope {
	func database(in container: CKContainer) -> CKDatabase {
		switch self {
		case .private: container.privateCloudDatabase
		case .public: container.publicCloudDatabase
		case .shared: container.sharedCloudDatabase
		}
	}
}

public extension CKAccountStatus {
	var cloudSeedingDescription: String {
		switch self {
		case .available: "available"
		case .couldNotDetermine: "couldNotDetermine"
		case .noAccount: "noAccount"
		case .restricted: "restricted"
		case .temporarilyUnavailable: "temporarilyUnavailable"
		@unknown default: "unknown"
		}
	}
}

public extension CloudSeedingRecordOptions {
	var zoneID: CKRecordZone.ID? {
		guard let zoneName else { return nil }
		return CKRecordZone.ID(zoneName: zoneName, ownerName: zoneOwnerName ?? CKCurrentUserDefaultName)
	}

	var recordID: CKRecord.ID {
		CKRecord.ID(recordName: recordName, zoneID: zoneID ?? CKRecordZone.default().zoneID)
	}
}

public extension CloudSeedingQueryOptions {
	var zoneID: CKRecordZone.ID? {
		guard let zoneName else { return nil }
		return CKRecordZone.ID(zoneName: zoneName, ownerName: zoneOwnerName ?? CKCurrentUserDefaultName)
	}

	var desiredKeys: [CKRecord.FieldKey]? {
		fields.isEmpty ? nil : fields
	}
}
