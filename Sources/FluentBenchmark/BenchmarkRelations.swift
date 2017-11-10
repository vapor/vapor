import Async
import Fluent
import Foundation

extension Benchmarker where Database.Connection: JoinSupporting {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws {
        // create
        let tanner = User<Database>(name: "Tanner", age: 23)
        try test(tanner.save(on: conn))

        let ziz = try Pet<Database>(name: "Ziz", ownerID: tanner.requireID())
        try test(ziz.save(on: conn))

        // test pet attached
        if try test(tanner.pets.query(on: conn).count()) != 1 {
            fail("count should have been 1")
        }
        if try test(ziz.owner.get(on: conn)).name != "Tanner" {
            fail("pet owner's name wrong")
        }

        // create toys
        let plasticBag = Toy<Database>(name: "Plastic Bag")
        try test(plasticBag.save(on: conn))

        let oldBologna = Toy<Database>(name: "Old Bologna")
        try test(oldBologna.save(on: conn))

        // attach toys
        try test(ziz.toys.attach(plasticBag, on: conn))
        try test(oldBologna.pets.attach(ziz, on: conn))

        // test toys attached
        if try test(ziz.toys.query(on: conn).count()) != 2 {
            fail("count should have been 2")
        }
        if try test(oldBologna.pets.query(on: conn).count()) != 1 {
            fail("count should have been 1")
        }
        if try test(plasticBag.pets.query(on: conn).count()) != 1 {
            fail("count should have been 1")
        }

        if try test(ziz.toys.isAttached(plasticBag, on: conn)) == false {
            fail("should be attached")
        }

        // test detach toy
        try test(ziz.toys.detach(plasticBag, on: conn))
        if try test(ziz.toys.isAttached(plasticBag, on: conn)) == true {
            fail("should be detached")
        }
    }

    /// Benchmark fluent relations.
    public func benchmarkRelations() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(on: worker))
        try _benchmark(on: conn)
    }
}

extension Benchmarker where Database.Connection: SchemaSupporting & JoinSupporting {
    /// Benchmark fluent relations.
    /// The schema will be prepared first.
    public func benchmarkRelations_withSchema() throws {
        let worker = DispatchQueue(label: "codes.vapor.fluent.benchmark.models")
        let conn = try test(database.makeConnection(on: worker))
        try test(UserMigration<Database>.prepare(on: conn))
        try test(PetMigration<Database>.prepare(on: conn))
        try test(ToyMigration<Database>.prepare(on: conn))
        try test(PetToyMigration<Database>.prepare(on: conn))
        try _benchmark(on: conn)
    }
}

