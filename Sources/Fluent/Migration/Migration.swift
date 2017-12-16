import Async
import JunkDrawer

/// Declares a database migration.
public protocol Migration {
    /// The type of database this migration can run on.
    /// Migrations require a query executor to work correctly
    /// as they must be able to query the MigrationLog model.
    associatedtype Database: Fluent.Database

    /// Runs this migration's changes on the database.
    /// This is usually creating a table, or altering an existing one.
    static func prepare(on connection: Database.Connection) -> Future<Void>

    /// Reverts this migration's changes on the database.
    /// This is usually dropping a created table. If it is not possible
    /// to revert the changes from this migration, complete the future
    /// with an error.
    static func revert(on connection: Database.Connection) -> Future<Void>
}

extension Model where Self: Migration, Database.Connection: SchemaSupporting {
    /// See Migration.prepare
    public static func prepare(on connection: Database.Connection) -> Future<Void> {
        return connection.create(self) { schema in
            let idCodingPath = Self.codingPath(forKey: idKey)
            for property in Self.properties() {
                guard property.codingPath.count == 1 else {
                    continue
                }
                try schema.addField(
                    type: Database.Connection.FieldType.requireSchemaFieldType(for: property.type),
                    name: property.codingPath[0].stringValue,
                    isOptional: property.isOptional,
                    isIdentifier: property.codingPath.equals(idCodingPath)
                )
            }
        }
    }

    /// See Migration.revert
    public static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(self)
    }
}

/// MARK: Utils

extension Array where Element == CodingKey {
    /// Returns true if the two coding keys are equivalent
    fileprivate func equals(_ other: [CodingKey]) -> Bool {
        guard count == other.count else {
            return false
        }

        for a in self {
            for b in other {
                guard a.stringValue == b.stringValue else {
                    return false
                }
            }
        }

        return true
    }
}
