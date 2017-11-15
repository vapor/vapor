import Async
import Dispatch
import Fluent
import Foundation

extension Benchmarker where Database.Connection: SchemaSupporting {
    /// Benchmark the basic schema creations.
    public func benchmarkSchema() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(on: worker))
        try test(KitchenSinkSchema<Database>.prepare(on: conn))
        try test(KitchenSinkSchema<Database>.revert(on: conn))
    }
}

