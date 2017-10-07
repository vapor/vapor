import Fluent
import Foundation

final class User: Model {
    var id: UUID?
    var name: String
    var age: Int
    let storage: Storage

    init(id: UUID?, name: String, age: Int) {
        self.id = id
        self.name = name
        self.age = age
        self.storage = .init()
    }
}
