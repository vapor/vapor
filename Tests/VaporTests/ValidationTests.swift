import Vapor
import XCTest

class ValidationTests: XCTestCase {
    func testValidate() {
        let valid = """
        {
            "name": "Tanner",
            "age": 24,
            "gender": "male",
            "email": "me@tanner.xyz",
            "luckyNumber": 5,
            "profilePictureURL": "https://foo.jpg",
            "preferredColors": ["blue"],
            "pet": {
                "name": "Zizek",
                "age": 3
            },
            "favoritePet": null,
            "isAdmin": true
        }
        """
        let validUrl: URI = "https://tanner.xyz/user?name=Tanner&age=24&gender=male&email=me@tanner.xyz&luckyNumber=5&profilePictureURL=https://foo.jpg&preferredColors=[blue]&pet[name]=Zizek&pet[age]=3&isAdmin=true"
        XCTAssertNoThrow(try User.validate(json: valid))
        XCTAssertNoThrow(try User.validate(query: validUrl))
        let invalidUser = """
        {
            "name": "Tan!ner",
            "age": 24,
            "gender": "other",
            "email": "me@tanner.xyz",
            "luckyNumber": 5,
            "profilePictureURL": "https://foo.jpg",
            "preferredColors": ["blue"],
            "pet": {
                "name": "Zizek",
                "age": 3
            },
            "isAdmin": true
        }
        """
        let invalidUserUrl: URI = "https://tanner.xyz/user?name=Tan!ner&age=24&gender=other&email=me@tanner.xyz&luckyNumber=5&profilePictureURL=https://foo.jpg&preferredColors=[blue]&pet[name]=Zizek&pet[age]=3&isAdmin=true"
        XCTAssertThrowsError(try User.validate(json: invalidUser)) { error in
            XCTAssertEqual("\(error)",
                           "name contains '!' (allowed: A-Z, a-z, 0-9)")
            
        }
        XCTAssertThrowsError(try User.validate(query: invalidUserUrl)) { error in
            XCTAssertEqual("\(error)",
                           "name contains '!' (allowed: A-Z, a-z, 0-9)")
        }
        let invalidPet = """
        {
            "name": "Tanner",
            "age": 24,
            "gender": "male",
            "email": "me@tanner.xyz",
            "luckyNumber": 5,
            "profilePictureURL": "https://foo.jpg",
            "preferredColors": ["blue"],
            "pet": {
                "name": "Zi!zek",
                "age": 3
            },
            "isAdmin": true
        }
        """
        let invalidPetURL: URI = "https://tanner.xyz/user?name=Tanner&age=24&gender=male&email=me@tanner.xyz&luckyNumber=5&profilePictureURL=https://foo.jpg&preferredColors=[blue]&pet[name]=Zi!ek&pet[age]=3&isAdmin=true"
        XCTAssertThrowsError(try User.validate(json: invalidPet)) { error in
            XCTAssertEqual("\(error)",
                           "pet name contains '!' (allowed: whitespace, A-Z, a-z, 0-9)")
        }
        XCTAssertThrowsError(try User.validate(query: invalidPetURL)) { error in
            XCTAssertEqual("\(error)",
                       "pet name contains '!' (allowed: whitespace, A-Z, a-z, 0-9)")
        }
        let invalidBool = """
        {
            "name": "Tanner",
            "age": 24,
            "gender": "male",
            "email": "me@tanner.xyz",
            "luckyNumber": 5,
            "profilePictureURL": "https://foo.jpg",
            "preferredColors": ["blue"],
            "pet": {
                "name": "Zizek",
                "age": 3
            },
            "isAdmin": "true"
        }
        """
        let invalidPetBool: URI = "https://tanner.xyz/user?name=Tanner&age=24&gender=male&email=me@tanner.xyz&luckyNumber=5&profilePictureURL=https://foo.jpg&preferredColors=[blue]&pet[name]=Zizek&pet[age]=3&isAdmin='true'"
        XCTAssertThrowsError(try User.validate(json: invalidBool)) { error in
            XCTAssertEqual("\(error)",
                           "isAdmin is not a(n) Bool")
        }
        XCTAssertThrowsError(try User.validate(query: invalidPetBool)) { error in
            XCTAssertEqual("\(error)",
                       "isAdmin is not a(n) Bool")
        }
        let validOptionalFavoritePet = """
        {
            "name": "Tanner",
            "age": 24,
            "gender": "male",
            "email": "me@tanner.xyz",
            "luckyNumber": 5,
            "profilePictureURL": "https://foo.jpg",
            "preferredColors": ["blue"],
            "pet": {
                "name": "Zizek",
                "age": 3
            },
            "favoritePet": {
                "name": "Zizek",
                "age": 3
            },
            "isAdmin": true
        }
        """
        let validOptionalFavoritePetUrl: URI = "https://tanner.xyz/user?name=Tanner&age=24&gender=male&email=me@tanner.xyz&luckyNumber=5&profilePictureURL=https://foo.jpg&preferredColors=[blue]&pet[name]=Zizek&pet[age]=3&favoritePet[name]=Zizek&favoritePet[age]=3&&isAdmin=true"
        XCTAssertNoThrow(try User.validate(json: validOptionalFavoritePet))
        XCTAssertNoThrow(try User.validate(query: validOptionalFavoritePetUrl))
        let invalidOptionalFavoritePet = """
        {
            "name": "Tanner",
            "age": 24,
            "gender": "male",
            "email": "me@tanner.xyz",
            "luckyNumber": 5,
            "profilePictureURL": "https://foo.jpg",
            "preferredColors": ["blue"],
            "pet": {
                "name": "Zizek",
                "age": 3
            },
            "favoritePet": {
                "name": "Zi!zek",
                "age": 3
            },
            "isAdmin": true
        }
        """
        let invalidOptionalFavoritePetUrl: URI = "https://tanner.xyz/model?name=Tanner&age=24&gender=male&email=me@tanner.xyz&luckyNumber=5&profilePictureURL=https://foo.jpg&preferredColors=[blue]&pet[name]=Zizek&pet[age]=3&favoritePet[name]=Zi!ek&favoritePet[age]=3&&isAdmin=true"
        XCTAssertThrowsError(try User.validate(json: invalidOptionalFavoritePet)) { error in
            XCTAssertEqual("\(error)",
                           "favoritePet name contains '!' (allowed: whitespace, A-Z, a-z, 0-9)")
        }
        XCTAssertThrowsError(try User.validate(query: invalidOptionalFavoritePetUrl)) { error in
            XCTAssertEqual("\(error)",
                           "favoritePet name contains '!' (allowed: whitespace, A-Z, a-z, 0-9)")
        }
    }
    
