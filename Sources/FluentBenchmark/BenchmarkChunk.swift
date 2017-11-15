import Async
import Dispatch
import Fluent
import Foundation

extension Benchmarker {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws {
        for i in 1...2048 {
            let user = User<Database>(name: "User \(i)", age: i)
            try test(user.save(on: conn))
        }


        var fetched64: [User<Database>] = []
        try conn.query(User<Database>.self).chunk(max: 64) { chunk in
            if chunk.count != 64 {
                self.fail("bad chunk count")
            }
            fetched64 += chunk
        }.blockingAwait()

        if fetched64.count != 2048 {
            fail("did not fetch all")
        }


        var fetched2047: [User<Database>] = []
        try conn.query(User<Database>.self).chunk(max: 2047) { chunk in
            if chunk.count != 2047 && chunk.count != 1 {
                self.fail("bad chunk count")
            }
            fetched2047 += chunk
        }.blockingAwait()

        if fetched2047.count != 2048 {
            fail("did not fetch all")
        }
    }

    /// Benchmark result chunking
    public func benchmarkChunking() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(on: worker))
        try _benchmark(on: conn)
    }
}

extension Benchmarker where Database.Connection: SchemaSupporting {
    /// Benchmark result chunking
    /// The schema will be prepared first.
    public func benchmarkChunking_withSchema() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(on: worker))
        try test(UserMigration<Database>.prepare(on: conn))
        try _benchmark(on: conn)
    }
}
