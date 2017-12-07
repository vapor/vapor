import Async
import Service
import Dispatch
import Fluent
import Foundation

extension Benchmarker  {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws {
        let message = LogMessage<Database>(message: "hello")

        if message.id != nil {
            fail("message ID was incorrectly set")
        }

        try message.save(on: conn).blockingAwait()

        if conn.lastAutoincrementID == nil {
            fail("The last auto increment was not set")
            return
        }

        if conn.lastAutoincrementID != message.id {
            fail("The model ID was incorrectly set to \(message.id?.description ?? "nil") instead of \(conn.lastAutoincrementID?.description ?? "nil")")
        }
    }

    /// Benchmark the Timestampable protocol
    public func benchmarkAutoincrement() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(using: worker.container))
        try _benchmark(on: conn)
    }
}

extension Benchmarker where Database.Connection: SchemaSupporting {
    /// Benchmark the Timestampable protocol
    /// The schema will be prepared first.
    public func benchmarkAutoincrement_withSchema() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(using: worker.container))
        try test(LogMessageMigration<Database>.prepare(on: conn))
        try _benchmark(on: conn)
    }
}

extension EventLoop {
    var container: BasicContainer {
        return BasicContainer(config: .init(), environment: .testing, services: .init(), on: self)
    }
}
