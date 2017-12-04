import FormURLEncoded
import HTTP
import XCTest

class FormURLEncodedCodableTests: XCTestCase {
    func testDecode() throws {
        let data = """
        name=Tanner&age=23&pets[]=Zizek&pets[]=Foo&dict[a]=1&dict[b]=2
        """.data(using: .utf8)!

        let user = try FormURLDecoder().decode(User.self, from: HTTPBody(data))
        XCTAssertEqual(user.name, "Tanner")
        XCTAssertEqual(user.age, 23)
        XCTAssertEqual(user.pets.count, 2)
        XCTAssertEqual(user.pets.first, "Zizek")
        XCTAssertEqual(user.pets.last, "Foo")
        XCTAssertEqual(user.dict["a"], 1)
        XCTAssertEqual(user.dict["b"], 2)
    }

    func testEncode() throws {
        let user = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2])
        let expected = """
        pets[]=Zizek&pets[]=Foo&name=Tanner&age=23&dict[b]=2&dict[a]=1
        """
        let data = try FormURLEncoder().encodeBody(from: user).data
        XCTAssertEqual(String(data: data!, encoding: .utf8)!, expected)
    }

    func testCodable() throws {
        let a = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2])
        let body = try FormURLEncoder().encodeBody(from: a)
        let b = try FormURLDecoder().decode(User.self, from: body)
        XCTAssertEqual(a, b)
    }

    static let allTests = [
        ("testDecode", testDecode),
        ("testEncode", testEncode),
        ("testCodable", testCodable),
    ]
}

struct User: Codable, Equatable {
    static func ==(lhs: User, rhs: User) -> Bool {
        return lhs.name == rhs.name
            && lhs.age == rhs.age
            && lhs.pets == rhs.pets
            && lhs.dict == rhs.dict
    }

    var name: String
    var age: Int
    var pets: [String]
    var dict: [String: Int]
}
