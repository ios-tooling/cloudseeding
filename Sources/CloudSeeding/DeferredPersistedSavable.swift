//
//  File.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 12/25/25.
//

import CloudKit
import Foundation
import SwiftData

@available(iOS 17.0, macOS 14, *)
public protocol DeferredPersistedSavable: PersistentModel {
	var pendingCloudRecordData: Data? { get set }
	var pendingCloudRecord: CKRecord? { get set }
}

@available(iOS 17.0, macOS 14, *)
public extension DeferredPersistedSavable {
	/// Saves to CloudKit, parking the record for a later retry on failure. The
	/// failure (if any) is returned so callers can surface it instead of
	/// treating a deferred save as a completed one.
	@discardableResult
	nonisolated(nonsending) func save(record: CKRecord, to database: CKDatabase) async -> Error? {
		let id = persistentModelID
		guard let container = modelContext?.container else {
			logger.warning("Trying to save a non-inserted \(Self.self) record, failing.")
			return CloudSeedingError.notAvailable
		}
		do {
			try await CloudComms.instance.save(record: record, to: database)
			// The record reached CloudKit; any copy parked by an earlier failure is obsolete.
			let ctx = ModelContext(container)
			if let model = ctx.model(for: id) as? any DeferredPersistedSavable { model.pendingCloudRecord = nil }
			return nil
		} catch {
			let ctx = ModelContext(container)
			guard let model = ctx.model(for: id) as? any DeferredPersistedSavable else {
				logger.error("Failed to resolve \(Self.self) for deferred save: model ID mismatch")
				return error
			}
			model.pendingCloudRecord = record
			return error
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
			logger.error("Failed to save DeferredPersistedSavable \(Self.self): \(error)")
		}
	}
	
}