    func testCatchError() throws {
        let invalidUser = """
        {
            "name": "Tan!ner",
            "age": 24,
            "gender": "male",
            "email": "me@tanner.xyz",
            "luckyNumber": 5,
            "profilePictureURL": "https://foo.jpg",
            "preferredColors": ["blue"],
            "pet": {
                "name": "Zizek",
                "age": 3
            },
            "isAdmin": true
        }
        """
        let invalidUserUrl: URI = "https://tanner.xyz/user?name=Tan!ner&age=24&gender=other&email=me@tanner.xyz&luckyNumber=5&profilePictureURL=https://foo.jpg&preferredColors=[blue]&pet[name]=Zizek&pet[age]=3&isAdmin=true"
        do {
            try User.validate(json: invalidUser)
        } catch let error as ValidationsError {
            XCTAssertEqual(error.failures.count, 1)
            let name = error.failures[0]
            XCTAssertEqual(name.key.stringValue, "name")
            XCTAssertEqual(name.result.isFailure, true)
            XCTAssertEqual(name.result.failureDescription, "contains '!' (allowed: A-Z, a-z, 0-9)")
            let and = name.result as! ValidatorResults.And
            let count = and.left as! ValidatorResults.Range<Int>
            XCTAssertEqual(count.result, .greaterThanOrEqualToMin(5))
            let character = and.right as! ValidatorResults.CharacterSet
            XCTAssertEqual(character.invalidSlice, "!")
        }
        do {
            try User.validate(query: invalidUserUrl)
        } catch let error as ValidationsError {
            XCTAssertEqual(error.failures.count, 1)
            let name = error.failures[0]
            XCTAssertEqual(name.key.stringValue, "name")
            XCTAssertEqual(name.result.isFailure, true)
            XCTAssertEqual(name.result.failureDescription, "contains '!' (allowed: A-Z, a-z, 0-9)")
            let and = name.result as! ValidatorResults.And
            let count = and.left as! ValidatorResults.Range<Int>
            XCTAssertEqual(count.result, .greaterThanOrEqualToMin(5))
            let character = and.right as! ValidatorResults.CharacterSet
            XCTAssertEqual(character.invalidSlice, "!")
        }
    }
    
