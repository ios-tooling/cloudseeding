//
//  SaveRecordOperation.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 7/26/25.
//

import Foundation
import CloudKit
import os

class SaveRecordOperation: CKModifyRecordsOperation, @unchecked Sendable {
	convenience init(record: CKRecord) {
		self.init(recordsToSave: [record])
	}

	func save(to database: CKDatabase) async throws -> CKRecord {

		try await withCheckedThrowingContinuation { continuation in
			let hasResumed = OSAllocatedUnfairLock(initialState: false)

			self.perRecordSaveBlock = { recordID, result in
				let alreadyResumed = hasResumed.withLock { value -> Bool in
					if value { return true }
					value = true
					return false
				}
				guard !alreadyResumed else { return }
				switch result {
				case .success(let newRecord):
					continuation.resume(returning: newRecord)

				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}

			self.modifyRecordsResultBlock = { result in
				let alreadyResumed = hasResumed.withLock { value -> Bool in
					if value { return true }
					value = true
					return false
				}
				guard !alreadyResumed else { return }
				switch result {
				case .success:
					// Should not reach here without perRecordSaveBlock being called,
					// but handle defensively
					continuation.resume(throwing: CloudSeedingError.recordNotFound)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}

			qualityOfService = .userInitiated
			database.add(self)
		}
	}
}
