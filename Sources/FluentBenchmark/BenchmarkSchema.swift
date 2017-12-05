import Async
import Dispatch
import Fluent
import Foundation

extension Benchmarker where Database.Connection: SchemaSupporting {
    /// Benchmark the basic schema creations.
    public func benchmarkSchema() throws -> Future<Void> {
        return pool.requestConnection().then { conn in
            return KitchenSinkSchema<Database>.prepare(on: conn).then {
                return KitchenSinkSchema<Database>.revert(on: conn)
            }.map {
                self.pool.releaseConnection(conn)
            }
        }
    }
}
