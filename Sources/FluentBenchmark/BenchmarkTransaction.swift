import Async
import Fluent
import Foundation

extension Benchmarker where Database.Connection: TransactionSupporting {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws {
        // create
        let tanner = User(name: "Tanner", age: 23)
        try test(tanner.save(on: conn))

        do {
            try conn.transaction { conn in
                var users: [Future<Void>] = []

                /// create 1,000 users
                for i in 1...1_000 {
                    let user = User(name: "User \(i)", age: i)
                    users.append(user.save(on: conn))
                }

                return users.flatten().then {
                    // count users
                    return conn.query(User.self).count().then { count in
                        if count != 1_001 {
                            self.fail("count should be 1,001")
                        }

                        throw "rollback"
                    }
                }
            }.blockingAwait()

            fail("transaction should have failed")
        } catch {
            // good
        }

        if try test(conn.query(User.self).count()) != 1 {
            fail("count should have restored to one")
        }
    }

    /// Benchmark fluent transactions.
    public func benchmarkTransactions() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(on: worker))
        try _benchmark(on: conn)
    }
}

extension Benchmarker where Database.Connection: TransactionSupporting & SchemaSupporting {
    /// Benchmark fluent transactions.
    /// The schema will be prepared first.
    public func benchmarkTransactions_withSchema() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(on: worker))
        try test(UserMigration<Database>.prepare(on: conn))
        try _benchmark(on: conn)
    }
}


