//
//  PersistedCKRecord.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 7/25/25.
//

import CloudKit
import Suite
import SwiftData

public enum NewerRecord: String { case localNewer, serverNewer, unknownNewer }

public protocol PersistedCKRecord: CKRecordBased & PersistentModel, PresavablePersistentModel {
	var modifiedAt: Date { get set }
	var changeRecordedAt: Date? { get set }
	var syncEngineID: String { get set }
	init()
	func resolveConflict(with cloudRecord: CKRecord, newer: NewerRecord, context: ModelContext)
	func load(fromCloud record: CKRecord, context: ModelContext) -> Bool
	func presave()
	func removeFromContext()

	/// Predicates are being 'optimized' into failure by Release builds.
	/// We need to provide concrete FetchDescriptors for each record type.
	static func fetchDescriptor(forSyncEngineID id: String) -> FetchDescriptor<Self>
	static func modifiedRecordsFetchDescriptor() -> FetchDescriptor<Self>
	static func syncFlagResetFetchDescriptor() -> FetchDescriptor<Self>

	/// Fetches an existing record by sync engine ID using a concrete predicate.
	/// These can be called through an existential type without generic bridging issues.
	static func fetchExisting(id: String, in context: ModelContext) -> (any PersistedCKRecord)?

	/// Fetches an existing record or creates a new one from a CKRecord.
	/// Called through existential types to avoid generic bridging issues in release builds.
	@discardableResult static func fetchOrCreateFromCloud(record: CKRecord, in context: ModelContext) -> (any PersistedCKRecord)?
}

public extension PersistedCKRecord {
	init?(record: CKRecord, context: ModelContext) {
		self.init()
		changeRecordedAt = nil
		syncEngineID = record.recordID.recordName
		if let mod = record[.modifiedAt] {
			self.modifiedAt = mod
		} else {
			self.modifiedAt = record.modificationDate ?? .now
		}
		lastKnownRecord = record
		if !load(fromCloud: record, context: context) { return nil }
	}

	func newerRecord(than cloudRecord: CKRecord) -> NewerRecord {
		guard let cloudModifiedAt = cloudRecord.modificationDate else { return .unknownNewer }
		if cloudModifiedAt > modifiedAt { return .serverNewer }
		return .localNewer
	}

	func presave() { }
	
	func reportedSave() {
		guard let modelContext else {
			logger.warning("Trying to save a \(Self.self) record without a model context")
			return
		}

		do {
			modelContext.presave()
			try modelContext.save()
		} catch {
			logger.error("Failed to save record \(Self.self): \(error)")
		}
	}
	
	func removeFromContext() {
		modelContext?.delete(self)
	}

	static func fetchExisting(id: String, in context: ModelContext) -> (any PersistedCKRecord)? {
		try? context.fetch(fetchDescriptor(forSyncEngineID: id)).first
	}

	@discardableResult static func fetchOrCreateFromCloud(record: CKRecord, in context: ModelContext) -> (any PersistedCKRecord)? {
		if let existing = fetchExisting(id: record.recordID.recordName, in: context) {
			return existing
		}

		// Create the object and insert it into the context BEFORE calling
		// load(fromCloud:), so that relationship assignments in load()
		// (e.g. page.thumbnailAsset = self) don't involve an unmanaged object,
		// which can cause duplicate registration errors in SwiftData.
		let new = Self()
		new.changeRecordedAt = nil
		new.syncEngineID = record.recordID.recordName
		if let mod = record[.modifiedAt] {
			new.modifiedAt = mod
		} else {
			new.modifiedAt = record.modificationDate ?? .now
		}
		new.lastKnownRecord = record
		context.insert(new)

		if new.load(fromCloud: record, context: context) {
			new.lastKnownRecord = record
			return new
		} else {
			context.delete(new)
			return nil
		}
	}
}

