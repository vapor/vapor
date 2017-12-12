import Async
import Service
import Dispatch
import Fluent
import Foundation

extension Benchmarker {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws -> Completable {
        var fetched64: [User<Database>] = []
        var fetched2047: [User<Database>] = []
        
        var future = Completable(())
        
        for i in 1...512 {
            let user = User<Database>(name: "User \(i)", age: i)
            
            future = future.flatMap(to: Void.self) {
                return user.save(on: conn)
            }
        }
        
        return future.flatMap(to: Void.self) {
            return conn.query(User<Database>.self).chunk(max: 64) { chunk in
                if chunk.count != 64 {
                    self.fail("bad chunk count")
                }
                fetched64 += chunk
            }
        }.flatMap(to: Void.self) {
            if fetched64.count != 512 {
                self.fail("did not fetch all - only \(fetched64.count) out of 2048")
            }
            
            return conn.query(User<Database>.self).chunk(max: 511) { chunk in
                if chunk.count != 511 && chunk.count != 1 {
                    self.fail("bad chunk count")
                }
                fetched2047 += chunk
            }
        }.map(to: Void.self) {
            if fetched2047.count != 512 {
                self.fail("did not fetch all - only \(fetched2047.count) out of 2048")
            }
        }
    }

    /// Benchmark result chunking
    public func benchmarkChunking() throws -> Completable {
        return pool.requestConnection().flatMap(to: Void.self) { conn in
            return try self._benchmark(on: conn).always {
                self.pool.releaseConnection(conn)
            }
        }
    }
}

extension Benchmarker where Database.Connection: SchemaSupporting {
    /// Benchmark result chunking
    /// The schema will be prepared first.
    public func benchmarkChunking_withSchema() throws -> Completable {
        return pool.requestConnection().flatMap(to: Void.self) { conn in
            let promise = Promise<Void>()
            
            UserMigration<Database>.prepare(on: conn).always {
                promise.complete()
            }
            
            return promise.future.flatMap(to: Void.self) {
                return try self._benchmark(on: conn)
            }.always {
                self.pool.releaseConnection(conn)
            }
        }
    }
}
