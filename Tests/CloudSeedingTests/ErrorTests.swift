import Testing
import CloudKit
@testable import CloudSeeding

func makeCKError(code: CKError.Code, userInfo: [String: Any] = [:]) -> CKError {
	CKError(_nsError: NSError(domain: CKErrorDomain, code: code.rawValue, userInfo: userInfo) as NSError)
}

// MARK: - String.extractedZoneID

@Test func extractedZoneID_validPattern() {
	#expect("zoneID=MyZone:ownerName".extractedZoneID == "MyZone")
}

@Test func extractedZoneID_noMatch() {
	#expect("no zone here".extractedZoneID == nil)
}

@Test func extractedZoneID_multipleColons() {
	#expect("zoneID=Zone1:owner:extra".extractedZoneID == "Zone1")
}

@Test func extractedZoneID_emptyString() {
	#expect("".extractedZoneID == nil)
}

@Test func extractedZoneID_missingColon() {
	#expect("zoneID=MyZone".extractedZoneID == nil)
}

@Test func extractedZoneID_embeddedInLongerString() {
	#expect("Error occurred in zoneID=TestZone:owner for record".extractedZoneID == "TestZone")
}

// MARK: - Error.errorChain

@Test func errorChain_singleError() {
	let error = NSError(domain: "test", code: 1)
	#expect(error.errorChain.count == 1)
}

@Test func errorChain_nestedErrors() {
	let innermost = NSError(domain: "inner", code: 3)
	let middle = NSError(domain: "middle", code: 2, userInfo: [NSUnderlyingErrorKey: innermost])
	let outer = NSError(domain: "outer", code: 1, userInfo: [NSUnderlyingErrorKey: middle])

	let chain = outer.errorChain
	#expect(chain.count == 3)
	#expect((chain[0] as NSError).domain == "outer")
	#expect((chain[1] as NSError).domain == "middle")
	#expect((chain[2] as NSError).domain == "inner")
}

// MARK: - Error.detailedDescription

@Test func detailedDescription_plainError() {
	let error = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Something went wrong"])
	let desc = error.detailedDescription
	#expect(desc.contains("TestDomain"))
	#expect(desc.contains("42"))
	#expect(desc.contains("Something went wrong"))
}

@Test func detailedDescription_withPartialErrors() {
	let recordID = CKRecord.ID(recordName: "rec1", zoneID: CKRecordZone.ID(zoneName: "Zone1", ownerName: CKCurrentUserDefaultName))
	let partialError = NSError(domain: CKErrorDomain, code: CKError.Code.zoneNotFound.rawValue, userInfo: [:])
	let ckError = makeCKError(code: .partialFailure, userInfo: [
		CKPartialErrorsByItemIDKey: [recordID: partialError]
	])

	let desc = ckError.detailedDescription
	#expect(desc.contains("CKErrorDomain"))
}

// MARK: - Error.zoneID

@Test func zoneID_fromDescription() {
	let error = NSError(domain: "test", code: 1, userInfo: [
		NSLocalizedDescriptionKey: "Failed for zoneID=TestZone:owner"
	])
	let zone = error.zoneID
	#expect(zone?.zoneName == "TestZone")
}

@Test func zoneID_noMatch() {
	let error = NSError(domain: "test", code: 1, userInfo: [
		NSLocalizedDescriptionKey: "No zone info here"
	])
	#expect(error.zoneID == nil)
}

@Test func zoneID_noDescription() {
	let error = NSError(domain: "test", code: 1)
	#expect(error.zoneID == nil)
}

// MARK: - Error.recursiveZoneID

@Test func recursiveZoneID_findsInChain() {
	let inner = NSError(domain: "inner", code: 2, userInfo: [
		NSLocalizedDescriptionKey: "zoneID=DeepZone:owner"
	])
	let outer = NSError(domain: "outer", code: 1, userInfo: [
		NSUnderlyingErrorKey: inner
	])
	#expect(outer.recursiveZoneID?.zoneName == "DeepZone")
}

@Test func recursiveZoneID_noneInChain() {
	let inner = NSError(domain: "inner", code: 2)
	let outer = NSError(domain: "outer", code: 1, userInfo: [NSUnderlyingErrorKey: inner])
	#expect(outer.recursiveZoneID == nil)
}

