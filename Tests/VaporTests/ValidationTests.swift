import Vapor
import XCTest

class ValidationTests: XCTestCase {
    func testValidate() {
        let valid = """
        {
            "name": "Tanner",
            "age": 24,
            "email": "me@tanner.xyz",
            "luckyNumber": 5,
            "profilePictureURL": "https://foo.jpg",
            "preferredColors": ["blue"],
            "pet": {
                "name": "Zizek",
                "age": 3
            }
        }
        """
        XCTAssertNoThrow(try User.validate(json: valid))
        let invalid = """
        {
            "name": "Tan!ner",
            "age": 24,
            "email": "me@tanner.xyz",
            "luckyNumber": 5,
            "profilePictureURL": "https://foo.jpg",
            "preferredColors": ["blue"],
            "pet": {
                "name": "Zizek",
                "age": 3
            }
        }
        """
        XCTAssertThrowsError(try User.validate(json: invalid)) { error in
            guard let validationsError = error as? ValidationsError else {
                XCTFail("error is not of type ValidationsError")
                return
            }
            XCTAssertTrue(validationsError.description.contains("contains an invalid character: '!' (allowed: A-Z, a-z, 0-9)"))
        }
    }

    func testASCII() {
        assert("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", validatedAs: .ascii, hasDescription: "contains only valid characters", failed: false)
        assert("\n\r\t", validatedAs: .ascii, hasDescription: "contains only valid characters", failed: false)
        assert("\n\r\t\u{129}", validatedAs: .ascii, hasDescription: "contains an invalid character: 'ĩ'", failed: true)
        assert(" !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~", validatedAs: .ascii, hasDescription: "contains only valid characters", failed: false)
        assert("ABCDEFGHIJKLMNOPQR🤠STUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", validatedAs: .ascii, hasDescription: "contains an invalid character: '🤠'", failed: true)
    }

    func testAlphanumeric() {
        assert("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", validatedAs: .alphanumeric, hasDescription: "contains only valid characters (allowed: A-Z, a-z, 0-9)", failed: false)
        assert("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", validatedAs: .alphanumeric, hasDescription: "contains an invalid character: '+' (allowed: A-Z, a-z, 0-9)", failed: true)
    }

    func testEmpty() {
        assert("", validatedAs: .empty, hasDescription: "is empty", failed: false)
        assert("something", validatedAs: .empty, hasDescription: "is not empty", failed: true)
        assert([Int](), validatedAs: .empty, hasDescription: "is empty", failed: false)
        assert([1, 2], validatedAs: .empty, hasDescription: "is not empty", failed: true)
    }

    func testEmail() {
        assert("tanner@vapor.codes", validatedAs: .email, hasDescription: "is a valid email address", failed: false)
        assert("tanner@vapor.codestanner@vapor.codes", validatedAs: .email, hasDescription: "is not a valid email address", failed: true)
        assert("tanner@vapor.codes.", validatedAs: .email, hasDescription: "is not a valid email address", failed: true)
        assert("tanner@@vapor.codes", validatedAs: .email, hasDescription: "is not a valid email address", failed: true)
        assert("@vapor.codes", validatedAs: .email, hasDescription: "is not a valid email address", failed: true)
        assert("tanner@codes", validatedAs: .email, hasDescription: "is not a valid email address", failed: true)
        assert("asdf", validatedAs: .email, hasDescription: "is not a valid email address", failed: true)
    }
    
    func testRange() {
        assert(4, validatedAs: .range(-5...5), hasDescription: "is between -5 and 5", failed: false)
        assert(5, validatedAs: .range(-5...5), hasDescription: "is between -5 and 5", failed: false)
        assert(-5, validatedAs: .range(-5...5), hasDescription: "is between -5 and 5", failed: false)
        assert(6, validatedAs: .range(-5...5), hasDescription: "is greater than maximum of 5", failed: true)
        assert(-6, validatedAs: .range(-5...5), hasDescription: "is less than minimum of -5", failed: true)
        assert(.max, validatedAs: .range(5...), hasDescription: "is greater than or equal to minimum of 5", failed: false)
        assert(-5, validatedAs: .range(-5..<6), hasDescription: "is between -5 and 5", failed: false)
        assert(-4, validatedAs: .range(-5..<6), hasDescription: "is between -5 and 5", failed: false)
        assert(5, validatedAs: .range(-5..<6), hasDescription: "is between -5 and 5", failed: false)
        assert(-6, validatedAs: .range(-5..<6), hasDescription: "is less than minimum of -5", failed: true)
        assert(6, validatedAs: .range(-5..<6), hasDescription: "is greater than maximum of 5", failed: true)
    }

