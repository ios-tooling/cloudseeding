import Foundation

public enum CloudSeedingDatabaseScope: String, CaseIterable, Equatable {
	case `private`
	case `public`
	case shared
}

public struct CloudSeedingGlobalOptions: Equatable {
	public var containerIdentifier: String?
	public var databaseScope: CloudSeedingDatabaseScope = .private
	public var compactOutput = false

	public init(containerIdentifier: String? = nil, databaseScope: CloudSeedingDatabaseScope = .private, compactOutput: Bool = false) {
		self.containerIdentifier = containerIdentifier
		self.databaseScope = databaseScope
		self.compactOutput = compactOutput
	}
}

public struct CloudSeedingQueryOptions: Equatable {
	public var recordType: String
	public var predicate: String
	public var zoneName: String?
	public var zoneOwnerName: String?
	public var fields: [String]
	public var limit: Int?

	public init(recordType: String, predicate: String = "TRUEPREDICATE", zoneName: String? = nil, zoneOwnerName: String? = nil, fields: [String] = [], limit: Int? = 100) {
		self.recordType = recordType
		self.predicate = predicate
		self.zoneName = zoneName
		self.zoneOwnerName = zoneOwnerName
		self.fields = fields
		self.limit = limit
	}
}

public struct CloudSeedingRecordOptions: Equatable {
	public var recordName: String
	public var zoneName: String?
	public var zoneOwnerName: String?
	public var fields: [String]

	public init(recordName: String, zoneName: String? = nil, zoneOwnerName: String? = nil, fields: [String] = []) {
		self.recordName = recordName
		self.zoneName = zoneName
		self.zoneOwnerName = zoneOwnerName
		self.fields = fields
	}
}

public struct CloudSeedingCommandLineOptions: Equatable {
	public enum Command: Equatable {
		case help(String?)
		case query(CloudSeedingQueryOptions)
		case record(CloudSeedingRecordOptions)
		case zones
		case user
	}

	public var global: CloudSeedingGlobalOptions
	public var command: Command

	public init(global: CloudSeedingGlobalOptions = .init(), command: Command) {
		self.global = global
		self.command = command
	}

	public static func parse(_ arguments: [String]) throws -> CloudSeedingCommandLineOptions {
		var parser = ArgumentParser(arguments)
		guard let commandName = parser.next() else {
			return CloudSeedingCommandLineOptions(command: .help(nil))
		}

		switch commandName {
		case "-h", "--help":
			return CloudSeedingCommandLineOptions(command: .help(nil))
		case "help":
			return CloudSeedingCommandLineOptions(command: .help(parser.next()))
		case "query":
			return try parseQuery(parser)
		case "record":
			return try parseRecord(parser)
		case "zones":
			return try parseSimpleCommand(parser, command: .zones)
		case "user":
			return try parseSimpleCommand(parser, command: .user)
		default:
			throw CloudSeedingCLIError.unknownCommand(commandName)
		}
	}

	private static func parseQuery(_ parser: ArgumentParser) throws -> CloudSeedingCommandLineOptions {
		var parser = parser
		var global = CloudSeedingGlobalOptions()
		var recordType: String?
		var predicate = "TRUEPREDICATE"
		var zoneName: String?
		var zoneOwnerName: String?
		var fields: [String] = []
		var limit: Int? = 100

		while let argument = parser.next() {
			switch argument {
			case "-h", "--help":
				return CloudSeedingCommandLineOptions(global: global, command: .help("query"))
			case "--container":
				global.containerIdentifier = try parser.requiredValue(after: argument)
			case "--database":
				global.databaseScope = try parseDatabase(try parser.requiredValue(after: argument))
			case "--compact":
				global.compactOutput = true
			case "--record-type":
				recordType = try parser.requiredValue(after: argument)
			case "--predicate":
				predicate = try parser.requiredValue(after: argument)
			case "--zone":
				zoneName = try parser.requiredValue(after: argument)
			case "--zone-owner":
				zoneOwnerName = try parser.requiredValue(after: argument)
			case "--field":
				fields.append(contentsOf: parseFields(try parser.requiredValue(after: argument)))
			case "--limit":
				limit = try parseLimit(try parser.requiredValue(after: argument))
			case "--all":
				limit = nil
			default:
				if argument.hasPrefix("-") {
					throw CloudSeedingCLIError.unknownOption(argument)
				}
				if recordType == nil {
					recordType = argument
				} else {
					throw CloudSeedingCLIError.usage("Unexpected argument: \(argument)")
				}
			}
		}

		guard let recordType, !recordType.isEmpty else {
			throw CloudSeedingCLIError.missingRequiredOption("--record-type")
		}

		return CloudSeedingCommandLineOptions(
			global: global,
			command: .query(.init(recordType: recordType, predicate: predicate, zoneName: zoneName, zoneOwnerName: zoneOwnerName, fields: unique(fields), limit: limit))
		)
	}

