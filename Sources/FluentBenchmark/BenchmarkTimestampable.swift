import Async
import Fluent
import Foundation

extension Benchmarker {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws {
        // create
        let tanner = User(name: "Tanner", age: 23)
        if tanner.createdAt != nil || tanner.updatedAt != nil {
            fail("timestamps should have been nil")
        }

        try test(tanner.save(on: conn))

        if tanner.createdAt?.isWithin(seconds: 1, of: Date()) != true {
            fail("timestamps should be current")
        }

        if tanner.updatedAt?.isWithin(seconds: 1, of: Date()) != true {
            fail("timestamps should be current")
        }

        let originalUpdatedAt = tanner.updatedAt!
        try test(tanner.save(on: conn))

        if tanner.updatedAt! <= originalUpdatedAt {
            fail("new updated at should be greater")
        }

        guard let fetched = try test(conn.query(User.self).filter(\User.name == "Tanner").first()) else {
            fail("could not fetch user")
            return
        }

        if fetched.createdAt != tanner.createdAt || fetched.updatedAt != tanner.updatedAt {
            fail("fetched timestamps are different")
        }
    }

    /// Benchmark the Timestampable protocol
    public func benchmarkTimestampable() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(on: worker))
        try _benchmark(on: conn)
    }
}

extension Benchmarker where Database.Connection: SchemaSupporting {
    /// Benchmark the Timestampable protocol
    /// The schema will be prepared first.
    public func benchmarkTimestampable_withSchema() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(on: worker))
        try test(UserMigration<Database>.prepare(on: conn))
        try _benchmark(on: conn)
    }
}

extension Date {
    public func isWithin(seconds: Double, of other: Date) -> Bool {
        var diff = other.timeIntervalSince1970 - self.timeIntervalSince1970
        if diff < 0 {
            diff = diff * -1.0
        }
        return diff <= seconds
    }

    public var unix: Int {
        return Int(timeIntervalSince1970)
    }
}
