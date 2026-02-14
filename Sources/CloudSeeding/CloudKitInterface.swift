//
//  CloudKitInterface.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 7/26/25.
//

import Foundation
import CloudKit
import Combine

@MainActor @Observable public class CloudKitInterface {
	public static let instance = CloudKitInterface()
	
	public enum Status: Sendable { case notAvailable, available, signedIn }
	
	public private(set) var status = Status.notAvailable
	nonisolated static public var currentUserID: String? { currentUserIDValue.value }
	nonisolated static public var currentUserName: String? { currentUserNameValue.value }
	nonisolated static let currentUserIDValue = CurrentValueSubject<String?, Never>(nil)
	nonisolated static let currentUserNameValue = CurrentValueSubject<String?, Never>(nil)

	var notificationTask: Task<Void, Never>?
	var containerID: String?
	public private(set) var container: CKContainer?

	private init() { }

	public func setup(containerID: String?) {
		notificationTask?.cancel()

		self.containerID = containerID
		container = containerID == nil ? CKContainer.default() : CKContainer(identifier: containerID!)

		notificationTask = Task { [weak self] in
			for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
				guard !Task.isCancelled else { return }
				await self?.checkAccountStatus()
			}
		}

		Task { await checkAccountStatus() }
	}

	public func checkAccountStatus() async {
		guard let container else {
			logger.warning("checkAccountStatus() called before setup()")
			return
		}
		do {
			let accountStatus = try await container.accountStatus()
			
			switch accountStatus {
				
			case .couldNotDetermine:
				status = .notAvailable
			case .available:
				status = .signedIn
			case .restricted:
				status = .notAvailable
			case .noAccount:
				status = .notAvailable
			case .temporarilyUnavailable:
				status = .notAvailable
			@unknown default:
				break
			}
			
			if status != .notAvailable {
				let recordID = try await container.userRecordID()
				Self.currentUserIDValue.value = recordID.recordName
				
				let participant = try await container.shareParticipant(forUserRecordID: recordID)
				if let name = participant.userIdentity.nameComponents?.fullName {
					Self.currentUserNameValue.value = name
				}
			}
		} catch {
			logger.error("Failed to check CloudKit account status: \(error)")
		}
	}
}

extension PersonNameComponents {
	var fullName: String? {
		guard let givenName, let familyName, !givenName.isEmpty || !familyName.isEmpty else { return nil }
		
		return [givenName, familyName].compactMap { $0 }.joined(separator: " ")
	}
}
