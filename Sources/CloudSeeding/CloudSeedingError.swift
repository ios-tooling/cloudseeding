//
//  File.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 7/26/25.
//

import Foundation
import os

let logger = Logger(subsystem: "CloudSeeding", category: "sync")

public enum CloudSeedingError: Error { case offline, notAvailable, notConfigured, recordNotFound }

public struct MultipleError: Error {
	public var errors: [any Error]

	public static func build(_ errors: [any Error]) -> (any Error)? {
		if errors.isEmpty { return nil }
		if errors.count == 1 { return errors[0] }
		return MultipleError(errors: errors)
	}
}