	private static func parseRecord(_ parser: ArgumentParser) throws -> CloudSeedingCommandLineOptions {
		var parser = parser
		var global = CloudSeedingGlobalOptions()
		var recordName: String?
		var zoneName: String?
		var zoneOwnerName: String?
		var fields: [String] = []

		while let argument = parser.next() {
			switch argument {
			case "-h", "--help":
				return CloudSeedingCommandLineOptions(global: global, command: .help("record"))
			case "--container":
				global.containerIdentifier = try parser.requiredValue(after: argument)
			case "--database":
				global.databaseScope = try parseDatabase(try parser.requiredValue(after: argument))
			case "--compact":
				global.compactOutput = true
			case "--record-name":
				recordName = try parser.requiredValue(after: argument)
			case "--zone":
				zoneName = try parser.requiredValue(after: argument)
			case "--zone-owner":
				zoneOwnerName = try parser.requiredValue(after: argument)
			case "--field":
				fields.append(contentsOf: parseFields(try parser.requiredValue(after: argument)))
			default:
				if argument.hasPrefix("-") {
					throw CloudSeedingCLIError.unknownOption(argument)
				}
				if recordName == nil {
					recordName = argument
				} else {
					throw CloudSeedingCLIError.usage("Unexpected argument: \(argument)")
				}
			}
		}

		guard let recordName, !recordName.isEmpty else {
			throw CloudSeedingCLIError.missingRequiredOption("--record-name")
		}

		return CloudSeedingCommandLineOptions(
			global: global,
			command: .record(.init(recordName: recordName, zoneName: zoneName, zoneOwnerName: zoneOwnerName, fields: unique(fields)))
		)
	}

	private static func parseSimpleCommand(_ parser: ArgumentParser, command: Command) throws -> CloudSeedingCommandLineOptions {
		var parser = parser
		var global = CloudSeedingGlobalOptions()

		while let argument = parser.next() {
			switch argument {
			case "-h", "--help":
				let commandName = command == .zones ? "zones" : "user"
				return CloudSeedingCommandLineOptions(global: global, command: .help(commandName))
			case "--container":
				global.containerIdentifier = try parser.requiredValue(after: argument)
			case "--database":
				global.databaseScope = try parseDatabase(try parser.requiredValue(after: argument))
			case "--compact":
				global.compactOutput = true
			default:
				if argument.hasPrefix("-") {
					throw CloudSeedingCLIError.unknownOption(argument)
				}
				throw CloudSeedingCLIError.usage("Unexpected argument: \(argument)")
			}
		}

		return CloudSeedingCommandLineOptions(global: global, command: command)
	}

	private static func parseDatabase(_ value: String) throws -> CloudSeedingDatabaseScope {
		guard let database = CloudSeedingDatabaseScope(rawValue: value) else {
			throw CloudSeedingCLIError.invalidDatabase(value)
		}
		return database
	}

	private static func parseLimit(_ value: String) throws -> Int? {
		guard let limit = Int(value), limit >= 0 else {
			throw CloudSeedingCLIError.invalidLimit(value)
		}
		return limit == 0 ? nil : limit
	}

	private static func parseFields(_ value: String) -> [String] {
		value
			.split(separator: ",")
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
	}

	private static func unique(_ values: [String]) -> [String] {
		var seen: Set<String> = []
		return values.filter { seen.insert($0).inserted }
	}
}

private struct ArgumentParser {
	private var arguments: [String]
	private var index = 0

	init(_ arguments: [String]) {
		self.arguments = arguments
	}

	mutating func next() -> String? {
		guard index < arguments.count else { return nil }
		defer { index += 1 }
		return arguments[index]
	}

	mutating func requiredValue(after option: String) throws -> String {
		guard let value = next(), !value.hasPrefix("-") else {
			throw CloudSeedingCLIError.missingValue(option)
		}
		return value
	}
}
