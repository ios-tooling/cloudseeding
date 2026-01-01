//
//  File.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 7/26/25.
//

import Foundation

enum CloudSeedingError: Error { case offline, notAvailable, recordNotFound }

struct MultipleError: Error {
	var errors: [any Error]
	
	static func build(_ errors: [any Error]) -> (any Error)? {
		if errors.isEmpty { return nil }
		if errors.count == 1 { return errors[0] }
		return MultipleError(errors: errors)
	}
}
