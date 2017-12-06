import Validation
import XCTest

class ValidationTests: XCTestCase {
    func testValidate() throws {
        let user = User(name: "Tan", age: 20)
        user.child = User(name: "Zizek Pulaski", age: 3)
        //user.child?.child = User(name: "Rubber band", age: 1)
        do {
            try user.validate()
        } catch {
            print("\(error)")
        }
    }

    static var allTests = [
        ("testValidate", testValidate)
    ]
}

final class User: Validatable {
    var id: Int?
    var name: String
    var age: Int
    var child: User?

    init(id: Int? = nil, name: String, age: Int) {
        self.id = id
        self.name = name
        self.age = age
    }

    static var keyStringMap: KeyStringMap = [
        key(\.id): "id",
        key(\.name): "name",
        key(\.age): "age",
        key(\.child): "child"
    ]

    static var validations: Validations = [
        key(\.name): IsCount(5...),
        key(\.age): !(!IsCount(18...)),
        key(\.child): !IsNil() && IsValid()
    ]
}
