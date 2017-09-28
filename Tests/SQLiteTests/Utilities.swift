import Dispatch
import XCTest
@testable import SQLite

extension Connection {
    static func makeTestConnection(queue: DispatchQueue) -> Connection? {
        do {
            let sqlite = try Database(path: "/tmp/test_database.sqlite").makeConnection(on: queue)
            return sqlite
            
        } catch {
            XCTFail()
        }
        return nil
    }
}
