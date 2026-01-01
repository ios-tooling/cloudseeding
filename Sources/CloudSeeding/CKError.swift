//
//  CKError.swift
//  SyncEngine
//
//  Created by Ben Gottlieb on 10/29/24.
//

import Foundation
import CloudKit

public extension Error {
	var ckError: CKError? { self as? CKError }
}

public extension CKError {
	var isNotAuthenticated: Bool { code == .notAuthenticated }
	var isTemporarilyUnavailable: Bool { code == .accountTemporarilyUnavailable }
	var indicatesDisabledCloudKit: Bool {
		isNotAuthenticated || isTemporarilyUnavailable
	}
	
	var retryAfter: TimeInterval? {
		guard let number = userInfo[CKErrorRetryAfterKey] as? NSNumber else { return nil }
		return number.doubleValue
	}
	
	func hasErrorCode(_ code: CKError.Code) -> Bool {
		if self.code == code { return true }
		
		if let partialErrorsByItemID {
			for partial in partialErrorsByItemID.values {
				if partial.ckError?.hasErrorCode(code) == true { return true }
			}
		}
		
		return false
	}
	
	var zoneIDs: [CKRecordZone.ID] {
		guard let partialErrorsByItemID else { return [] }
		
		return partialErrorsByItemID.compactMap { id, error -> CKRecordZone.ID? in
			guard error.ckError?.hasErrorCode(.zoneNotFound) == true else { return nil }
			
			return (id as? CKRecord.ID)?.zoneID
		}
	}
}
