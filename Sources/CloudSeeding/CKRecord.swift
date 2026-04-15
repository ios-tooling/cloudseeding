//
//  CKRecord.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 8/15/25.
//

import Foundation
import CloudKit
import CoreLocation

@available(iOS 17.0, macOS 14, *)
public extension CKRecord {
	var createdByRecordID: String? {
		let name = self.creatorUserRecordID?.recordName
		return name == CKCurrentUserDefaultName ? CloudKitInterface.currentUserID : name
	}

	var approximateSize: Int {
		allKeys().reduce(0) { total, key in
			total + approximateSize(of: self[key])
		}
	}

	private func approximateSize(of value: CKRecordValue?) -> Int {
		switch value {
		case let string as String: return string.utf8.count
		case let data as Data: return data.count
		case is NSNumber: return MemoryLayout<Double>.size
		case is Date: return MemoryLayout<Date>.size
		case let asset as CKAsset:
			guard let url = asset.fileURL,
					let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
					let size = attrs[.size] as? Int else { return 0 }
			return size
		case let array as [CKRecordValue]:
			return array.reduce(0) { $0 + approximateSize(of: $1) }
		case is CLLocation: return MemoryLayout<CLLocationCoordinate2D>.size
		case let reference as CKRecord.Reference: return reference.recordID.recordName.utf8.count
		default: return 0
		}
	}
}
