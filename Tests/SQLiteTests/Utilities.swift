import Async
import Service
import Dispatch
import XCTest
@testable import SQLite

extension SQLiteConnection {
    static func makeTestConnection(queue: DispatchQueue) -> SQLiteConnection? {
        do {
            let sqlite = SQLiteDatabase(
                storage: .file(path: "/tmp/test_database.sqlite")
            )
            let container = BasicContainer(config: .init(), environment: .detect(), services: .init(), on: queue)
            
            return try sqlite.makeConnection(using: container).blockingAwait()
        } catch {
            XCTFail()
        }
        return nil
    }
}
