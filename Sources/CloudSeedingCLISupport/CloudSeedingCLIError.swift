import Foundation

public enum CloudSeedingCLIError: Error, Equatable, CustomStringConvertible {
	case usage(String)
	case unknownCommand(String)
	case unknownOption(String)
	case missingValue(String)
	case missingRequiredOption(String)
	case invalidDatabase(String)
	case invalidLimit(String)
	case invalidPredicate(String)
	case unavailableAccount(String)

	public var description: String {
		switch self {
		case .usage(let message): message
		case .unknownCommand(let command): "Unknown command: \(command)"
		case .unknownOption(let option): "Unknown option: \(option)"
		case .missingValue(let option): "Missing value for \(option)"
		case .missingRequiredOption(let option): "Missing required option: \(option)"
		case .invalidDatabase(let value): "Invalid database: \(value). Expected private, public, or shared."
		case .invalidLimit(let value): "Invalid limit: \(value). Use a positive integer, 0 for all results, or --all."
		case .invalidPredicate(let value): "Invalid predicate: \(value)"
		case .unavailableAccount(let status): "CloudKit account is not available for this database: \(status)"
		}
	}
}
