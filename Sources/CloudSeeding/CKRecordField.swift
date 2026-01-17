//
//  CKRecordField.swift
//  SyncEngine
//
//  Created by Ben Gottlieb on 10/26/24.
//

import Suite
import CloudKit
import UniformTypeIdentifiers

public struct CKRecordField<DataType>: Sendable {
	public let name: String
	public let dataType: DataType.Type
	
	var isPrimitiveField: Bool {
		DataType.self == Bool.Type.self || DataType.self == Int.Type.self || DataType.self == Double.Type.self || DataType.self == String.Type.self || DataType.self == Date.Type.self || DataType.self == Data.Type.self
	}
}

extension CKRecordField where DataType == Bool {
	public static func bool(_ name: String) -> Self { .init(name: name, dataType: Bool.self) }
}

extension CKRecordField where DataType == Int {
	public static func int(_ name: String) -> Self { .init(name: name, dataType: Int.self) }
}

extension CKRecordField where DataType == Double {
	public static func double(_ name: String) -> Self { .init(name: name, dataType: Double.self) }
}

extension CKRecordField where DataType == String {
	public static func string(_ name: String) -> Self { .init(name: name, dataType: String.self) }
}

extension CKRecordField where DataType == [String] {
	public static func stringArray(_ name: String) -> Self { .init(name: name, dataType: [String].self) }
}

extension CKRecordField where DataType == [Date] {
	public static func dateArray(_ name: String) -> Self { .init(name: name, dataType: [Date].self) }
}

extension CKRecordField where DataType == [Double] {
	public static func doubleArray(_ name: String) -> Self { .init(name: name, dataType: [Double].self) }
}

extension CKRecordField where DataType == Date {
	public static func date(_ name: String) -> Self { .init(name: name, dataType: Date.self) }
}

extension CKRecordField where DataType == URL {
	public static func url(_ name: String) -> Self { .init(name: name, dataType: URL.self) }
}

extension CKRecordField where DataType == [URL] {
	public static func urls(_ name: String) -> Self { .init(name: name, dataType: [URL].self) }
}

extension CKRecordField where DataType == Data {
	public static func data(_ name: String) -> Self { .init(name: name, dataType: Data.self) }
}

extension CKRecordField where DataType == [Data] {
	public static func dataArray(_ name: String) -> Self { .init(name: name, dataType: [Data].self) }
}

extension CKRecordField where DataType: Codable {
	public static func codable(_ name: String, _ type: DataType.Type) -> Self {
		.init(name: name, dataType: DataType.self)
	}
}

extension CKAsset {
	public static let ckRecordAttachmentsDirectory = URL.document(named: "cloudkit-assets")
	
	func localAssetURL(for type: UTType) -> URL? {
		guard let fileURL else { return nil }
		let filename = (try? fileURL.md5) ?? fileURL.lastPathComponent
		let full = Self.ckRecordAttachmentsDirectory.appendingPathComponent(filename, conformingTo: type)
		try? FileManager.default.createDirectory(at: Self.ckRecordAttachmentsDirectory, withIntermediateDirectories: true)

		if !FileManager.default.fileExists(at: full), FileManager.default.fileExists(at: fileURL) {
			try? FileManager.default.moveItem(at: fileURL, to: full)
		}
		return full
	}
}

extension CKRecord {
	public subscript(field: CKRecordField<URL>, type: UTType) -> URL? {
		get {
			if let url = self[field.name] as? URL { return url }
			return (self[field.name] as? CKAsset)?.localAssetURL(for: type)?.removingHomeDirectory
		}
		set {
			guard let url = newValue else {
				self[field.name] = nil
				return
			}
			
			self[field.name] = CKAsset(fileURL: url.addingHomeDirectory)
		}
	}
	
	public subscript(field: CKRecordField<[URL]>, type: UTType) -> [URL]? {
		get { (self[field.name] as? [CKAsset])?.compactMap { $0.localAssetURL(for: type)?.removingHomeDirectory } }
		set { self[field.name] = newValue?.map { CKAsset(fileURL: $0.addingHomeDirectory) }}
	}
	
	public subscript<Result>(field: CKRecordField<Result>) -> Result? {
		get { self[field.name] as? Result }
		set { self[field.name] = newValue as? CKRecordValue }
	}

	public subscript<Result: Equatable>(field: CKRecordField<Result>) -> Result? {
		get { self[field.name] as? Result }
		set {
			let existing = self[field.name] as? Result
			if existing == newValue { return }
			self[field.name] = newValue as? CKRecordValue
		}
	}

	public subscript<Result: Codable>(codable field: CKRecordField<Result>) -> Result? {
		get {
			if let data = self[field.name] as? Data {
				return try? Result.loadJSON(data: data)
			}
			return nil
		}
		set { self[field.name] = try? newValue?.asJSONData() as? CKRecordValue}
	}
}

extension CKRecordField<Date> {
	public static let modifiedAt = CKRecordField.date("syncEngineModifiedAt")
}
