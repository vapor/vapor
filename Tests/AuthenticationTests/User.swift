import Authentication
import Async
import FluentSQLite
import Foundation

let test = DatabaseIdentifier<SQLiteDatabase>("test")

final class User: Model, Migration, PasswordAuthenticatable {
    typealias Database = SQLiteDatabase
    
    static let idKey = \User.id
    static let usernameKey = \User.email
    static let passwordKey = \User.password
    static let database = test

    var id: UUID?
    var name: String
    var email: String
    var password: String

    init(name: String, email: String, password: String) {
        self.name = name
        self.email = email
        self.password = password
    }

    static func prepare(on connection: SQLiteDatabase.Connection) -> Future<Void> {
        return connection.create(self) { table in
            try table.field(for: \.id)
            try table.field(for: \.name)
            try table.field(for: \.email)
            try table.field(for: \.password)
        }
    }

    static func revert(on connection: SQLiteDatabase.Connection) -> Future<Void> {
        return connection.delete(self)
    }
}
