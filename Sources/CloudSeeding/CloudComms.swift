//
//  CloudComms.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 12/26/25.
//

import CloudKit
import Suite


actor CloudComms {
	static let instance = CloudComms()
	
	var cooldownEndsAt: Date?
	var isOffline = false
	
	enum CloudError: Error {
		case offline
		case coolingDown
		case unableToSave(Error)
		case tryLater
		case recordProblem(Error)
	}
	
	func setOnline() {
		isOffline = false
	}
	
	func save(record: CKRecord, to database: CKDatabase) async throws {
		if isOffline { throw CloudError.coolingDown }
		if let cooldownEndsAt {
			if cooldownEndsAt.isInFuture { throw CloudError.coolingDown }
			self.cooldownEndsAt = nil
		}
		
		do {
			try await database.save(record)
		} catch let error as CKError {
			try handleCKError(error)
		}
	}
	
	func handleCKError(_ error: CKError) throws {
		switch error.code as CKError.Code {
		case .accountTemporarilyUnavailable: throw CloudError.tryLater
		case .badContainer, .badDatabase: throw CloudError.unableToSave(error)
		case .internalError: throw CloudError.tryLater
		case .partialFailure:  throw CloudError.recordProblem(error)
		case .networkUnavailable: throw CloudError.tryLater
		case .networkFailure:
			isOffline = true
			throw CloudError.tryLater
		case .serviceUnavailable: throw CloudError.tryLater
		case .requestRateLimited:
			if let retryAfter = error.retryAfterSeconds {
				self.cooldownEndsAt = Date.now.addingTimeInterval(retryAfter)
			}
			throw CloudError.tryLater
		case .missingEntitlement: throw CloudError.unableToSave(error)
		case .notAuthenticated: throw CloudError.tryLater
		case .permissionFailure: throw CloudError.recordProblem(error)
		case .unknownItem: throw CloudError.recordProblem(error)
		case .invalidArguments: throw CloudError.unableToSave(error)
		case .resultsTruncated: throw CloudError.unableToSave(error)
		case .serverRecordChanged: throw CloudError.recordProblem(error)
		case .serverRejectedRequest: throw CloudError.recordProblem(error)
		case .assetFileNotFound: throw CloudError.unableToSave(error)
		case .assetFileModified: throw CloudError.unableToSave(error)
		case .incompatibleVersion: throw CloudError.recordProblem(error)
		case .constraintViolation: throw CloudError.recordProblem(error)
		case .operationCancelled: throw CloudError.tryLater
		case .changeTokenExpired: throw CloudError.tryLater
		case .batchRequestFailed: throw CloudError.recordProblem(error)
		case .zoneBusy: throw CloudError.tryLater
		case .quotaExceeded: throw CloudError.tryLater
		case .zoneNotFound: throw CloudError.recordProblem(error)
		case .limitExceeded: throw CloudError.tryLater
		case .userDeletedZone: throw CloudError.recordProblem(error)
		case .tooManyParticipants: throw CloudError.unableToSave(error)
		case .alreadyShared: throw CloudError.recordProblem(error)
		case .referenceViolation: throw CloudError.recordProblem(error)
		case .managedAccountRestricted: throw CloudError.unableToSave(error)
		case .participantMayNeedVerification: throw CloudError.recordProblem(error)
		case .serverResponseLost: throw CloudError.tryLater
		case .assetNotAvailable: throw CloudError.unableToSave(error)
		case .participantAlreadyInvited: throw CloudError.recordProblem(error)
		@unknown default: throw error
		}
	}
}
