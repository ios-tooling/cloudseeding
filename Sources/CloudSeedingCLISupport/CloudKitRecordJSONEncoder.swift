import CloudKit
import CoreLocation
import Foundation

public struct CloudKitRecordJSONEncoder {
	private let iso8601 = ISO8601DateFormatter()

	public init() { }

	public func encode(record: CKRecord, fieldKeys: [String]? = nil) -> [String: Any] {
		let keys = (fieldKeys?.isEmpty == false ? fieldKeys! : record.allKeys()).sorted()
		var fields: [String: Any] = [:]

		for key in keys {
			guard let value = record[key] else { continue }
			fields[key] = encodeCloudKitValue(value)
		}

		var output: [String: Any] = [
			"recordType": record.recordType,
			"recordID": encode(recordID: record.recordID),
			"recordName": record.recordID.recordName,
			"zoneName": record.recordID.zoneID.zoneName,
			"ownerName": record.recordID.zoneID.ownerName,
			"fields": fields,
		]

		if let creationDate = record.creationDate {
			output["creationDate"] = iso8601.string(from: creationDate)
		}
		if let modificationDate = record.modificationDate {
			output["modificationDate"] = iso8601.string(from: modificationDate)
		}
		if let creatorUserRecordID = record.creatorUserRecordID {
			output["creatorUserRecordID"] = encode(recordID: creatorUserRecordID)
		}
		if let lastModifiedUserRecordID = record.lastModifiedUserRecordID {
			output["lastModifiedUserRecordID"] = encode(recordID: lastModifiedUserRecordID)
		}
		if let recordChangeTag = record.recordChangeTag {
			output["recordChangeTag"] = recordChangeTag
		}

		return output
	}

	public func encode(recordID: CKRecord.ID) -> [String: String] {
		[
			"recordName": recordID.recordName,
			"zoneName": recordID.zoneID.zoneName,
			"ownerName": recordID.zoneID.ownerName,
		]
	}

	public func encode(zone: CKRecordZone) -> [String: Any] {
		[
			"zoneID": encode(zoneID: zone.zoneID),
			"zoneName": zone.zoneID.zoneName,
			"ownerName": zone.zoneID.ownerName,
			"capabilities": encode(capabilities: zone.capabilities),
		]
	}

	public func encode(zoneID: CKRecordZone.ID) -> [String: String] {
		[
			"zoneName": zoneID.zoneName,
			"ownerName": zoneID.ownerName,
		]
	}

	public func encodeCloudKitValue(_ value: Any) -> Any {
		switch value {
		case let value as String:
			value
		case let value as NSNumber:
			encode(number: value)
		case let value as Date:
			iso8601.string(from: value)
		case let value as Data:
			[
				"type": "data",
				"bytes": value.count,
				"base64": value.base64EncodedString(),
			]
		case let value as CKAsset:
			encode(asset: value)
		case let value as CKRecord.Reference:
			encode(reference: value)
		case let value as CLLocation:
			encode(location: value)
		case let value as [Any]:
			value.map { encodeCloudKitValue($0) }
		default:
			String(describing: value)
		}
	}

	public static func jsonData(for object: Any, prettyPrinted: Bool = true) throws -> Data {
		var options: JSONSerialization.WritingOptions = [.sortedKeys]
		if prettyPrinted { options.insert(.prettyPrinted) }
		return try JSONSerialization.data(withJSONObject: object, options: options)
	}

	private func encode(number: NSNumber) -> Any {
		let type = String(cString: number.objCType)
		switch type {
		case "c", "B":
			return number.boolValue
		case "s", "i", "l", "q", "S", "I", "L", "Q":
			return number.int64Value
		default:
			return number.doubleValue
		}
	}

	private func encode(asset: CKAsset) -> [String: Any] {
		var output: [String: Any] = ["type": "asset"]
		if let fileURL = asset.fileURL {
			output["path"] = fileURL.path
			if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
				let size = attributes[.size] as? NSNumber {
				output["bytes"] = size.int64Value
			}
		}
		return output
	}

	private func encode(reference: CKRecord.Reference) -> [String: Any] {
		[
			"type": "reference",
			"recordID": encode(recordID: reference.recordID),
			"action": encode(referenceAction: reference.action),
		]
	}

	private func encode(referenceAction: CKRecord.ReferenceAction) -> String {
		switch referenceAction {
		case .none: "none"
		case .deleteSelf: "deleteSelf"
		@unknown default: "unknown"
		}
	}

	private func encode(location: CLLocation) -> [String: Any] {
		[
			"type": "location",
			"latitude": location.coordinate.latitude,
			"longitude": location.coordinate.longitude,
			"altitude": location.altitude,
			"horizontalAccuracy": location.horizontalAccuracy,
			"verticalAccuracy": location.verticalAccuracy,
			"timestamp": iso8601.string(from: location.timestamp),
		]
	}

	private func encode(capabilities: CKRecordZone.Capabilities) -> [String] {
		var values: [String] = []
		if capabilities.contains(.fetchChanges) { values.append("fetchChanges") }
		if capabilities.contains(.atomic) { values.append("atomic") }
		if capabilities.contains(.sharing) { values.append("sharing") }
		if capabilities.contains(.zoneWideSharing) { values.append("zoneWideSharing") }
		return values
	}
}
