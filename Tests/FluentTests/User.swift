import Async
import Dispatch
import Fluent
import Foundation
import SQLite

final class User: Model {
    var id: UUID?
    var name: String
    var age: Int

    init(id: UUID? = nil, name: String, age: Int) {
        self.id = id
        self.name = name
        self.age = age
    }
}

extension User: Migration {
    static func prepare(_ database: DatabaseConnection) -> Future<Void> {
        return database.create(User.self) { builder in
            builder.id()
            builder.string("name")
            builder.int("age")
        }
    }

    static func revert(_ database: DatabaseConnection) -> Future<Void> {
        return database.delete(User.self)
    }
}

extension User {
    static func makeTestConnection() throws -> DatabaseConnection {
        let conn = try SQLiteDatabase.makeTestConnection()
        try User.prepare(conn).blockingAwait()
        return conn
    }
}

extension SQLiteDatabase {
    static func makeTestConnection() throws -> DatabaseConnection {
        let test = DispatchQueue(label: "codes.vapor.test.fluent.database")
        let futureConn = SQLiteDatabase(storage: .memory)
            .makeConnection(on: EventLoop(queue: test)) as Future<DatabaseConnection>
        return try futureConn.blockingAwait()
    }
}
