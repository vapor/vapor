import Fluent
import SQL

extension DatabaseSchema {
    /// Converts a database schema to sql schema query
    public func makeSchemaQuery(delegate: SchemaDelegate) -> SchemaQuery {
        let schemaStatement: SchemaStatement

        switch action {
        case .create:
            schemaStatement = .create(columns: addFields.map {
                $0.makeSchemaColumn(delegate: delegate)
            })
        case .update:
            schemaStatement = .alter(
                columns: addFields.map {
                    $0.makeSchemaColumn(delegate: delegate)
                },
                deleteColumns: removeFields
            )
        case .delete:
            schemaStatement = .drop
        }

        return SchemaQuery(statement: schemaStatement, table: entity)
    }
}

/// Performs special operations required by the
/// database schema conversion.
public protocol SchemaDelegate {
    /// Converts a Fluent schema field type to a raw
    /// SQL datatype.
    func convertToDataType(_ type: SchemaFieldType) -> String
}