// MARK: - CKError boolean properties

@Test func ckError_isNotAuthenticated() {
	#expect(makeCKError(code: .notAuthenticated).isNotAuthenticated == true)
	#expect(makeCKError(code: .networkFailure).isNotAuthenticated == false)
}

@Test func ckError_isTemporarilyUnavailable() {
	#expect(makeCKError(code: .accountTemporarilyUnavailable).isTemporarilyUnavailable == true)
	#expect(makeCKError(code: .networkFailure).isTemporarilyUnavailable == false)
}

@Test func ckError_indicatesDisabledCloudKit() {
	#expect(makeCKError(code: .notAuthenticated).indicatesDisabledCloudKit == true)
	#expect(makeCKError(code: .accountTemporarilyUnavailable).indicatesDisabledCloudKit == true)
	#expect(makeCKError(code: .networkFailure).indicatesDisabledCloudKit == false)
}

// MARK: - CKError.retryAfter

@Test func ckError_retryAfter_present() {
	let error = makeCKError(code: .requestRateLimited, userInfo: [
		CKErrorRetryAfterKey: NSNumber(value: 30.0)
	])
	#expect(error.retryAfter == 30.0)
}

@Test func ckError_retryAfter_absent() {
	let error = makeCKError(code: .requestRateLimited)
	#expect(error.retryAfter == nil)
}

// MARK: - CKError.hasErrorCode

@Test func ckError_hasErrorCode_directMatch() {
	let error = makeCKError(code: .zoneNotFound)
	#expect(error.hasErrorCode(.zoneNotFound) == true)
	#expect(error.hasErrorCode(.networkFailure) == false)
}

@Test func ckError_hasErrorCode_inPartials() {
	let recordID = CKRecord.ID(recordName: "rec1", zoneID: CKRecordZone.ID(zoneName: "Zone1", ownerName: CKCurrentUserDefaultName))
	let partialError = NSError(domain: CKErrorDomain, code: CKError.Code.zoneNotFound.rawValue, userInfo: [:])
	let error = makeCKError(code: .partialFailure, userInfo: [
		CKPartialErrorsByItemIDKey: [recordID: partialError]
	])
	#expect(error.hasErrorCode(.zoneNotFound) == true)
	#expect(error.hasErrorCode(.networkFailure) == false)
}

// MARK: - CKError.zoneIDs

@Test func ckError_zoneIDs_extractsFromPartials() {
	let zoneID = CKRecordZone.ID(zoneName: "TargetZone", ownerName: CKCurrentUserDefaultName)
	let recordID = CKRecord.ID(recordName: "rec1", zoneID: zoneID)
	let partialError = NSError(domain: CKErrorDomain, code: CKError.Code.zoneNotFound.rawValue, userInfo: [:])
	let error = makeCKError(code: .partialFailure, userInfo: [
		CKPartialErrorsByItemIDKey: [recordID: partialError]
	])

	let zones = error.zoneIDs
	#expect(zones.count == 1)
	#expect(zones.first?.zoneName == "TargetZone")
}

@Test func ckError_zoneIDs_emptyWhenNoPartials() {
	let error = makeCKError(code: .networkFailure)
	#expect(error.zoneIDs.isEmpty)
}

// MARK: - Error.ckError

@Test func error_ckError_castSuccess() {
	let error: Error = makeCKError(code: .networkFailure)
	#expect(error.ckError != nil)
	#expect(error.ckError?.code == .networkFailure)
}

@Test func error_ckError_castFailure() {
	let error: Error = NSError(domain: "other", code: 1)
	#expect(error.ckError == nil)
}

// MARK: - MultipleError.build

@Test func multipleError_build_empty() {
	#expect(MultipleError.build([]) == nil)
}

@Test func multipleError_build_single() {
	let single = NSError(domain: "test", code: 1)
	let result = MultipleError.build([single])
	#expect((result as? NSError)?.domain == "test")
	#expect(result is MultipleError == false)
}

@Test func multipleError_build_multiple() {
	let e1 = NSError(domain: "a", code: 1)
	let e2 = NSError(domain: "b", code: 2)
	let result = MultipleError.build([e1, e2])
	let multi = result as? MultipleError
	#expect(multi != nil)
	#expect(multi?.errors.count == 2)
}
