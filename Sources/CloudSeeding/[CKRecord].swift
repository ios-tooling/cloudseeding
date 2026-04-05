//
//  CKRecord.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 8/15/25.
//

import Foundation
import CloudKit
import CoreLocation

public extension [CKRecord] {
	var typeCounts: [String: Int] {
		var types: [String: Int] = [:]
		
		for record in self {
			let type = record.recordType
			types[type, default: 0] += 1
		}
		return types
	}
	
	var typeCountDescription: String {
		let types = typeCounts
		
		return types.keys.map { "\($0): \(types[$0]!)" }.joined(separator: ", ")
	}
}
