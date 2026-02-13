//
//  CKRecordBased.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 7/25/25.
//

import Foundation
import CloudKit
import SwiftData

public protocol CKRecordBased: AnyObject {
	var cachedRecordData: Data? { get set }
	
	func populateCloudRecord(_ record: CKRecord)
	
	var ckRecordName: String { get }
	var ckRecordID: CKRecord.ID { get }
	static var ckRecordType: CKRecord.RecordType { get }
	var ckRecordZoneID: CKRecordZone.ID { get }
}


extension CKRecordBased {
	public var ckRecordID: CKRecord.ID { CKRecord.ID(recordName: ckRecordName, zoneID: ckRecordZoneID) }

	public func updateCloudRecord(_ record: CKRecord) {
		populateCloudRecord(record)
		if let modifiedAt = (self as? any PersistedCKRecord)?.modifiedAt, record[.modifiedAt] != modifiedAt {
			record[.modifiedAt] = modifiedAt
		}
	}
	
	public var ckRecord: CKRecord {
		if let record = lastKnownRecord {
			updateCloudRecord(record)
			self.lastKnownRecord = record
			return record
		}
		
		let record = CKRecord(recordType: Self.ckRecordType, recordID: ckRecordID)
		updateCloudRecord(record)
		self.lastKnownRecord = record
		return record
	}
	
	var rawLastKnownRecord: CKRecord? {
		guard let data = cachedRecordData else { return nil }
		guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
		unarchiver.requiresSecureCoding = true
		return CKRecord(coder: unarchiver)
	}
	
	public var lastKnownRecord: CKRecord? {
		get {
			rawLastKnownRecord
		}
		
		set {
			if let newValue {
				if let old = rawLastKnownRecord?.modificationDate, let new = newValue.modificationDate, old > new { return }
				let archiver = NSKeyedArchiver(requiringSecureCoding: true)
				newValue.encode(with: archiver)
				self.cachedRecordData = archiver.encodedData
			} else {
				self.cachedRecordData = nil
			}
		}
	}
}

