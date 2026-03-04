import Testing
import CloudKit
@testable import CloudSeeding

// MARK: - Test double

final class MockCKRecordBased: CKRecordBased {
	var cachedRecordData: Data?

	var testRecordName: String = "test-record"
	var testFields: [String: CKRecordValue] = [:]

	func populateCloudRecord(_ record: CKRecord) {
		for (key, value) in testFields {
			record[key] = value
		}
	}

	var ckRecordName: String { testRecordName }
	static var ckRecordType: CKRecord.RecordType { "MockType" }
	var ckRecordZoneID: CKRecordZone.ID {
		CKRecordZone.ID(zoneName: "TestZone", ownerName: CKCurrentUserDefaultName)
	}
}

// MARK: - lastKnownRecord

@Test func lastKnownRecord_initiallyNil() {
	let mock = MockCKRecordBased()
	#expect(mock.lastKnownRecord == nil)
	#expect(mock.cachedRecordData == nil)
}

@Test func lastKnownRecord_setAndGet_roundtrip() {
	let mock = MockCKRecordBased()
	let record = CKRecord(recordType: "MockType", recordID: CKRecord.ID(recordName: "test-record", zoneID: mock.ckRecordZoneID))
	record["title"] = "Hello" as CKRecordValue
	record["count"] = 42 as CKRecordValue

	mock.lastKnownRecord = record

	let retrieved = mock.lastKnownRecord
	#expect(retrieved != nil)
	#expect(retrieved?.recordType == "MockType")
	#expect(retrieved?.recordID.recordName == "test-record")
	#expect(retrieved?["title"] as? String == "Hello")
	#expect(retrieved?["count"] as? Int == 42)
}

@Test func lastKnownRecord_setNil_clearsData() {
	let mock = MockCKRecordBased()
	let record = CKRecord(recordType: "MockType", recordID: CKRecord.ID(recordName: "test-record", zoneID: mock.ckRecordZoneID))
	mock.lastKnownRecord = record
	#expect(mock.cachedRecordData != nil)

	mock.lastKnownRecord = nil
	#expect(mock.cachedRecordData == nil)
	#expect(mock.lastKnownRecord == nil)
}

@Test func lastKnownRecord_preservesCustomFields() {
	let mock = MockCKRecordBased()
	let record = CKRecord(recordType: "MockType", recordID: CKRecord.ID(recordName: "test-record", zoneID: mock.ckRecordZoneID))
	let date = Date(timeIntervalSince1970: 1000000)
	record["name"] = "Test" as CKRecordValue
	record["number"] = 3.14 as CKRecordValue
	record["timestamp"] = date as CKRecordValue

	mock.lastKnownRecord = record
	let retrieved = mock.lastKnownRecord

	#expect(retrieved?["name"] as? String == "Test")
	#expect(retrieved?["number"] as? Double == 3.14)
	#expect(retrieved?["timestamp"] as? Date == date)
}

// MARK: - ckRecordID

@Test func ckRecordID_derivedFromNameAndZone() {
	let mock = MockCKRecordBased()
	mock.testRecordName = "my-record"

	let id = mock.ckRecordID
	#expect(id.recordName == "my-record")
	#expect(id.zoneID.zoneName == "TestZone")
	#expect(id.zoneID.ownerName == CKCurrentUserDefaultName)
}

// MARK: - ckRecord

@Test func ckRecord_createsNewRecordWhenNoCache() {
	let mock = MockCKRecordBased()
	mock.testFields = ["title": "Hello" as CKRecordValue]

	let record = mock.ckRecord
	#expect(record.recordType == "MockType")
	#expect(record.recordID.recordName == "test-record")
	#expect(record["title"] as? String == "Hello")
	// Should have cached the record
	#expect(mock.cachedRecordData != nil)
}

@Test func ckRecord_updatesExistingCachedRecord() {
	let mock = MockCKRecordBased()
	mock.testFields = ["title": "First" as CKRecordValue]

	// Create initial record
	let first = mock.ckRecord
	#expect(first["title"] as? String == "First")

	// Update the fields and get ckRecord again — should update the cached record
	mock.testFields = ["title": "Second" as CKRecordValue]
	let second = mock.ckRecord
	#expect(second["title"] as? String == "Second")
	// Same record identity (same recordID)
	#expect(second.recordID == first.recordID)
}
