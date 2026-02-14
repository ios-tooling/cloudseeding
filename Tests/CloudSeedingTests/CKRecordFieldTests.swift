import Testing
import CloudKit
@testable import CloudSeeding

// MARK: - Test helper

struct TestConfig: Codable, Equatable {
	var name: String
	var value: Int
}

private func makeRecord() -> CKRecord {
	CKRecord(recordType: "TestType", recordID: CKRecord.ID(recordName: "test"))
}

// MARK: - Factory methods

@Test func boolFactory() {
	let field = CKRecordField.bool("flag")
	#expect(field.name == "flag")
	#expect(field.dataType == Bool.self)
}

@Test func intFactory() {
	let field = CKRecordField.int("count")
	#expect(field.name == "count")
	#expect(field.dataType == Int.self)
}

@Test func doubleFactory() {
	let field = CKRecordField.double("score")
	#expect(field.name == "score")
	#expect(field.dataType == Double.self)
}

@Test func stringFactory() {
	let field = CKRecordField.string("title")
	#expect(field.name == "title")
	#expect(field.dataType == String.self)
}

@Test func dateFactory() {
	let field = CKRecordField.date("created")
	#expect(field.name == "created")
	#expect(field.dataType == Date.self)
}

@Test func dataFactory() {
	let field = CKRecordField.data("blob")
	#expect(field.name == "blob")
	#expect(field.dataType == Data.self)
}

@Test func stringArrayFactory() {
	let field = CKRecordField.stringArray("tags")
	#expect(field.name == "tags")
	#expect(field.dataType == [String].self)
}

@Test func dateArrayFactory() {
	let field = CKRecordField.dateArray("dates")
	#expect(field.name == "dates")
	#expect(field.dataType == [Date].self)
}

@Test func doubleArrayFactory() {
	let field = CKRecordField.doubleArray("values")
	#expect(field.name == "values")
	#expect(field.dataType == [Double].self)
}

@Test func urlFactory() {
	let field = CKRecordField.url("link")
	#expect(field.name == "link")
	#expect(field.dataType == URL.self)
}

@Test func urlsFactory() {
	let field = CKRecordField.urls("links")
	#expect(field.name == "links")
	#expect(field.dataType == [URL].self)
}

@Test func dataArrayFactory() {
	let field = CKRecordField.dataArray("blobs")
	#expect(field.name == "blobs")
	#expect(field.dataType == [Data].self)
}

@Test func codableFactory() {
	let field = CKRecordField.codable("config", TestConfig.self)
	#expect(field.name == "config")
	#expect(field.dataType == TestConfig.self)
}

// MARK: - isPrimitiveField

// NOTE: isPrimitiveField has a bug — it compares DataType.self (e.g. Bool.self)
// against Bool.Type.self (Bool.Type.Type), which never matches. This test
// documents the actual (broken) behavior. When the bug is fixed, these
// expectations should be flipped.
@Test func isPrimitiveField_alwaysReturnsFalse_knownBug() {
	#expect(CKRecordField.bool("b").isPrimitiveField == false)
	#expect(CKRecordField.int("i").isPrimitiveField == false)
	#expect(CKRecordField.double("d").isPrimitiveField == false)
	#expect(CKRecordField.string("s").isPrimitiveField == false)
	#expect(CKRecordField.date("dt").isPrimitiveField == false)
	#expect(CKRecordField.data("da").isPrimitiveField == false)
	#expect(CKRecordField.url("u").isPrimitiveField == false)
	#expect(CKRecordField.stringArray("sa").isPrimitiveField == false)
}

// MARK: - CKRecord subscript roundtrips

@Test func ckRecord_stringSubscript_roundtrip() {
	let record = makeRecord()
	let field = CKRecordField.string("title")
	record[field] = "Hello"
	let result: String? = record[field]
	#expect(result == "Hello")
}

@Test func ckRecord_intSubscript_roundtrip() {
	let record = makeRecord()
	let field = CKRecordField.int("count")
	record[field] = 42
	let result: Int? = record[field]
	#expect(result == 42)
}

@Test func ckRecord_doubleSubscript_roundtrip() {
	let record = makeRecord()
	let field = CKRecordField.double("score")
	record[field] = 3.14
	let result: Double? = record[field]
	#expect(result == 3.14)
}

@Test func ckRecord_boolSubscript_roundtrip() {
	let record = makeRecord()
	// CKRecord stores Bool as NSNumber; use the raw key to set, then typed field to read
	record["active"] = true as NSNumber as CKRecordValue
	let field = CKRecordField.bool("active")
	let result: Bool? = record[field]
	#expect(result == true)
}

@Test func ckRecord_dateSubscript_roundtrip() {
	let record = makeRecord()
	let field = CKRecordField.date("created")
	let now = Date.now
	record[field] = now
	let result: Date? = record[field]
	#expect(result == now)
}

@Test func ckRecord_dataSubscript_roundtrip() {
	let record = makeRecord()
	let field = CKRecordField.data("blob")
	let data = Data([0x01, 0x02, 0x03])
	record[field] = data
	let result: Data? = record[field]
	#expect(result == data)
}

// MARK: - Codable subscript

@Test func ckRecord_codableSubscript_roundtrip() {
	let record = makeRecord()
	let field = CKRecordField.codable("config", TestConfig.self)
	let config = TestConfig(name: "test", value: 99)
	record[codable: field] = config
	let result: TestConfig? = record[codable: field]
	#expect(result == config)
}

@Test func ckRecord_codableSubscript_nil() {
	let record = makeRecord()
	let field = CKRecordField.codable("config", TestConfig.self)
	let result: TestConfig? = record[codable: field]
	#expect(result == nil)
}

// MARK: - Nil subscript

@Test func ckRecord_nilSubscript_clearsValue() {
	let record = makeRecord()
	let field = CKRecordField.string("title")
	record[field] = "Hello"
	#expect((record[field] as String?) == "Hello")
	record[field] = nil as String?
	#expect((record[field] as String?) == nil)
}

// MARK: - modifiedAt constant

@Test func modifiedAtFieldConstant() {
	#expect(CKRecordField<Date>.modifiedAt.name == "syncEngineModifiedAt")
}
