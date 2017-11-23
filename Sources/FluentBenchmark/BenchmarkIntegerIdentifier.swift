import Async
import Dispatch
import Fluent
import Foundation

extension Benchmarker where Database.Connection: SchemaSupporting {
    public func benchmarkAutoIncrement() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(on: worker))
        try test(LogMessageMigration<Database>.prepare(on: conn))
        
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
}
