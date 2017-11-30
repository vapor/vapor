import Async
import Dispatch
import Fluent
import Foundation

extension Benchmarker where Database.Connection: JoinSupporting & ReferenceSupporting {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws -> Future<Void> {
        // create
        let tanner = User<Database>(name: "Tanner", age: 23)
        let ziz = try Pet<Database>(name: "Ziz", ownerID: tanner.requireID())
        let foo = Pet<Database>(name: "Foo", ownerID: UUID())
        let plasticBag = Toy<Database>(name: "Plastic Bag")
        let oldBologna = Toy<Database>(name: "Old Bologna")
        
        let promise = Promise<Int>()
        
        conn.enableReferences().then {
            return tanner.save(on: conn)
        }.then {
            return ziz.save(on: conn)
        }.then {
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
            
        return promise.future.then { count -> Future<User<Database>> in
            if count != 1 {
                self.fail("count should have been 1")
            }
            
            return ziz.owner.get(on: conn)
        }.then { user -> Future<Void> in
            if user.name != "Tanner" {
                self.fail("pet owner's name wrong")
            }
            
            return plasticBag.save(on: conn)
        }.then { _ -> Future<Void> in
            return oldBologna.save(on: conn)
        }.then { _ -> Future<Void> in
            return ziz.toys.attach(plasticBag, on: conn)
        }.then { _ -> Future<Void> in
            return oldBologna.pets.attach(ziz, on: conn)
        }.then { _ -> Future<Int> in
            return try ziz.toys.query(on: conn).count()
        }.then { count -> Future<Int> in
            if count != 2 {
                self.fail("count should have been 2")
            }
            
            return try oldBologna.pets.query(on: conn).count()
        }.then { count -> Future<Int> in
            if count != 1 {
                self.fail("count should have been 1")
            }
            
            return try plasticBag.pets.query(on: conn).count()
        }.then { count -> Future<Bool> in
            if count != 1 {
                self.fail("count should have been 1")
            }
            
            return try ziz.toys.isAttached(plasticBag, on: conn)
        }.then { _ -> Future<Void> in
            return try ziz.toys.detach(plasticBag, on: conn)
        }.then { _ -> Future<Bool> in
            return try ziz.toys.isAttached(plasticBag, on: conn)
        }.map { bool in
            if bool {
                self.fail("should be detached")
            }
        }
    }

    /// Benchmark fluent relations.
    public func benchmarkRelations() throws -> Future<Void> {
        return pool.requestConnection().then { conn in
            return try self._benchmark(on: conn).map {
                self.pool.releaseConnection(conn)
            }
        }
    }
}

extension Benchmarker where Database.Connection: SchemaSupporting & JoinSupporting & ReferenceSupporting {
    /// Benchmark fluent relations.
    /// The schema will be prepared first.
    public func benchmarkRelations_withSchema() throws -> Future<Void> {
        return pool.requestConnection().then { conn in
            return UserMigration<Database>.prepare(on: conn).then {
                return conn.enableReferences().then {
                    return UserMigration<Database>.prepare(on: conn)
                }.then {
                    return PetMigration<Database>.prepare(on: conn)
                }.then {
                    return ToyMigration<Database>.prepare(on: conn)
                }.then {
                    return PetToyMigration<Database>.prepare(on: conn)
                }.then {
                    return try self._benchmark(on: conn)
                }.map {
                    self.pool.releaseConnection(conn)
                }
            }
        }
    }
}

