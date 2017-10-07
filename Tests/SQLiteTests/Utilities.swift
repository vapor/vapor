import Dispatch
import XCTest
@testable import SQLite

extension SQLiteConnection {
    static func makeTestConnection(queue: DispatchQueue) -> SQLiteConnection? {
        do {
            let sqlite = try SQLiteDatabase(
                storage: .file(path: "/tmp/test_database.sqlite")
            )
            return try SQLiteConnection(database: sqlite, queue: queue)
        } catch {
            XCTFail()
        }
        return nil
    }
}
