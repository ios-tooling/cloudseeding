//
//  File.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 12/25/25.
//

import CloudKit
import Foundation
import SwiftData

public protocol DeferredPersistedSavable: PersistentModel {
	var pendingCloudRecordData: Data? { get set }
	var pendingCloudRecord: CKRecord? { get set }
}

public extension DeferredPersistedSavable {
	func save(record: CKRecord, to database: CKDatabase) async {
		let id = persistentModelID
		guard let container = modelContext?.container else {
			print("Trying to save a non-inserted record, failing.")
			return
		}
		do {
			try await CloudComms.instance.save(record: record, to: database)
		} catch {
			let ctx = ModelContext(container)
			guard let model = ctx.model(for: id) as? any DeferredPersistedSavable else {
				print("Trying to save a mismatched object.")
				return
			}
			model.pendingCloudRecord = record
		}
	}
	
	var pendingCloudRecord: CKRecord? {
		get {
			guard let data = pendingCloudRecordData else { return nil }
			
			guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
			unarchiver.requiresSecureCoding = true
			return CKRecord(coder: unarchiver)
		}
		set {
			guard let newValue else {
				clearPendingCloudRecordData()
				return
			}
			
			let archiver = NSKeyedArchiver(requiringSecureCoding: true)
			newValue.encode(with: archiver)
			let data = archiver.encodedData
			
			if data != pendingCloudRecordData {
				pendingCloudRecordData = data
				recordedSave()
			}
		}
	}
	
	func clearPendingCloudRecordData() {
		guard pendingCloudRecordData != nil else { return }
		
		pendingCloudRecordData = nil
		recordedSave()
	}
	
	func recordedSave() {
		do {
			try modelContext?.save()
		} catch {
			print("Failed to saved DeferredPersistedSavable \(Self.self): \(error)")
		}
	}
	
}
