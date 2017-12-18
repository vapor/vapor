import Async
import Service
import Dispatch
import XCTest
@testable import SQLite

extension SQLiteConnection {
    static func makeTestConnection(queue: DispatchEventLoop) -> SQLiteConnection? {
        do {
            let sqlite = SQLiteDatabase(
                storage: .file(path: "/tmp/test_database.sqlite")
            )
            
            return try sqlite.makeConnection(on: queue).blockingAwait()
        } catch {
            XCTFail()
        }
        return nil
    }
}
