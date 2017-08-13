import Core
import Vapor

final class User: JSONCodable, ContentCodable, ResponseEncodable {
    var name: String
    var age: Int

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
}
