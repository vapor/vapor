import HTTP
import Vapor

final class User: JSONCodable, ContentCodable, ResponseRepresentable {
    var name: String
    var age: Int

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
}
