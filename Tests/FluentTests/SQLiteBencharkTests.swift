import Async
import Fluent
import FluentBenchmark
import FluentSQLite
import SQLite
import XCTest

final class SQLiteBencharkTests: XCTestCase {
    var benchmarker: Benchmarker<SQLiteDatabase>!

    override func setUp() {
        let database = SQLiteDatabase(storage: .memory)
        benchmarker = Benchmarker(database, onFail: XCTFail)
    }

    func testSchema() throws {
        try benchmarker.benchmarkSchema()
    }

    func testModels() throws {
        try benchmarker.benchmarkModels_withSchema()
    }

    static let allTests = [
        ("testSchema", testSchema),
        ("testModels", testModels),
    ]
}