    func testNotReadability() {
        assert("vapor!🤠",
               fails: .ascii && .alphanumeric,
               "contains '🤠' (allowed: ASCII) and contains '!' (allowed: A-Z, a-z, 0-9)")
        assert("vapor",
               fails: !(.ascii && .alphanumeric),
               "contains only ASCII and contains only A-Z, a-z, 0-9")
    }

    func testASCII() {
        assert("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
               passes: .ascii)
        assert("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
               fails: !.ascii,
               "contains only ASCII")
        assert("\n\r\t", passes: .ascii)
        assert("\n\r\t\u{129}", fails: .ascii, "contains 'ĩ' (allowed: ASCII)")
        assert(" !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~", passes: .ascii)
        assert("ABCDEFGHIJKLMNOPQR🤠STUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
               fails: .ascii,
               "contains '🤠' (allowed: ASCII)")
    }

    func testAlphanumeric() {
        assert("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", passes: .alphanumeric)
        assert("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", fails: .alphanumeric, "contains '+' (allowed: A-Z, a-z, 0-9)")
    }

    func testEmpty() {
        assert("", passes: .empty)
        assert("something", fails: .empty, "is not empty")
        assert([Int](), passes: .empty)
        assert([Int](), fails: !.empty, "is empty")
        assert([1, 2], fails: .empty, "is not empty")
        assert([1, 2], passes: !.empty)
    }

    func testEmail() {
        assert("tanner@vapor.codes", passes: .email)
        assert("tanner@vapor.codes", fails: !.email, "is a valid email address")
        assert("tanner@vapor.codestanner@vapor.codes", fails: .email, "is not a valid email address")
        assert("tanner@vapor.codes.", fails: .email, "is not a valid email address")
        assert("tanner@@vapor.codes", fails: .email, "is not a valid email address")
        assert("@vapor.codes", fails: .email, "is not a valid email address")
        assert("tanner@codes", fails: .email, "is not a valid email address")
        assert("asdf", fails: .email, "is not a valid email address")
        assert("asdf", passes: !.email)
    }

    func testRange() {
        assert(4, passes: .range(-5...5))
        assert(4, passes: .range(..<5))
        assert(5, fails: .range(..<5), "is greater than maximum of 4")
        assert(5, passes: .range(...10))
        assert(11, fails: .range(...10), "is greater than maximum of 10")
        assert(4, fails: !.range(-5...5), "is between -5 and 5")
        assert(5, passes: .range(-5...5))
        assert(-5, passes: .range(-5...5))
        assert(6, fails: .range(-5...5), "is greater than maximum of 5")
        assert(-6, fails: .range(-5...5), "is less than minimum of -5")
        assert(.max, passes: .range(5...))
        assert(4, fails: .range(5...), "is less than minimum of 5")
        assert(-5, passes: .range(-5..<6))
        assert(-4, passes: .range(-5..<6))
        assert(5, passes: .range(-5..<6))
        assert(-6, fails: .range(-5..<6), "is less than minimum of -5")
        assert(6, fails: .range(-5..<6), "is greater than maximum of 5")
        assert(6, passes: !.range(-5..<6))
    }

    func testCountCharacters() {
        assert("1", passes: .count(1...6))
        assert("1", fails: !.count(1...6), "is between 1 and 6 character(s)")
        assert("123", passes: .count(1...6))
        assert("123456", passes: .count(1...6))
        assert("", fails: .count(1...6), "is less than minimum of 1 character(s)")
        assert("1234567", fails: .count(1...6), "is greater than maximum of 6 character(s)")
    }

    func testCountItems() {
        assert([1], passes: .count(1...6))
        assert([1], fails: !.count(1...6), "is between 1 and 6 item(s)")
        assert([1], passes: .count(...1))
        assert([1], fails: .count(..<1), "is greater than maximum of 0 item(s)")
        assert([1, 2, 3], passes: .count(1...6))
        assert([1, 2, 3, 4, 5, 6], passes: .count(1...6))
        assert([Int](), fails: .count(1...6), "is less than minimum of 1 item(s)")
        assert([1, 2, 3, 4, 5, 6, 7], fails: .count(1...6), "is greater than maximum of 6 item(s)")
    }

