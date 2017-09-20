import XCTest
@testable import SQLite

extension Database {
    static func makeTestConnection(queue: DispatchQueue) -> Database? {
        do {
            let sqlite = try Database(path: "/tmp/test_database.sqlite", queue: queue)
            return sqlite
            
        } catch {
            XCTFail()
        }
        return nil
    }
}
