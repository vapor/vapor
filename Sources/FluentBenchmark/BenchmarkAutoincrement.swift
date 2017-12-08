import Async
import Service
import Dispatch
import Fluent
import Foundation

extension Benchmarker  {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws -> Future<Void> {
        let message = LogMessage<Database>(message: "hello")

        if message.id != nil {
            fail("message ID was incorrectly set")
        }

        return message.save(on: conn).map {
            if conn.lastAutoincrementID == nil {
                throw "The last auto increment was not set"
            }
            
            if conn.lastAutoincrementID != message.id {
                throw "The model ID was incorrectly set to \(message.id?.description ?? "nil") instead of \(conn.lastAutoincrementID?.description ?? "nil")"
            }
        }
    }

    /// Benchmark the Timestampable protocol
    public func benchmarkAutoincrement() throws -> Future<Void> {
        return pool.requestConnection().then { conn in
            return try self._benchmark(on: conn).map {
                self.pool.releaseConnection(conn)
            }
        }
    }
}

extension Benchmarker where Database.Connection: SchemaSupporting {
    /// Benchmark the Timestampable protocol
    /// The schema will be prepared first.
    public func benchmarkAutoincrement_withSchema() throws -> Future<Void> {
        return pool.requestConnection().then { conn -> Future<Database.Connection> in
            let promise = Promise<Database.Connection>()
            
            LogMessageMigration<Database>.prepare(on: conn).do {
                promise.complete(conn)
                }.catch { _ in
                    promise.complete(conn)
            }
            
            return promise.future
            }.then { conn -> Future<Void> in
                return try self._benchmark(on: conn).map {
                    self.pool.releaseConnection(conn)
                }
        }
    }
}
