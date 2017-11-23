import FormURLEncoded
import XCTest

class FormURLEncodedCodableTests: XCTestCase {
    func testDecode() throws {
        let data = """
        name=Tanner&age=23&pets[]=Zizek&pets[]=Foo&dict[a]=1&dict[b]=2
        """.data(using: .utf8)!

        let user = try FormURLDecoder().decode(User.self, from: data)
        XCTAssertEqual(user.name, "Tanner")
        XCTAssertEqual(user.age, 23)
        XCTAssertEqual(user.pets.count, 2)
        XCTAssertEqual(user.pets.first, "Zizek")
        XCTAssertEqual(user.pets.last, "Foo")
        XCTAssertEqual(user.dict["a"], 1)
        XCTAssertEqual(user.dict["b"], 2)
    }

    func testEncode() throws {
        let user = User(name: "Tanner", age: 23, pets: ["Zizek"], dict: ["a": 1, "b": 2])
        let expected = """
        name=Tanner&age=23&pets[]=Zizek&pets[]=Foo&dict[a]=1&dict[b]=2
        """
        let data = try FormURLEncoder().encode(user)
        XCTAssertEqual(String(data: data, encoding: .utf8)!, expected)
    }

    static let allTests = [
        ("testDecode", testDecode),
    ]
}

struct User: Codable {
    var name: String
    var age: Int
    var pets: [String]
    var dict: [String: Int]
}
