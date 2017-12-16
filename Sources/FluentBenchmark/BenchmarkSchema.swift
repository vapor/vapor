import Async
import Dispatch
import Fluent
import Foundation

extension Benchmarker where Database.Connection: SchemaSupporting {
    /// Benchmark the basic schema creations.
    public func benchmarkSchema() throws -> Future<Void> {
        return pool.requestConnection().flatMap(to: Void.self) { conn in
            return KitchenSinkSchema<Database>.prepare(on: conn).flatMap(to: Void.self) {
                return KitchenSinkSchema<Database>.revert(on: conn)
            }.map(to: Void.self) {
                self.pool.releaseConnection(conn)
            }
        }
    }
}
