import XCTest
import FluentBenchmark
import FluentMySQL

class FluentMySQLTests: XCTestCase {
    var benchmarker: Benchmarker<MySQLDatabase>!
    
    override func setUp() {
        let database = MySQLDatabase(
            hostname: "localhost",
            user: "root",
            password: nil,
            database: "vapor_test"
        )
        
        benchmarker = Benchmarker(database, onFail: XCTFail)
        
        try! benchmarker.database.makeConnection(on: DispatchQueue(label: "temp")).then { conn in
            return conn.connection.administrativeQuery("DROP TABLE IF EXISTS `users`, `foo`")
        }.blockingAwait(timeout: .seconds(3))
    }
    
    func testSchema() throws {
        try benchmarker.benchmarkSchema()
    }
    
    func testModels() throws {
        try benchmarker.benchmarkModels_withSchema()
    }
    
//    func testRelations() throws {
//        try benchmarker.benchmarkRelations_withSchema()
//    }
    
    func testTimestampable() throws {
        try benchmarker.benchmarkTimestampable_withSchema()
    }
    
    func testTransactions() throws {
        try benchmarker.benchmarkTransactions_withSchema()
    }
    
    func testChunking() throws {
        try benchmarker.benchmarkChunking_withSchema()
    }
    
    static let allTests = [
        ("testSchema", testSchema),
        ("testModels", testModels),
//        ("testRelations", testRelations),
        ("testTimestampable", testTimestampable),
        ("testTransactions", testTransactions),
        ("testChunking", testChunking),
        ]
}
