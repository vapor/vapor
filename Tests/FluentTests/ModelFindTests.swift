import XCTest
@testable import Fluent

class ModelFindTests: XCTestCase {

    /// Dummy Model implementation for testing.
    final class DummyModel: Entity {
        let storage = Storage()
        static var entity: String {
            return "dummy_models"
        }

        init(row: Row) throws {

        }

        func makeRow() -> Row {
            return .null
        }

    }

    /// Dummy Driver implementation for testing.
    class DummyDriver: Driver {
        var keyNamingConvention: KeyNamingConvention = .snake_case

        var idType: IdentifierType = .int
        var queryLogger: QueryLogger?
        
        var idKey: String {
            return "foo"
        }

        enum Error: Swift.Error {
            case broken
        }
        
        public func makeConnection(_ type: ConnectionType) throws -> Connection {
            return DummyConnection(driver: self)
        }
    }
    
    class DummyConnection: Connection {
        public var isClosed: Bool = false
        
        var driver: DummyDriver
        var queryLogger: QueryLogger?
        
        init(driver: DummyDriver) {
            self.driver = driver
        }
        
        func query<E>(_ query: RawOr<Query<E>>) throws -> Node {
            guard case .some(let query) = query else {
                return .null
            }
            
            if
                let filter = query.filters.first?.wrapped,
                case .compare(let key, let comparison, let value) = filter.method,
                query.action == .fetch([]) &&
                    query.filters.count == 1 &&
                    key == driver.idKey &&
                    comparison == .equals
            {
                if value.int == 42 {
                    return .array([
                        .object([driver.idKey: 42])
                    ])
                } else if value.int == 500 {
                    throw DummyDriver.Error.broken
                }
            }
            
            return .array([])
        }
    }

    static let allTests = [
        ("testFindFailing", testFindFailing),
        ("testFindSucceeding", testFindSucceeding),
        ("testFindErroring", testFindErroring),
    ]

    override func setUp() {
        Node.fuzzy = [Node.self]
        database = Database(DummyDriver())
        Database.default = database
    }

    var database: Database!

    func testFindFailing() {
        do {
            let result = try DummyModel.find(404)
            XCTAssert(result == nil, "Result should be nil")
        } catch {
            XCTFail("Find should not have failed")
        }
    }

    func testFindSucceeding() {
        do {
            let result = try DummyModel.find(42)
            XCTAssert(result?.id?.int == 42, "Result should have matching id")
        } catch {
            XCTFail("Find should not have failed")
        }
    }

    func testFindErroring() {
        do {
            let _ = try DummyModel.find(500)
            XCTFail("Should have thrown error")
        } catch DummyDriver.Error.broken {
            //
        } catch {
            XCTFail("Error should have been caught")
        }
    }
}
