import Vapor
import XCTest

class ValidationTests: XCTestCase {
    func testValidate() throws {
        let user = """
        {
            "name": "Tanner",
            "age": 24,
            "email": null
        }
        """
        let decoder = try JSONDecoder().decode(DecoderUnwrapper.self, from: Data(user.utf8))
        try User.validate(decoder.decoder)
        
//        let user = User(name: "Tanner", age: 23, pet: Pet(name: "Zizek Pulaski", age: 4), preferedColors: ["blue?", "green?"])
//        user.luckyNumber = 7
//        user.email = "tanner@vapor.codes"
//        try user.validate()
//        try user.pet.validate()
//
//        let secondUser = User(name: "Natan", age: 30, pet: Pet(name: "Nina", age: 4), preferedColors: ["pink"])
//        secondUser.profilePictureURL = "https://www.somedomain.com/somePath.png"
//        secondUser.email = "natan@vapor.codes"
//        try secondUser.validate()
    }
//
//    func testASCII() throws {
//        try Validator<String>.ascii.validate("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
//        try Validator<String>.ascii.validate("\n\r\t")
//        XCTAssertThrowsError(try Validator<String>.ascii.validate("\n\r\t\u{129}"))
//        try Validator<String>.ascii.validate(" !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
//        XCTAssertThrowsError(try Validator<String>.ascii.validate("ABCDEFGHIJKLMNOPQR🤠STUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"))
//    }
//
//    func testAlphanumeric() throws {
//        try Validator<String>.alphanumeric.validate("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
//        XCTAssertThrowsError(try Validator<String>.alphanumeric.validate("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"))
//    }
//    
//    func testEmpty() throws {
//        try Validator<String>.empty.validate("")
//        XCTAssertThrowsError(try Validator<String>.empty.validate("something"))
//        try Validator<[Int]>.empty.validate([])
//        XCTAssertThrowsError(try Validator<[Int]>.empty.validate([1, 2]))
//    }
//
//    func testEmail() throws {
//        try Validator<String>.email.validate("tanner@vapor.codes")
//        XCTAssertThrowsError(try Validator<String>.email.validate("tanner@vapor.codestanner@vapor.codes"))
//        XCTAssertThrowsError(try Validator<String>.email.validate("tanner@vapor.codes."))
//        XCTAssertThrowsError(try Validator<String>.email.validate("tanner@@vapor.codes"))
//        XCTAssertThrowsError(try Validator<String>.email.validate("@vapor.codes"))
//        XCTAssertThrowsError(try Validator<String>.email.validate("tanner@codes"))
//        XCTAssertThrowsError(try Validator<String>.email.validate("asdf"))
//    }
//    
//    func testRange() throws {
//        try Validator<Int>.range(-5...5).validate(4)
//        try Validator<Int>.range(-5...5).validate(5)
//        try Validator<Int>.range(-5...5).validate(-5)
//        XCTAssertThrowsError(try Validator<Int>.range(-5...5).validate(6)) { error in
//            XCTAssertEqual((error as? ValidationError)?.reason, "data is greater than 5")
//        }
//        XCTAssertThrowsError(try Validator<Int>.range(-5...5).validate(-6)) { error in
//            XCTAssertEqual((error as? ValidationError)?.reason, "data is less than -5")
//        }
//
//        try Validator<Int>.range(5...).validate(.max)
//
//        try Validator<Int>.range(-5..<6).validate(-5)
//        try Validator<Int>.range(-5..<6).validate(-4)
//        try Validator<Int>.range(-5..<6).validate(5)
//        XCTAssertThrowsError(try Validator<Int>.range(-5..<6).validate(-6))
//        XCTAssertThrowsError(try Validator<Int>.range(-5..<6).validate(6))
//    }
//
//    func testCountCharacters() throws {
//        let validator = Validator<String>.count(1...6)
//        try validator.validate("1")
//        try validator.validate("123")
//        try validator.validate("123456")
//        XCTAssertThrowsError(try validator.validate("")) { error in
//            XCTAssertEqual((error as? ValidationError)?.reason, "data is less than required minimum of 1 character")
//        }
//        XCTAssertThrowsError(try validator.validate("1234567")) { error in
//            XCTAssertEqual((error as? ValidationError)?.reason, "data is greater than required maximum of 6 characters")
//        }
//    }
//
//    func testCountItems() throws {
//        let validator = Validator<[Int]>.count(1...6)
//        try validator.validate([1])
//        try validator.validate([1, 2, 3])
//        try validator.validate([1, 2, 3, 4, 5, 6])
//        XCTAssertThrowsError(try validator.validate([])) { error in
//            XCTAssertEqual((error as? ValidationError)?.reason, "data is less than required minimum of 1 item")
//        }
//        XCTAssertThrowsError(try validator.validate([1, 2, 3, 4, 5, 6, 7])) { error in
//            XCTAssertEqual((error as? ValidationError)?.reason, "data is greater than required maximum of 6 items")
//        }
//    }
//
//    func testURL() throws {
//        try Validator<String>.url.validate("https://www.somedomain.com/somepath.png")
//        try Validator<String>.url.validate("https://www.somedomain.com/")
//        try Validator<String>.url.validate("file:///Users/vapor/rocks/somePath.png")
//        XCTAssertThrowsError(try Validator<String>.url.validate("www.somedomain.com/"))
//        XCTAssertThrowsError(try Validator<String>.url.validate("bananas"))
//    }
}

private final class User: Validatable, Codable {
    var id: Int?
    var name: String
    var age: Int
    var email: String?
    var pet: Pet
    var luckyNumber: Int?
    var profilePictureURL: String?
    var preferedColors: [String]

    init(id: Int? = nil, name: String, age: Int, pet: Pet, preferedColors: [String] = []) {
        self.id = id
        self.name = name
        self.age = age
        self.pet = pet
        self.preferedColors = preferedColors
    }

    static func validations() -> Validations {
        var validations = Validations()
        // validate name is at least 5 characters and alphanumeric
        validations.add("name", as: String.self, is: .count(5...) && .alphanumeric)
        // validate age is 18 or older
        validations.add("age", as: Int.self, is: .range(18...))
//        // validate the email is valid and is not nil
        validations.add("email", as: String?.self, is: .nil || .email)
//        try validations.add(\.email, .email && !.nil) // test other way
//        // validate the email is valid or is nil
//        try validations.add(\.email, .nil || .email)
//        try validations.add(\.email, .email || .nil) // test other way
//        // validate that the lucky number is nil or is 5 or 7
//        try validations.add(\.luckyNumber, .nil || .in(5, 7))
//        // validate that the profile picture is nil or a valid URL
//        try validations.add(\.profilePictureURL, .url || .nil)
//        try validations.add(\.preferedColors, !.empty)
        print(validations)
        return validations
    }
}

private final class Pet: Codable, Validatable {
    var name: String
    var age: Int
    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    static func validations() -> Validations {
        var validations = Validations()
//        try validations.add(\.name, .count(5...) && .characterSet(.alphanumerics + .whitespaces))
//        try validations.add(\.age, .range(3...))
        return validations
    }
}
