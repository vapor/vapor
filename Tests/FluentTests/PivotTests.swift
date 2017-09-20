import XCTest
@testable import Fluent

class PivotTests: XCTestCase {
    var lqd: LastQueryDriver!
    var db: Database!

    override func setUp() {
        lqd = LastQueryDriver()
        db = Database(lqd)
    }

    func testEntityAttach() throws {
        Pivot<Atom, Compound>.database = db
        let atom = Atom(name: "Hydrogen")
        atom.id = 42
        atom.exists = true

        let compound = Compound(name: "Water")
        compound.id = 1337
        compound.exists = true

        try atom.compounds.add(compound)

        guard let (sql, values) = lqd.lastQuery else {
            XCTFail("No query recorded")
            return
        }

        XCTAssertEqual(
            sql,
            "INSERT INTO `atom_compound` (`\(Pivot<Atom, Compound>.idKey)`, `\(Atom.foreignIdKey)`, `\(Compound.foreignIdKey)`) VALUES (?, ?, ?)"
        )

        XCTAssertEqual(values.count, 3)
    }

    static let allTests = [
        ("testEntityAttach", testEntityAttach),
    ]
}
