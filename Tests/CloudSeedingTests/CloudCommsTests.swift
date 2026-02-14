import Testing
import CloudKit
@testable import CloudSeeding

// MARK: - handleCKError mapping tests

@Test(arguments: [
	CKError.Code.accountTemporarilyUnavailable,
	CKError.Code.internalError,
	CKError.Code.networkUnavailable,
	CKError.Code.serviceUnavailable,
	CKError.Code.notAuthenticated,
	CKError.Code.operationCancelled,
	CKError.Code.changeTokenExpired,
	CKError.Code.zoneBusy,
	CKError.Code.quotaExceeded,
	CKError.Code.limitExceeded,
	CKError.Code.serverResponseLost,
])
func handleCKError_mapsToTryLater(code: CKError.Code) async {
	let comms = CloudComms()
	let error = makeCKError(code: code)
	do {
		try await comms.handleCKError(error)
		Issue.record("Expected handleCKError to throw for code \(code)")
	} catch {
		guard case CloudComms.CloudError.tryLater = error else {
			Issue.record("Expected .tryLater for code \(code), got \(error)")
			return
		}
	}
}

@Test(arguments: [
	CKError.Code.badContainer,
	CKError.Code.badDatabase,
	CKError.Code.missingEntitlement,
	CKError.Code.invalidArguments,
	CKError.Code.resultsTruncated,
	CKError.Code.assetFileNotFound,
	CKError.Code.assetFileModified,
	CKError.Code.tooManyParticipants,
	CKError.Code.managedAccountRestricted,
	CKError.Code.assetNotAvailable,
])
func handleCKError_mapsToUnableToSave(code: CKError.Code) async {
	let comms = CloudComms()
	let error = makeCKError(code: code)
	do {
		try await comms.handleCKError(error)
		Issue.record("Expected handleCKError to throw for code \(code)")
	} catch {
		guard case CloudComms.CloudError.unableToSave = error else {
			Issue.record("Expected .unableToSave for code \(code), got \(error)")
			return
		}
	}
}

@Test(arguments: [
	CKError.Code.partialFailure,
	CKError.Code.permissionFailure,
	CKError.Code.unknownItem,
	CKError.Code.serverRecordChanged,
	CKError.Code.serverRejectedRequest,
	CKError.Code.incompatibleVersion,
	CKError.Code.constraintViolation,
	CKError.Code.batchRequestFailed,
	CKError.Code.zoneNotFound,
	CKError.Code.userDeletedZone,
	CKError.Code.alreadyShared,
	CKError.Code.referenceViolation,
	CKError.Code.participantMayNeedVerification,
])
func handleCKError_mapsToRecordProblem(code: CKError.Code) async {
	let comms = CloudComms()
	let error = makeCKError(code: code)
	do {
		try await comms.handleCKError(error)
		Issue.record("Expected handleCKError to throw for code \(code)")
	} catch {
		guard case CloudComms.CloudError.recordProblem = error else {
			Issue.record("Expected .recordProblem for code \(code), got \(error)")
			return
		}
	}
}

// MARK: - Side effects

@Test func handleCKError_networkFailureSetsOffline() async {
	let comms = CloudComms()
	let error = makeCKError(code: .networkFailure)

	let wasOfflineBefore = await comms.isOffline
	#expect(wasOfflineBefore == false)

	do {
		try await comms.handleCKError(error)
		Issue.record("Expected throw")
	} catch {
		guard case CloudComms.CloudError.tryLater = error else {
			Issue.record("Expected .tryLater, got \(error)")
			return
		}
	}

	let isOfflineAfter = await comms.isOffline
	#expect(isOfflineAfter == true)
}

@Test func handleCKError_requestRateLimitedSetsCooldown() async {
	let comms = CloudComms()
	let error = makeCKError(code: .requestRateLimited, userInfo: [
		CKErrorRetryAfterKey: NSNumber(value: 60.0)
	])

	let cooldownBefore = await comms.cooldownEndsAt
	#expect(cooldownBefore == nil)

	do {
		try await comms.handleCKError(error)
		Issue.record("Expected throw")
	} catch {
		guard case CloudComms.CloudError.tryLater = error else {
			Issue.record("Expected .tryLater, got \(error)")
			return
		}
	}

	let cooldownAfter = await comms.cooldownEndsAt
	#expect(cooldownAfter != nil)
}
