import Async
import Dispatch
import Fluent
import Foundation

extension Benchmarker where Database.Connection: JoinSupporting & ReferenceSupporting {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws -> Future<Void> {
        // create
        let tanner = User<Database>(name: "Tanner", age: 23)
        var ziz: Pet<Database>!
        let foo = Pet<Database>(name: "Foo", ownerID: UUID())
        let plasticBag = Toy<Database>(name: "Plastic Bag")
        let oldBologna = Toy<Database>(name: "Old Bologna")
        
        let promise = Promise<Int>()
        
        conn.enableReferences().flatMap(to: Void.self) {
            return tanner.save(on: conn)
        }.flatMap(to: Void.self) {
            ziz = try Pet<Database>(name: "Ziz", ownerID: tanner.requireID())
            return ziz.save(on: conn)
        }.flatMap(to: Void.self) {
            return foo.save(on: conn)
        }.addAwaiter { response in
            if response.error == nil {
                self.fail("should not have saved")
            }
            
            do {
                try tanner.pets.query(on: conn).count().do(promise.complete).catch(promise.fail)
            } catch {
                promise.fail(error)
            }
        }
            
        return promise.future.flatMap(to: User<Database>.self) { count in
            if count != 1 {
                self.fail("count should have been 1")
            }
            
            return ziz.owner.get(on: conn)
        }.flatMap(to: Void.self) { user in
            if user.name != "Tanner" {
                self.fail("pet owner's name wrong")
            }
            
            return plasticBag.save(on: conn)
        }.flatMap(to: Void.self) {
            return oldBologna.save(on: conn)
        }.flatMap(to: Void.self) {
            return ziz.toys.attach(plasticBag, on: conn)
        }.flatMap(to: Void.self) {
            return oldBologna.pets.attach(ziz, on: conn)
        }.flatMap(to: Int.self) {
            return try ziz.toys.query(on: conn).count()
        }.flatMap(to: Int.self) { count in
            if count != 2 {
                self.fail("count should have been 2")
            }
            
            return try oldBologna.pets.query(on: conn).count()
        }.flatMap(to: Int.self) { count in
            if count != 1 {
                self.fail("count should have been 1")
            }
            
            return try plasticBag.pets.query(on: conn).count()
        }.flatMap(to: Bool.self) { count in
            if count != 1 {
                self.fail("count should have been 1")
            }
            
            return ziz.toys.isAttached(plasticBag, on: conn)
        }.flatMap(to: Void.self) { bool in
            return ziz.toys.detach(plasticBag, on: conn)
        }.flatMap(to: Bool.self) {
            return ziz.toys.isAttached(plasticBag, on: conn)
        }.map(to: Void.self) { bool in
            if bool {
                self.fail("should be detached")
            }
        }
    }

    /// Benchmark fluent relations.
    public func benchmarkRelations() throws -> Future<Void> {
        return pool.requestConnection().flatMap(to: Void.self) { conn in
            return try self._benchmark(on: conn).map(to: Void.self) {
                self.pool.releaseConnection(conn)
            }
        }
    }
}

extension Benchmarker where Database.Connection: SchemaSupporting & JoinSupporting & ReferenceSupporting {
    /// Benchmark fluent relations.
    /// The schema will be prepared first.
    public func benchmarkRelations_withSchema() throws -> Future<Void> {
        return pool.requestConnection().flatMap(to: Void.self) { conn in
            return conn.enableReferences().flatMap(to: Void.self) {
                return UserMigration<Database>.prepare(on: conn)
            }.flatMap(to: Void.self) {
                return PetMigration<Database>.prepare(on: conn)
            }.flatMap(to: Void.self) {
                return ToyMigration<Database>.prepare(on: conn)
            }.flatMap(to: Void.self) {
                return PetToyMigration<Database>.prepare(on: conn)
            }.flatMap(to: Void.self) {
                return try self._benchmark(on: conn)
            }.map(to: Void.self) {
                self.pool.releaseConnection(conn)
            }
        }
    }
}