    func testURL() {
        assert("https://www.somedomain.com/somepath.png", passes: .url)
        assert("https://www.somedomain.com/somepath.png", fails: !.url, "is a valid URL")
        assert("https://www.somedomain.com/", passes: .url)
        assert("file:///Users/vapor/rocks/somePath.png", passes: .url)
        assert("www.somedomain.com/", fails: .url, "is an invalid URL")
        assert("bananas", fails: .url, "is an invalid URL")
        assert("bananas", passes: !.url)
    }
    
    func testValid() {
        assert("some random string", passes: .valid)
        assert(true, passes: .valid)
        assert("123", passes: .valid)
        assert([1, 2, 3], passes: .valid)
        assert(Date.init(), passes: .valid)
        assert("some random string", fails: !.valid, "is valid")
        assert(true, fails: !.valid, "is valid")
        assert("123", fails: !.valid, "is valid")
    }

    func testPreexistingValidatorResultIsIncluded() throws {
        struct CustomValidatorResult: ValidatorResult {
            var isFailure: Bool {
                true
            }
            var successDescription: String? {
                nil
            }
            var failureDescription: String? {
                "custom description"
            }
        }
        var validations = Validations()
        validations.add("key", result: CustomValidatorResult())
        let error = try validations.validate(json: "{}").error
        XCTAssertEqual(error?.description, "key custom description")
    }

    func testDoubleNegationIsAvoided() throws {
        var validations = Validations()
        validations.add("key", as: String.self, is: !.empty)
        let error = try validations.validate(json: #"{"key": ""}"#).error
        XCTAssertEqual(error?.description, "key is empty")
    }

    func testCaseOf() {
        enum StringEnumType: String, CaseIterable {
            case case1, case2, case3 = "CASE3"
        }
        assert("case1", passes: .case(of: StringEnumType.self))
        assert("case2", passes: .case(of: StringEnumType.self))
        assert("case1", fails: !.case(of: StringEnumType.self), "is case1, case2, or CASE3")
        assert("case3", fails: .case(of: StringEnumType.self), "is not case1, case2, or CASE3")

        enum IntEnumType: Int, CaseIterable {
            case case1 = 1, case2 = 2
        }
        assert(1, passes: .case(of: IntEnumType.self))
        assert(2, passes: .case(of: IntEnumType.self))
        assert(1, fails: !.case(of: IntEnumType.self), "is 1 or 2")
        assert(3, fails: .case(of: IntEnumType.self), "is not 1 or 2")

        enum SingleCaseEnum: String, CaseIterable {
            case case1 = "CASE1"
        }
        assert("CASE1", passes: .case(of: SingleCaseEnum.self))
        assert("CASE1", fails: !.case(of: SingleCaseEnum.self), "is CASE1")
        assert("CASE2", fails: .case(of: SingleCaseEnum.self), "is not CASE1")
    }

    func testCustomResponseMiddleware() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        // Converts validation errors to a custom response.
        final class ValidationErrorMiddleware: Middleware {
            // Defines the format of the custom error response.
            struct ErrorResponse: Content {
                var errors: [String]
            }

            func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
                next.respond(to: request).flatMapErrorThrowing { error in
                    // Check to see if this is a validation error. 
                    if let validationError = error as? ValidationsError {
                        // Convert each failed ValidatorResults to a String
                        // for the sake of this example.
                        let errorMessages = validationError.failures.map { failure -> String in 
                            let reason: String
                            // The failure result will be one of the ValidatorResults subtypes.
                            //
                            // Each validator extends ValidatorResults with a nested type.
                            // For example, the .email validator's result type is:
                            //
                            //      struct ValidatorResults.Email {
                            //          let isValidEmail: Bool
                            //      }
                            //
                            // You can handle as many or as few of these types as you want.
                            // Vapor and third party packages may add additional types.
                            // This switch is only handling two cases as an example.
                            //
                            // If you want to localize your validation failures, this is a
                            // good place to do it.
                            switch failure.result {
                            case is ValidatorResults.Missing:
                                reason = "is required"
                            case let error as ValidatorResults.TypeMismatch:
                                reason = "is not \(error.type)"
                            default:
                                reason = "unknown"
                            }
                            return "\(failure.key) \(reason)"
                        }
                        // Create the 400 response and encode the custom error content.
                        let response = Response(status: .badRequest)
                        try response.content.encode(ErrorResponse(errors: errorMessages))
                        return response
                    } else {
                        // This isn't a validation error, rethrow it and let
                        // ErrorMiddleware handle it.
                        throw error
                    }
                }
            }
        }
        app.middleware.use(ValidationErrorMiddleware())

