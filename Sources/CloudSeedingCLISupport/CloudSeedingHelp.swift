import Foundation

public enum CloudSeedingHelp {
	public static func text(for command: String?) -> String {
		switch command {
		case "query":
			"""
			Usage:
			  cloudseeding query <record-type> [options]
			  cloudseeding query --record-type <type> [options]

			Options:
			  --container <identifier>   CloudKit container identifier. Defaults to CKContainer.default().
			  --database <scope>         private, public, or shared. Defaults to private.
			  --predicate <format>       NSPredicate format. Defaults to TRUEPREDICATE.
			  --zone <name>              Query a specific record zone.
			  --zone-owner <name>        Zone owner. Defaults to the current user for custom zones.
			  --field <key[,key]>        Desired keys to fetch. May be repeated.
			  --limit <count>            Maximum records to return. Defaults to 100. Use 0 for all.
			  --all                      Return every matching record.
			  --compact                  Emit compact JSON.
			"""
		case "record":
			"""
			Usage:
			  cloudseeding record <record-name> [options]
			  cloudseeding record --record-name <name> [options]

			Options:
			  --container <identifier>   CloudKit container identifier. Defaults to CKContainer.default().
			  --database <scope>         private, public, or shared. Defaults to private.
			  --zone <name>              Fetch from a specific record zone.
			  --zone-owner <name>        Zone owner. Defaults to the current user for custom zones.
			  --field <key[,key]>        Fields to include in output. May be repeated.
			  --compact                  Emit compact JSON.
			"""
		case "zones":
			"""
			Usage:
			  cloudseeding zones [options]

			Options:
			  --container <identifier>   CloudKit container identifier. Defaults to CKContainer.default().
			  --database <scope>         private, public, or shared. Defaults to private.
			  --compact                  Emit compact JSON.
			"""
		case "user":
			"""
			Usage:
			  cloudseeding user [options]

			Options:
			  --container <identifier>   CloudKit container identifier. Defaults to CKContainer.default().
			  --compact                  Emit compact JSON.
			"""
		default:
			"""
			Usage:
			  cloudseeding <command> [options]

			Commands:
			  query    Query records by record type and predicate.
			  record   Fetch a single record by record name.
			  zones    List record zones in a database.
			  user     Show CloudKit account and user-record information.

			Run `cloudseeding help <command>` for command-specific options.
			"""
		}
	}
}
