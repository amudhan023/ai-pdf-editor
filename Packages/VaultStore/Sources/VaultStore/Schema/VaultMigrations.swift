import Foundation
import GRDB

/// The vault schema (ARCHITECTURE.md §8.2: persons, sections/fields, history
/// entries, provenance, documents) as a `DatabaseMigrator`. New columns/
/// tables land as new named migrations appended after `v1` — never edit a
/// migration that has shipped (CLAUDE.md §20.7: "migration discipline...
/// there is no 'we'll migrate later'").
enum VaultMigrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial_schema") { db in
            try db.create(table: "person") { t in
                t.column("id", .text).primaryKey()
                t.column("kind", .text).notNull()
                t.column("displayName", .text).notNull()
            }

            try db.create(table: "profileField") { t in
                t.column("personID", .text).notNull()
                    .indexed()
                    .references("person", onDelete: .cascade)
                t.column("path", .text).notNull()
                t.column("valueData", .blob).notNull()
                t.column("sensitivity", .text).notNull()
                t.column("aliasesData", .blob).notNull()
                t.column("verifiedAt", .datetime)
                t.column("provenanceData", .blob).notNull()
                t.primaryKey(["personID", "path"])
            }

            try db.create(table: "historyEntry") { t in
                t.column("id", .text).primaryKey()
                t.column("personID", .text).notNull()
                    .indexed()
                    .references("person", onDelete: .cascade)
                t.column("category", .text).notNull()
                t.column("rangeStart", .datetime).notNull()
                t.column("rangeEnd", .datetime)
            }

            try db.create(table: "historyFieldEntry") { t in
                t.column("historyEntryID", .text).notNull()
                    .indexed()
                    .references("historyEntry", onDelete: .cascade)
                t.column("path", .text).notNull()
                t.column("valueData", .blob).notNull()
                t.primaryKey(["historyEntryID", "path"])
            }

            try db.create(table: "relationshipEdge") { t in
                t.autoIncrementedPrimaryKey("rowID")
                t.column("fromPersonID", .text).notNull()
                    .indexed()
                    .references("person", onDelete: .cascade)
                t.column("toPersonID", .text).notNull()
                    .indexed()
                    .references("person", onDelete: .cascade)
                t.column("kindTag", .text).notNull()
                t.column("kindLabel", .text)
            }

            // Attachment metadata (ARCHITECTURE.md §8.1's "attachments/" —
            // the encrypted bytes live on disk via AttachmentStore; this
            // row is the blob-key reference, never a value column
            // (CLAUDE.md §8.5's FormKnowledge rule applies equally here).
            try db.create(table: "document") { t in
                t.column("id", .text).primaryKey()
                t.column("personID", .text)
                    .indexed()
                    .references("person", onDelete: .setNull)
                t.column("byteSize", .integer).notNull()
                t.column("addedAt", .datetime).notNull()
            }
        }

        return migrator
    }
}
