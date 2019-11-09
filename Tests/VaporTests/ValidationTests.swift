import Vapor
import XCTest

class ValidationTests: XCTestCase {
    func testValidate() throws {
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

    func testASCII() throws {
        assert("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", validatedAs: .ascii, hasDescription: "contains valid characters", failed: false)
        assert("\n\r\t", validatedAs: .ascii, hasDescription: "contains valid characters", failed: false)
        assert("\n\r\t\u{129}", validatedAs: .ascii, hasDescription: "contains an invalid character: 'ĩ'", failed: true)
        assert(" !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~", validatedAs: .ascii, hasDescription: "contains valid characters", failed: false)
        assert("ABCDEFGHIJKLMNOPQR🤠STUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", validatedAs: .ascii, hasDescription: "contains an invalid character: '🤠'", failed: true)
    }

    func testAlphanumeric() throws {
        assert("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", validatedAs: .alphanumeric, hasDescription: "contains valid characters (allowed: A-Z, a-z, 0-9)", failed: false)
        assert("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", validatedAs: .alphanumeric, hasDescription: "contains an invalid character: '+' (allowed: A-Z, a-z, 0-9)", failed: true)
    }

    func testEmpty() throws {
        assert("", validatedAs: .empty, hasDescription: "empty", failed: false)
        assert("something", validatedAs: .empty, hasDescription: "empty", failed: true)
        assert([Int](), validatedAs: .empty, hasDescription: "empty", failed: false)
        assert([1, 2], validatedAs: .empty, hasDescription: "empty", failed: true)
    }

    func testEmail() throws {
        assert("tanner@vapor.codes", validatedAs: .email, hasDescription: "a valid email address", failed: false)
        assert("tanner@vapor.codestanner@vapor.codes", validatedAs: .email, hasDescription: "a valid email address", failed: true)
        assert("tanner@vapor.codes.", validatedAs: .email, hasDescription: "a valid email address", failed: true)
        assert("tanner@@vapor.codes", validatedAs: .email, hasDescription: "a valid email address", failed: true)
        assert("@vapor.codes", validatedAs: .email, hasDescription: "a valid email address", failed: true)
        assert("tanner@codes", validatedAs: .email, hasDescription: "a valid email address", failed: true)
        assert("asdf", validatedAs: .email, hasDescription: "a valid email address", failed: true)
    }
    
    func testRange() throws {
        assert(4, validatedAs: .range(-5...5), hasDescription: "between -5 and 5", failed: false)
        assert(5, validatedAs: .range(-5...5), hasDescription: "between -5 and 5", failed: false)
        assert(-5, validatedAs: .range(-5...5), hasDescription: "between -5 and 5", failed: false)
        assert(6, validatedAs: .range(-5...5), hasDescription: "greater than maximum of 5", failed: true)
        assert(-6, validatedAs: .range(-5...5), hasDescription: "less than minimum of -5", failed: true)
        assert(.max, validatedAs: .range(5...), hasDescription: "greater than or equal to minimum of 5", failed: false)
        assert(-5, validatedAs: .range(-5..<6), hasDescription: "between -5 and 5", failed: false)
        assert(-4, validatedAs: .range(-5..<6), hasDescription: "between -5 and 5", failed: false)
        assert(5, validatedAs: .range(-5..<6), hasDescription: "between -5 and 5", failed: false)
        assert(-6, validatedAs: .range(-5..<6), hasDescription: "less than minimum of -5", failed: true)
        assert(6, validatedAs: .range(-5..<6), hasDescription: "greater than maximum of 5", failed: true)
    }

    func testCountCharacters() throws {
        assert("1", validatedAs: .count(1...6), hasDescription: "between 1 and 6 characters", failed: false)
        assert("123", validatedAs: .count(1...6), hasDescription: "between 1 and 6 characters", failed: false)
        assert("123456", validatedAs: .count(1...6), hasDescription: "between 1 and 6 characters", failed: false)
        assert("", validatedAs: .count(1...6), hasDescription: "less than minimum of 1 character", failed: true)
        assert("1234567", validatedAs: .count(1...6), hasDescription: "greater than maximum of 6 characters", failed: true)
    }

    func testCountItems() throws {
        assert([1], validatedAs: .count(1...6), hasDescription: "between 1 and 6 items", failed: false)
        assert([1, 2, 3], validatedAs: .count(1...6), hasDescription: "between 1 and 6 items", failed: false)
        assert([1, 2, 3, 4, 5, 6], validatedAs: .count(1...6), hasDescription: "between 1 and 6 items", failed: false)
        assert([Int](), validatedAs: .count(1...6), hasDescription: "less than minimum of 1 item", failed: true)
        assert([1, 2, 3, 4, 5, 6, 7], validatedAs: .count(1...6), hasDescription: "greater than maximum of 6 items", failed: true)
    }

    func testURL() throws {
        assert("https://www.somedomain.com/somepath.png", validatedAs: .url, hasDescription: "a valid URL", failed: false)
        assert("https://www.somedomain.com/", validatedAs: .url, hasDescription: "a valid URL", failed: false)
        assert("file:///Users/vapor/rocks/somePath.png", validatedAs: .url, hasDescription: "a valid URL", failed: false)
        assert("www.somedomain.com/", validatedAs: .url, hasDescription: "a valid URL", failed: true)
        assert("bananas", validatedAs: .url, hasDescription: "a valid URL", failed: true)
    }

    func testPreexistingValidatorResultIsIncluded() throws {
        struct CustomValidatorResult: ValidatorResult {
            let failed = true
            let description = "right"
        }
        let validations = [Validation(key: "key", result: CustomValidatorResult())]
        XCTAssertThrowsError(try validations.validate(json: "{}")) { error in
            XCTAssertEqual((error as? ValidationsError)?.description, "key: is not right")
        }
    }

    func testDoubleNegationIsAvoided() throws {
        let validations = [Validation(key: "key", as: String.self, validator: !.empty)]
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
            Validation(key: "name", as: String.self, validator: .count(5...) && .alphanumeric),
            // validate age is 18 or older
            Validation(key: "age", as: Int.self, validator: .range(18...)),
            // validate the email is valid and is not nil
            Validation(key: "email", as: String?.self, validator: !.nil && .email),
            Validation(key: "email", as: String?.self, validator: .email && !.nil), // test other way
            // validate the email is valid or is nil
            Validation(key: "email", as: String?.self, validator: .nil || .email),
            Validation(key: "email", as: String?.self, validator: .email || .nil), // test other way
            // validate that the lucky number is nil or is 5 or 7
            Validation(key: "luckyNumber", as: Int?.self, validator: .nil || .in(5, 7)),
            // validate that the profile picture is nil or a valid URL
            Validation(key: "profilePictureURL", as: String?.self, validator: .url || .nil),
            Validation(key: "preferredColors", as: [String].self, validator: !.empty),
            // pet validations
            Validation(key: "pet", validations: [
                Validation(key: "name", as: String.self, validator: .count(5...) && .characterSet(.alphanumerics + .whitespaces)),
                Validation(key: "age", as: Int.self, validator: .range(3...))
            ])
        ]
    }
}
