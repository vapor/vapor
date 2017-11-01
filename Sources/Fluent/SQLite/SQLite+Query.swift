import Async
import Dispatch
import Foundation
import Random
import SQL
import SQLite

extension SQLiteConnection: QueryExecutor {
    public func execute<I: Async.InputStream, D: Decodable>(
        query: DatabaseQuery,
        into stream: I
    ) -> Future<Void> where I.Input == D {
        let promise = Promise(Void.self)

        do {
            try _perform(query, into: stream)
                .then { promise.complete(()) }
                .catch { err in promise.fail(err) }
        } catch {
            promise.fail(error)
        }

        return promise.future
    }

    private func _perform<I: Async.InputStream, D: Decodable>(
        _ fluentQuery: DatabaseQuery,
        into stream: I
    ) throws -> Future<Void> where I.Input == D {
        let promise = Promise(Void.self)

        let sqlQuery: SQLQuery
        var values: [SQLiteData] = []

        switch fluentQuery.action {
        case .read:
            var select = DataQuery(statement: .select, table: fluentQuery.entity)

            if let data = fluentQuery.data {
                let encoder = SQLiteRowEncoder()
                try data.encode(to: encoder)
                select.columns += encoder.row.fields.keys.map {
                    DataColumn(table: fluentQuery.entity, name: $0.name)
                }
            }

            for filter in fluentQuery.filters {
                let (predicate, value) = try filter.makePredicate()
                select.predicates.append(predicate)
                if let value = value {
                    values.append(value)
                }
            }

            for join in fluentQuery.joins {
                select.joins.append(join.join)
            }

            select.limit = fluentQuery.limit?.count
            select.offset = fluentQuery.limit?.offset

            sqlQuery = .data(select)
        case .update:
            var update = DataQuery(statement: .update, table: fluentQuery.entity)

            guard let data = fluentQuery.data else {
                throw "data required for insert"
            }

            let encoder = SQLiteRowEncoder()
            try data.encode(to: encoder)

            update.columns = encoder.row.fields.keys.map {
                DataColumn(table: fluentQuery.entity, name: $0.name)
            }
            values = encoder.row.fields.values.map { $0.data }

            for filter in fluentQuery.filters {
                let (predicate, value) = try filter.makePredicate()
                update.predicates.append(predicate)
                if let value = value {
                    values.append(value)
                }
            }

            sqlQuery = .data(update)
        case .create:
            var insert = DataQuery(statement: .insert, table: fluentQuery.entity)

            guard let data = fluentQuery.data else {
                throw "data required for insert"
            }

            let encoder = SQLiteRowEncoder()
            try data.encode(to: encoder)
            insert.columns += encoder.row.fields.keys.map {
                DataColumn(table: fluentQuery.entity, name: $0.name)
            }
            values += encoder.row.fields.values.map { $0.data }
            sqlQuery = .data(insert)
        case .delete:
            var delete = DataQuery(statement: .delete, table: fluentQuery.entity)

            for filter in fluentQuery.filters {
                let (predicate, value) = try filter.makePredicate()
                delete.predicates.append(predicate)
                if let value = value {
                    values.append(value)
                }
            }

            sqlQuery = .data(delete)
        case .aggregate(_, _):
            // FIXME: actually take field and aggregate into account
            var select = DataQuery(statement: .select, table: fluentQuery.entity)

            let count = DataComputed(function: "count", key: "fluentAggregate")
            select.computed.append(count)

            sqlQuery = .data(select)
        }

        let string = SQLiteSQLSerializer()
            .serialize(query: sqlQuery)

        print("[SQLite] \(string) \(values)")
        
        let sqliteQuery = SQLiteQuery(
            string: string,
            connection: self
        )
        for value in values {
            sqliteQuery.bind(value) // FIXME: set array w/o need to loop?
        }

        sqliteQuery.drain { row in
            let decoder = SQLiteRowDecoder(row: row)
            do {
                let model = try D(from: decoder)
                stream.inputStream(model)
            } catch {
                fatalError("uncaught error")
                // fluentQuery.errorStream?(error)
            }
        }.catch { err in
            promise.fail(err)
        }

        sqliteQuery.execute().then {
            promise.complete()
        }.catch { err in
            promise.fail(err)
        }

        return promise.future
    }
}

extension Filter {
    fileprivate func makePredicate() throws -> (predicate: Predicate, value: SQLiteData?) {
        let predicate: Predicate
        let value: SQLiteData?

        switch method {
        case .compare(let field, let comp, let encodable):
            predicate = Predicate(
                table: entity,
                column: field,
                comparison: comp.predicate
            )

            let encoder = SQLiteDataEncoder()
            try encodable.encode(to: encoder)

            switch comp {
            case .hasPrefix:
                value = .text((encoder.data.text ?? "") + "%")
            case .hasSuffix:
                value = .text("%" + (encoder.data.text ?? ""))
            case .contains:
                value = .text("%" + (encoder.data.text ?? "") + "%")
            default:
                value = encoder.data
            }
        default:
            fatalError("not implemented")
        }

        return (predicate, value)
    }
}

extension Join {
    fileprivate var join: SQL.Join {
        return .init(
            method: type.method,
            table: baseEntity,
            column: baseKey,
            foreignTable: joinedEntity,
            foreignColumn: joinedKey
        )
    }
}

extension JoinType {
    fileprivate var method: SQL.JoinMethod {
        switch self {
        case .inner: return .inner
        case .outer: return .outer
        }
    }
}

extension Comparison {
    var predicate: PredicateComparison {
        switch self {
        case .equals: return .equal
        case .greaterThan: return .greaterThan
        case .greaterThanOrEquals: return .greaterThanOrEqual
        case .lessThan: return .lessThan
        case .lessThanOrEquals: return .lessThanOrEqual
        case .notEquals: return .notEqual
        case .hasPrefix: return .like
        case .hasSuffix: return .like
        case .contains: return .like
        }
    }
}
