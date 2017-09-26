import Dispatch
import XCTest
@testable import SQLite

extension Connection {
    static func makeTestConnection(queue: DispatchQueue) -> Connection? {
        do {
            let sqlite = try Connection(path: "/tmp/test_database.sqlite", queue: queue)
            return sqlite
            
        } catch {
            XCTFail()
        }
        return nil
    }
}