    func testCountCharacters() {
        assert("1", validatedAs: .count(1...6), hasDescription: "is between 1 and 6 characters", failed: false)
        assert("123", validatedAs: .count(1...6), hasDescription: "is between 1 and 6 characters", failed: false)
        assert("123456", validatedAs: .count(1...6), hasDescription: "is between 1 and 6 characters", failed: false)
        assert("", validatedAs: .count(1...6), hasDescription: "is less than minimum of 1 character", failed: true)
        assert("1234567", validatedAs: .count(1...6), hasDescription: "is greater than maximum of 6 characters", failed: true)
    }

    func testCountItems() {
        assert([1], validatedAs: .count(1...6), hasDescription: "is between 1 and 6 items", failed: false)
        assert([1, 2, 3], validatedAs: .count(1...6), hasDescription: "is between 1 and 6 items", failed: false)
        assert([1, 2, 3, 4, 5, 6], validatedAs: .count(1...6), hasDescription: "is between 1 and 6 items", failed: false)
        assert([Int](), validatedAs: .count(1...6), hasDescription: "is less than minimum of 1 item", failed: true)
        assert([1, 2, 3, 4, 5, 6, 7], validatedAs: .count(1...6), hasDescription: "is greater than maximum of 6 items", failed: true)
    }

    func testURL() {
        assert("https://www.somedomain.com/somepath.png", validatedAs: .url, hasDescription: "a valid URL", failed: false)
        assert("https://www.somedomain.com/", validatedAs: .url, hasDescription: "a valid URL", failed: false)
        assert("file:///Users/vapor/rocks/somePath.png", validatedAs: .url, hasDescription: "a valid URL", failed: false)
        assert("www.somedomain.com/", validatedAs: .url, hasDescription: "an invalid URL", failed: true)
        assert("bananas", validatedAs: .url, hasDescription: "an invalid URL", failed: true)
    }

    func testPreexistingValidatorResultIsIncluded() {
        struct CustomValidatorResult: ValidatorResult {
            let failed = true
            let description = "custom description"
        }
        let validations = [Validation("key", result: CustomValidatorResult())]
        XCTAssertThrowsError(try validations.validate(json: "{}")) { error in
            XCTAssertEqual((error as? ValidationsError)?.description, "key: custom description")
        }
    }

    func testDoubleNegationIsAvoided() {
        let validations = [Validation("key", as: String.self, is: !.empty)]
        XCTAssertThrowsError(try validations.validate(json: #"{"key": ""}"#)) { error in
            XCTAssertEqual((error as? ValidationsError)?.description, "key: is empty")
        }
    }
}

private func assert<T>(_ data: T, validatedAs validator: Validator<T>, hasDescription description: String, failed: Bool, file: StaticString = #file, line: UInt = #line) {
    let result = validator.validate(data)
    XCTAssertEqual(result.description, description, file: file, line: line)
    XCTAssertEqual(result.failed, failed, file: file, line: line)
}

private final class User: Validatable, Codable {
    var id: Int?
    var name: String
    var age: Int
    var email: String?
    var pet: Pet
    var luckyNumber: Int?
    var profilePictureURL: String?
    var preferredColors: [String]
    
    struct Pet: Codable {
        var name: String
        var age: Int
        init(name: String, age: Int) {
            self.name = name
            self.age = age
        }
    }

    init(id: Int? = nil, name: String, age: Int, pet: Pet, preferredColors: [String] = []) {
        self.id = id
        self.name = name
        self.age = age
        self.pet = pet
        self.preferredColors = preferredColors
    }

    static func validations() -> [Validation] {
        [
            // validate name is at least 5 characters and alphanumeric
            .init("name", as: String.self, is: .count(5...) && .alphanumeric),
            // validate age is 18 or older
            .init("age", as: Int.self, is: .range(18...)),
            // validate the email is valid and is not nil
            .init("email", as: String?.self, is: !.nil && .email),
            .init("email", as: String?.self, is: .email && !.nil), // test other way
            // validate the email is valid or is nil
            .init("email", as: String?.self, is: .nil || .email),
            .init("email", as: String?.self, is: .email || .nil), // test other way
            // validate that the lucky number is nil or is 5 or 7
            .init("luckyNumber", as: Int?.self, is: .nil || .in(5, 7)),
            // validate that the profile picture is nil or a valid URL
            .init("profilePictureURL", as: String?.self, is: .url || .nil),
            .init("preferredColors", as: [String].self, is: !.empty),
            // pet validations
            .init("pet", validations: [
                .init("name", as: String.self, is: .count(5...) && .characterSet(.alphanumerics + .whitespaces)),
                .init("age", as: Int.self, is: .range(3...))
            ])
        ]
    }
}
