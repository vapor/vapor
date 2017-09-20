import XCTest
@testable import Fluent

extension Entity {
    static func willCreate(entity: Entity) {
        guard let dummyModel = entity as? CallbacksTests.DummyModel else { return }
        dummyModel.staticWasModifiedOnCreate = true
    }
}

class CallbacksTests: XCTestCase {

    /// Dummy Model implementation for testing.
    final class DummyModel: Entity {
        let storage = Storage()
        var wasModifiedOnCreate: Bool = false
        var wasModifiedOnUpdate: Bool = false
        
        var staticWasModifiedOnCreate: Bool = false
        var staticWasModifiedOnUpdate: Bool = false

        init() {
            
        }
        
        init(row: Row) throws {

        }

        func makeRow() -> Row {
            return .null
        }
        
        static func willUpdate(entity: Entity) {
            guard let dummyModel = entity as? DummyModel else { return }
            dummyModel.staticWasModifiedOnUpdate = true
        }
        
        func willCreate() {
            wasModifiedOnCreate = true
        }
        
        func willUpdate() {
            wasModifiedOnUpdate = true
        }

        func didCreate() {
            do {
                try assertExists()
            } catch let error {
                XCTFail("Should exist. Error: \(error)")
            }
        }

        func didDelete() {
            XCTAssertThrowsError(try assertExists()) { error in
                XCTAssertTrue(error is EntityError)
                if case .doesntExist = error as! EntityError {
                } else {
                    XCTFail()
                }
            }
        }
    }

    static let allTests = [
        ("testCreateCallbacksCanMutateProperties", testCreateCallbacksCanMutateProperties),
        ("testUpdateCallbacksCanMutateProperties", testUpdateCallbacksCanMutateProperties)
    ]

    override func setUp() {
        Node.fuzzy = [Node.self]
        database = Database(DummyDriver())
        Database.default = database
    }

    var database: Database!
    
    func testStaticCreateCallbacksCanMutateProperties() {
        let result = DummyModel()
        XCTAssertFalse(result.staticWasModifiedOnCreate, "Result should not have been modified yet")
        
        try? result.save()
        XCTAssertTrue(result.staticWasModifiedOnCreate, "Result should have been modified by now")
    }
    
    func testStaticUpdateCallbacksCanMutateProperties() {
        let result = DummyModel()
        XCTAssertFalse(result.staticWasModifiedOnUpdate, "Result should not have been modified yet")
        
        try? result.save()
        XCTAssertFalse(result.staticWasModifiedOnUpdate, "Result should not have been modified yet")
        
        // Save the object once more to trigger the update callback
        try? result.save()
        XCTAssertTrue(result.staticWasModifiedOnUpdate, "Result should have been modified by now")
    }

    func testCreateCallbacksCanMutateProperties() {
        let result = DummyModel()
        XCTAssertFalse(result.wasModifiedOnCreate, "Result should not have been modified yet")
        
        try? result.save()
        XCTAssertTrue(result.wasModifiedOnCreate, "Result should have been modified by now")
    }
    
    func testUpdateCallbacksCanMutateProperties() {
        let result = DummyModel()
        XCTAssertFalse(result.wasModifiedOnUpdate, "Result should not have been modified yet")
        
        try? result.save()
        XCTAssertFalse(result.wasModifiedOnUpdate, "Result should not have been modified yet")
        
        // Save the object once more to trigger the update callback
        try? result.save()
        XCTAssertTrue(result.wasModifiedOnUpdate, "Result should have been modified by now")
    }

    func testDelete() {
        let result = DummyModel()
        try? result.save()
        try? result.delete()
    }
}
