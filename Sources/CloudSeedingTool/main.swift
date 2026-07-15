import CloudKit
import CloudSeedingCLISupport
import Foundation

@main
struct CloudSeedingTool {
	static func main() async {
		do {
			let options = try CloudSeedingCommandLineOptions.parse(Array(CommandLine.arguments.dropFirst()))
			if case .help(let command) = options.command {
				print(CloudSeedingHelp.text(for: command))
				return
			}

			let result = try await CloudKitCommandRunner(options: options).run()
			let data = try CloudKitRecordJSONEncoder.jsonData(for: result, prettyPrinted: !options.global.compactOutput)
			FileHandle.standardOutput.write(data)
			FileHandle.standardOutput.write(Data("\n".utf8))
		} catch let error as CloudSeedingCLIError {
			writeError(error.description)
			exit(2)
		} catch {
			writeError(String(describing: error))
			exit(1)
		}
	}

	private static func writeError(_ message: String) {
		FileHandle.standardError.write(Data((message + "\n").utf8))
	}
}

private struct CloudKitCommandRunner {
	let options: CloudSeedingCommandLineOptions
	let encoder = CloudKitRecordJSONEncoder()

	func run() async throws -> Any {
		let container = makeContainer()

		switch options.command {
		case .help:
			return [:]
		case .user:
			return try await userInfo(in: container)
		case .zones:
			try await requireAccountIfNeeded(in: container)
			return try await listZones(in: container)
		case .record(let recordOptions):
			try await requireAccountIfNeeded(in: container)
			return try await fetchRecord(recordOptions, in: container)
		case .query(let queryOptions):
			try await requireAccountIfNeeded(in: container)
			return try await queryRecords(queryOptions, in: container)
		}
	}

	private func makeContainer() -> CKContainer {
		if let identifier = options.global.containerIdentifier {
			return CKContainer(identifier: identifier)
		}
		return CKContainer.default()
	}

	private func userInfo(in container: CKContainer) async throws -> [String: Any] {
		let status = try await container.accountStatus()
		var output: [String: Any] = [
			"accountStatus": status.cloudSeedingDescription,
		]
		if let identifier = options.global.containerIdentifier {
			output["containerIdentifier"] = identifier
		}
		if status == .available {
			let userRecordID = try await container.userRecordID()
			output["userRecordID"] = encoder.encode(recordID: userRecordID)
		}
		return output
	}

	private func listZones(in container: CKContainer) async throws -> [String: Any] {
		let database = options.global.databaseScope.database(in: container)
		let zones = try await database.allRecordZones()
		return [
			"database": options.global.databaseScope.rawValue,
			"zones": zones.map(encoder.encode(zone:)),
		]
	}

	private func fetchRecord(_ recordOptions: CloudSeedingRecordOptions, in container: CKContainer) async throws -> [String: Any] {
		let database = options.global.databaseScope.database(in: container)
		let record = try await database.record(for: recordOptions.recordID)
		return encoder.encode(record: record, fieldKeys: recordOptions.fields)
	}

	private func queryRecords(_ queryOptions: CloudSeedingQueryOptions, in container: CKContainer) async throws -> [String: Any] {
		let database = options.global.databaseScope.database(in: container)
		let predicate = try makePredicate(format: queryOptions.predicate)
		let query = CKQuery(recordType: queryOptions.recordType, predicate: predicate)
		var records: [[String: Any]] = []
		var failures: [[String: Any]] = []
		var cursor: CKQueryOperation.Cursor?

		repeat {
			let result: (matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)], queryCursor: CKQueryOperation.Cursor?)
			if let cursor {
				result = try await database.records(continuingMatchFrom: cursor)
			} else {
				result = try await database.records(
					matching: query,
					inZoneWith: queryOptions.zoneID,
					desiredKeys: queryOptions.desiredKeys,
					resultsLimit: queryOptions.requestLimit(fetchedCount: records.count)
				)
			}

			for (recordID, recordResult) in result.matchResults {
				if let limit = queryOptions.limit, records.count >= limit { break }
				switch recordResult {
				case .success(let record):
					records.append(encoder.encode(record: record, fieldKeys: queryOptions.fields))
				case .failure(let error):
					failures.append([
						"recordID": encoder.encode(recordID: recordID),
						"error": String(describing: error),
					])
				}
			}

			cursor = queryOptions.shouldContinue(afterFetching: records.count) ? result.queryCursor : nil
		} while cursor != nil

		var output: [String: Any] = [
			"database": options.global.databaseScope.rawValue,
			"recordType": queryOptions.recordType,
			"predicate": queryOptions.predicate,
			"count": records.count,
			"records": records,
		]
		if let zoneID = queryOptions.zoneID {
			output["zoneID"] = encoder.encode(zoneID: zoneID)
		}
		if !failures.isEmpty {
			output["failures"] = failures
		}
		return output
	}

	private func requireAccountIfNeeded(in container: CKContainer) async throws {
		guard options.global.databaseScope != .public else { return }
		let status = try await container.accountStatus()
		guard status == .available else {
			throw CloudSeedingCLIError.unavailableAccount(status.cloudSeedingDescription)
		}
	}

	private func makePredicate(format: String) throws -> NSPredicate {
		guard !format.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			throw CloudSeedingCLIError.invalidPredicate(format)
		}
		return NSPredicate(format: format)
	}
}

private extension CloudSeedingQueryOptions {
	func requestLimit(fetchedCount: Int) -> Int {
		guard let limit else { return CKQueryOperation.maximumResults }
		let remaining = max(1, limit - fetchedCount)
		let maximum = CKQueryOperation.maximumResults
		return maximum == 0 ? remaining : min(remaining, maximum)
	}

	func shouldContinue(afterFetching count: Int) -> Bool {
		guard let limit else { return true }
		return count < limit
	}
}
