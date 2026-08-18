//
//  PublicDatabaseAccessTests.swift
//  CloudSeeding
//
//  CloudKit lets anyone read the public database, signed in or not; only the
//  private and shared scopes need an account. Gating public reads on account
//  status makes a signed-out user indistinguishable from an empty catalog —
//  which is how a fully seeded public catalog read as empty in an app whose
//  simulator had no iCloud account.
//
//  The rule is tested directly rather than through CKDatabase: constructing a
//  real database requires container entitlements a test binary can't carry.
//

import Testing
import CloudKit
@testable import CloudSeeding

struct PublicDatabaseAccessTests {
	@Test func publicReadsNeverRequireAnAccount() {
		for status in [CloudKitInterface.Status.notAvailable, .available, .signedIn] {
			#expect(!CloudSeedingAccountRequirement.requiresAccount(scope: .public, status: status))
		}
	}

	@Test func privateAndSharedRequireAnAccountWhenSignedOut() {
		#expect(CloudSeedingAccountRequirement.requiresAccount(scope: .private, status: .notAvailable))
		#expect(CloudSeedingAccountRequirement.requiresAccount(scope: .shared, status: .notAvailable))
	}

	@Test func privateAndSharedAreAllowedOnceAvailable() {
		for status in [CloudKitInterface.Status.available, .signedIn] {
			#expect(!CloudSeedingAccountRequirement.requiresAccount(scope: .private, status: status))
			#expect(!CloudSeedingAccountRequirement.requiresAccount(scope: .shared, status: status))
		}
	}
}
