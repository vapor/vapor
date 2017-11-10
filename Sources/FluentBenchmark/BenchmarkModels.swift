import Async
import Fluent
import Foundation

extension Benchmarker {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws {
        // create
        let a = Foo<Database>(bar: "asdf", baz: 42)
        try test(a.save(on: conn))

        let b = Foo<Database>(bar: "asdf", baz: 42)
        try test(b.save(on: conn))

        if try test(conn.query(Foo<Database>.self).count()) != 2 {
            fail("count should have been 2")
        }

        // update
        b.bar = "fdsa"
        try test(b.save(on: conn))

        // read
        let fetched = try test(Foo<Database>.find(b.requireID(), on: conn))
        if fetched?.bar != "fdsa" {
            fail("b.bar should have been updated")
        }

        // delete
        try test(b.delete(on: conn))

        if try test(conn.query(Foo<Database>.self).count()) != 1 {
            fail("count should have been 1")
        }
    }

    /// Benchmark the basic model CRUD.
    public func benchmarkModels() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(on: worker))
        try _benchmark(on: conn)
    }
}

extension Benchmarker where Database.Connection: SchemaSupporting {
    /// Benchmark the basic model CRUD.
    /// The schema will be prepared first.
    public func benchmarkModels_withSchema() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(on: worker))
        try test(FooMigration<Database>.prepare(on: conn))
        try _benchmark(on: conn)
    }
}
