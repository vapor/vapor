import Async
import Service
import Dispatch
import Fluent
import Foundation

extension Benchmarker  {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws -> Completable {
        let message = LogMessage<Database>(message: "hello")

        if message.id != nil {
            fail("message ID was incorrectly set")
        }

        return message.save(on: conn).map(to: Void.self) {
            if conn.lastAutoincrementID == nil {
                throw FluentBenchmarkError(identifier: "autoincrement", reason: "The last auto increment was not set")
            }
            
            if conn.lastAutoincrementID != message.id {
                throw FluentBenchmarkError(identifier: "model-autoincrement-mismatch", reason: "The model ID was incorrectly set to \(message.id?.description ?? "nil") instead of \(conn.lastAutoincrementID?.description ?? "nil")")
            }
        }
    }

    /// Benchmark the Timestampable protocol
    public func benchmarkAutoincrement() throws -> Completable {
        return pool.requestConnection().flatMap(to: Void.self) { conn in
            return try self._benchmark(on: conn).always {
                self.pool.releaseConnection(conn)
            }
        }
    }
}

extension Benchmarker where Database.Connection: SchemaSupporting {
    /// Benchmark the Timestampable protocol
    /// The schema will be prepared first.
    public func benchmarkAutoincrement_withSchema() throws -> Completable {
        return pool.requestConnection().flatMap(to: Void.self) { conn in
            LogMessageMigration<Database>.prepare(on: conn).flatMap(to: Void.self) {
                return try self._benchmark(on: conn)
            }.always {
                self.pool.releaseConnection(conn)
            }
        }
    }
}