        app.post("users") { req -> HTTPStatus in 
            try User.validate(content: req)
            return .ok
        }

        // Test that the custom validation error middleware is working.
        try app.test(.POST, "users", beforeRequest: { req in
            try req.content.encode([
                "name": "Vapor",
                "age": "asdf"
            ])
        }, afterResponse: { res in 
            XCTAssertEqual(res.status, .badRequest)
            let content = try res.content.decode(ValidationErrorMiddleware.ErrorResponse.self)
            XCTAssertEqual(content.errors.count, 11)
        })
    }

    override class func setUp() {
        XCTAssert(isLoggingConfigured)
    }
}

private func assert<T>(
    _ data: T,
    fails validator: Validator<T>,
    _ description: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    let file = (file)
    let result = validator.validate(data)
    XCTAssert(result.isFailure, result.successDescription ?? "n/a", file: file, line: line)
    XCTAssertEqual(description, result.failureDescription ?? "n/a", file: file, line: line)
}

private func assert<T>(
    _ data: T,
    passes validator: Validator<T>,
    file: StaticString = #file,
    line: UInt = #line
) {
    let file = (file)
    let result = validator.validate(data)
    XCTAssert(!result.isFailure, result.failureDescription ?? "n/a", file: file, line: line)
}

private final class User: Validatable, Codable {
    enum Gender: String, CaseIterable, Codable {
        case male, female, other
    }
    
    var id: Int?
    var name: String
    var age: Int
    var gender: Gender
    var email: String?
    var pet: Pet
    var favoritePet: Pet?
    var luckyNumber: Int?
    var profilePictureURL: String?
    var preferredColors: [String]
    var isAdmin: Bool
    
    struct Pet: Codable {
        var name: String
        var age: Int
        init(name: String, age: Int) {
            self.name = name
            self.age = age
        }
    }

    init(id: Int? = nil, name: String, age: Int, gender: Gender, pet: Pet, preferredColors: [String] = [], isAdmin: Bool) {
        self.id = id
        self.name = name
        self.age = age
        self.gender = gender
        self.pet = pet
        self.preferredColors = preferredColors
        self.isAdmin = isAdmin
    }

    static func validations(_ v: inout Validations) {
        // validate name is at least 5 characters and alphanumeric
        v.add("name", as: String.self, is: .count(5...) && .alphanumeric)
        // validate age is 18 or older
        v.add("age", as: Int.self, is: .range(18...))
        // validate gender is of type Gender
        v.add("gender", as: String.self, is: .case(of: Gender.self))
        // validate the email is valid and is not nil
        v.add("email", as: String?.self, is: !.nil && .email)
        v.add("email", as: String?.self, is: .email && !.nil) // test other way
        // validate the email is valid or is nil
        v.add("email", as: String?.self, is: .nil || .email)
        v.add("email", as: String?.self, is: .email || .nil) // test other way
        // validate that the lucky number is nil or is 5 or 7
        v.add("luckyNumber", as: Int?.self, is: .nil || .in(5, 7))
        // validate that the profile picture is nil or a valid URL
        v.add("profilePictureURL", as: String?.self, is: .url || .nil)
        v.add("preferredColors", as: [String].self, is: !.empty)
        // pet validations
        v.add("pet") { pet in
            pet.add("name", as: String.self,
                    is: .count(5...) && .characterSet(.alphanumerics + .whitespaces))
            pet.add("age", as: Int.self, is: .range(3...))
        }
        // optional favorite pet validations
        v.add("favoritePet", required: false) { pet in
            pet.add("name", as: String.self,
                    is: .count(5...) && .characterSet(.alphanumerics + .whitespaces))
            pet.add("age", as: Int.self, is: .range(3...))
        }
        v.add("isAdmin", as: Bool.self)
    }
}
