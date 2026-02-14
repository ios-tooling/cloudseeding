//
//  Error.swift
//  SyncEngine
//
//  Created by Ben Gottlieb on 8/17/25.
//

import Foundation
import CloudKit

extension Error {
	public var errorChain: [Error] {
		var result: [any Error] = [self]
		
		if let underlying = (self as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
			result += underlying.errorChain
		}
		return result
	}
	
	public var detailedDescription: String {
		var base = ""
		
		base += "\((self as NSError).domain) \((self as NSError).code)\n"
		base += self.localizedDescription + "\n"
		
		if let ckError = self as? CKError {
			if let partials = ckError.partialErrorsByItemID as? [CKRecord.ID: CKError] {
				partials.forEach { id, err in
					base += "\n\t•\(id): \(err.detailedDescription)"
				}
			}
		}
		
		return base
	}
	
	public var zoneID: CKRecordZone.ID? {
		let info = (self as NSError).userInfo
		if let zoneID = (info[NSLocalizedDescriptionKey] as? String)?.extractedZoneID {
			return CKRecordZone.ID(zoneName: zoneID)
		}
		return nil
	}
	
	public var recursiveZoneID: CKRecordZone.ID? {
		for error in errorChain {
			if let id = error.zoneID { return id }
		}
		return nil
	}
}

extension String {
	public var extractedZoneID: String? {
		do {
			let pattern = "zoneID=([^:]+):" // Capture only up to the first colon
			let regex = try NSRegularExpression(pattern: pattern, options: [])
			let nsString = self as NSString
			let results = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
			
			if let match = results.first {
				let range = match.range(at: 1) // Get the first capture group
				if range.location != NSNotFound {
					let zoneID = nsString.substring(with: range)
					return zoneID
				}
			}
		} catch {
			logger.error("Regex error extracting zoneID: \(error)")
		}
		return nil
	}
}
