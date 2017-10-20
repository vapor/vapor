import Async
import SQL
import SQLite

extension SQLiteConnection: SchemaExecutor {
    public func execute(schema: DatabaseSchema) -> Future<Void> {
        let promise = Promise(Void.self)

        let sqlQuery: SQLQuery
        var values: [SQLiteData] = [] // FIXME: default values

        switch schema.action {
        case .create:
            var create = SchemaQuery(statement: .create, table: schema.entity)

            for field in schema.addFields {
                create.columns.append(field.column)
            }

            sqlQuery = .schema(create)
        default:
            fatalError("not supported")
        }

        let string = SQLiteSQLSerializer()
            .serialize(query: sqlQuery)

        print(string)

        let sqliteQuery = try! SQLiteQuery(
            statement: string,
            connection: self
        )

        for value in values {
            print(value)
            try! sqliteQuery.bind(value)
        }

        sqliteQuery.execute().then {
            promise.complete()
            }.catch { err in
                promise.fail(err)
        }

        return promise.future
    }
}

extension Field {
    fileprivate var column: SchemaColumn {
        return SchemaColumn(
            name: name,
            dataType: type.dataType,
            isNotNull: true, // FIXME: implement
            isPrimaryKey: false // FIXME: implement
        )
    }
}

extension FieldType {
    fileprivate var dataType: String {
        switch self {
        case .string:
            return "TEXT"
        case .custom(let custom):
            return custom
        }
    }
}
