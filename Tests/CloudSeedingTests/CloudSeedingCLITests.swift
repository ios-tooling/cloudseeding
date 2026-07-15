import CloudKit
import Foundation
import Testing
@testable import CloudSeedingCLISupport

@Test func cloudSeedingCLIParsesQueryOptions() throws {
	let options = try CloudSeedingCommandLineOptions.parse([
		"query",
		"ChecklistItem",
		"--container", "iCloud.com.example.app",
		"--database", "private",
		"--predicate", "isChecked == false",
		"--zone", "Catalog",
		"--field", "title,isChecked",
		"--field", "title",
		"--limit", "25",
		"--compact",
	])

	#expect(options.global.containerIdentifier == "iCloud.com.example.app")
	#expect(options.global.databaseScope == .private)
	#expect(options.global.compactOutput == true)

	guard case .query(let query) = options.command else {
		Issue.record("Expected query command")
		return
	}

	#expect(query.recordType == "ChecklistItem")
	#expect(query.predicate == "isChecked == false")
	#expect(query.zoneName == "Catalog")
	#expect(query.fields == ["title", "isChecked"])
	#expect(query.limit == 25)
}

@Test func cloudSeedingCLIParsesAllAsUnlimitedQuery() throws {
	let options = try CloudSeedingCommandLineOptions.parse([
		"query",
		"--record-type", "Project",
		"--all",
	])

	guard case .query(let query) = options.command else {
		Issue.record("Expected query command")
		return
	}

	#expect(query.limit == nil)
}

@Test func cloudSeedingCLIParsesRecordIDWithCustomZone() throws {
	let options = try CloudSeedingCommandLineOptions.parse([
		"record",
		"abc123",
		"--zone", "Catalog",
		"--zone-owner", "_defaultOwner",
	])

	guard case .record(let record) = options.command else {
		Issue.record("Expected record command")
		return
	}

	#expect(record.recordID.recordName == "abc123")
	#expect(record.recordID.zoneID.zoneName == "Catalog")
	#expect(record.recordID.zoneID.ownerName == "_defaultOwner")
}

@Test func cloudSeedingCLIEncodesRecordAsJSONSafeDictionary() throws {
	let zoneID = CKRecordZone.ID(zoneName: "Catalog", ownerName: CKCurrentUserDefaultName)
	let recordID = CKRecord.ID(recordName: "item-1", zoneID: zoneID)
	let record = CKRecord(recordType: "ChecklistItem", recordID: recordID)
	let date = Date(timeIntervalSince1970: 1_800_000_000)
	record["title"] = "Follow up" as CKRecordValue
	record["done"] = false as CKRecordValue
	record["rank"] = 42 as CKRecordValue
	record["createdAt"] = date as CKRecordValue

	let encoded = CloudKitRecordJSONEncoder().encode(record: record)
	let fields = try #require(encoded["fields"] as? [String: Any])

	#expect(encoded["recordType"] as? String == "ChecklistItem")
	#expect(encoded["recordName"] as? String == "item-1")
	#expect(fields["title"] as? String == "Follow up")
	#expect(fields["done"] as? Bool == false)
	#expect(fields["rank"] as? Int64 == 42)
	#expect(fields["createdAt"] as? String == ISO8601DateFormatter().string(from: date))

	let data = try CloudKitRecordJSONEncoder.jsonData(for: encoded)
	#expect(data.isEmpty == false)
}
