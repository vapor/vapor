import Vapor
import NIOCore
import Testing
import Foundation

@Suite("Validation Tests")
struct ValidationTests {
    @Test("Test Validate")
    func testValidate() throws {
        struct User: Validatable, Codable {
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
                v.add(
                    "email",
                    as: String?.self,
                    is: .custom(
                        "Validates whether email domain is 'tanner.xyz'."
                    ) { email in
                        if let email {
                            let parts = email.split(separator: "@")
                            return parts[parts.count - 1] == "tanner.xyz"
                        }
                        return true
                    }
                )
                // validate that the lucky number is nil or is 5 or 7
                v.add("luckyNumber", as: Int?.self, is: .nil || .in(5, 7))
                // validate that the profile picture is nil or a valid URL
                v.add("profilePictureURL", as: String?.self, is: .url || .nil)
                v.add("preferredColors", as: [String].self, is: !.empty)
                // pet validations
                v.add("pet") { pet in
                    pet.add("name", as: String.self, is: .count(5...) && .characterSet(.alphanumerics + .whitespaces))
                    pet.add("age", as: Int.self, is: .range(3...))
                }
                // optional favorite pet validations
                v.add("favoritePet", required: false) { pet in
                    pet.add(
                        "name", as: String.self,
                        is: .count(5...) && .characterSet(.alphanumerics + .whitespaces)
                    )
                    pet.add("age", as: Int.self, is: .range(3...))
                }
                v.add("isAdmin", as: Bool.self)
            }
        }

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
            "hobbies": [
                {
                    "title": "Football"
                },
                {
                    "title": "Computer science"
                }
            ],
            "favoritePet": null,
            "isAdmin": true
        }
        """
        #expect(throws: Never.self) {
            try User.validate(json: valid)
        }

        let validURL: URI = "https://tanner.xyz/user?name=Tanner&age=24&gender=male&email=me@tanner.xyz&luckyNumber=5&profilePictureURL=https://foo.jpg&preferredColors=[blue]&pet[name]=Zizek&pet[age]=3&isAdmin=true"
        #expect(throws: Never.self) {
            try User.validate(query: validURL)
        }

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
            "isAdmin": true,
            "hobbies": [
                {
                    "title": "Football"
                },
                {
                    "title": "Computer science"
                }
            ]
        }
        """

        let jsonError = #expect(throws: ValidationsError.self) {
            try User.validate(json: invalidUser)
        }
        #expect(jsonError?.description == "name contains '!' (allowed: A-Z, a-z, 0-9)")

        let invalidUserURL: URI = "https://tanner.xyz/user?name=Tan!ner&age=24&gender=other&email=me@tanner.xyz&luckyNumber=5&profilePictureURL=https://foo.jpg&preferredColors=[blue]&pet[name]=Zizek&pet[age]=3&isAdmin=true"
        let urlError = #expect(throws: ValidationsError.self) {
            try User.validate(query: invalidUserURL)
        }
        #expect(urlError?.description == "name contains '!' (allowed: A-Z, a-z, 0-9)")
    }

    @Test("Test Validate International Email")
    func testValidateInternationalEmail() throws {
        struct Email: Validatable, Codable {
            var email: String?

            init(email: String) {
                self.email = email
            }

            static func validations(_ v: inout Validations) {
                // validate the international email is valid and is not nil
                v.add("email", as: String?.self, is: !.nil && .internationalEmail)
                v.add("email", as: String?.self, is: .internationalEmail && !.nil) // test other way
            }
        }

        let valid = """
        {
            "email": "ß@tanner.xyz"
        }
        """
        #expect(throws: Never.self) {
            try Email.validate(json: valid)
        }

        // N.B.: These two checks previously asserted against a URI containing the unencoded `ß` character.
        // Such a URI is semantically incorrect (per RFC 3986) and should have been considered a bug.
        let validURL: URI = "https://tanner.xyz/email?email=%C3%9F@tanner.xyz" // ß
        #expect(throws: Never.self) {
            try Email.validate(query: validURL)
        }

        let validURL2: URI = "https://tanner.xyz/email?email=me@%C3%9Fanner.xyz"
        #expect(throws: Never.self) {
            try Email.validate(query: validURL2)
        }

        let invalidUser = """
        {
            "email": "me@tanner@.xyz",
        }
        """
        let jsonError = #expect(throws: ValidationsError.self) {
            try Email.validate(json: invalidUser)
        }
        #expect(jsonError?.description == "email is not a valid email address, email is not a valid email address")
        
        let invalidUserURL: URI = "https://tanner.xyz/email?email=me@tanner@.xyz"
        let urlError = #expect(throws: ValidationsError.self) {
            try Email.validate(query: invalidUserURL)
        }
        #expect(urlError?.description == "email is not a valid email address, email is not a valid email address")
    }

    @Test("Test Validate Nested")
    func testValidateNested() throws {
        struct User: Validatable, Codable {
            var name: String
            var age: Int
            var pet: Pet

            struct Pet: Codable {
                var name: String
                var age: Int
                init(name: String, age: Int) {
                    self.name = name
                    self.age = age
                }
            }

            static func validations(_ v: inout Validations) {
                // validate name is at least 5 characters and alphanumeric
                v.add("name", as: String.self, is: .count(5...) && .alphanumeric)
                // validate age is 18 or older
                v.add("age", as: Int.self, is: .range(18...))
                // pet validations
                v.add("pet") { pet in
                    pet.add("name", as: String.self, is: .count(5...) && .characterSet(.alphanumerics + .whitespaces))
                    pet.add("age", as: Int.self, is: .range(3...))
                }
            }
        }

        let invalidPetJSON = """
        {
            "name": "Tanner",
            "age": 24,
            "pet": {
                "name": "Zi!zek",
                "age": 3
            }
        }
        """
        let jsonError = #expect(throws: ValidationsError.self) {
            try User.validate(json: invalidPetJSON)
        }
        #expect(jsonError?.description == "pet name contains '!' (allowed: whitespace, A-Z, a-z, 0-9)")

        let invalidPetURL: URI = "https://tanner.xyz/user?name=Tanner&age=24&pet[name]=Zi!ek&pet[age]=3"
        let urlError = #expect(throws: ValidationsError.self) {
            try User.validate(query: invalidPetURL)
        }
        #expect(urlError?.description == "pet name contains '!' (allowed: whitespace, A-Z, a-z, 0-9)")
    }

    @Test("Test Validate Nested Each")
    func testValidateNestedEach() throws {
        struct User: Validatable {
            var name: String
            var age: Int
            var hobbies: [Hobby]
            var allergies: [Allergy]?

            struct Hobby: Codable {
                var title: String
                init(title: String) {
                    self.title = title
                }
            }
            
            struct Allergy: Codable {
                var title: String
                init(title: String) {
                    self.title = title
                }
            }

            static func validations(_ v: inout Validations) {
                v.add("name", as: String.self, is: .count(5...) && .alphanumeric)
                v.add("age", as: Int.self, is: .range(18...))
                v.add(each: "hobbies") { i, hobby in
                    hobby.add("title", as: String.self, is: .count(5...) && .characterSet(.alphanumerics + .whitespaces))
                }
                v.add("hobbies", as: [Hobby].self, is: !.empty)
                v.add(each: "allergies", required: false) { i, allergy in
                    allergy.add("title", as: String.self, is: .characterSet(.letters))
                }
            }
        }

        let invalidNestedArray = """
        {
            "name": "Tanner",
            "age": 24,
            "hobbies": [
                {
                    "title": "Football€"
                },
                {
                    "title": "Co"
                }
            ]
        }
        """
        let jsonError = #expect(throws: ValidationsError.self) {
            try User.validate(json: invalidNestedArray)
        }
        #expect(jsonError?.description == "hobbies at index 0 title contains '€' (allowed: whitespace, A-Z, a-z, 0-9) and at index 1 title is less than minimum of 5 character(s)")
        
        let invalidNestedArray2 = """
        {
            "name": "Tanner",
            "age": 24,
            "allergies": [
                {
                    "title": "Peanuts"
                }
            ]
        }
        """
        let jsonError2 = #expect(throws: ValidationsError.self) {
            try User.validate(json: invalidNestedArray2)
        }
        #expect(jsonError2?.description == "hobbies is required, hobbies is required")
        
        let invalidNestedArray3 = """
        {
            "name": "Tanner",
            "age": 24,
            "hobbies": [
                {
                    "title": "Football"
                }
            ],
            "allergies": [
                {
                    "title": "Peanuts€"
                }
            ]
        }
        """
        let jsonError3 = #expect(throws: ValidationsError.self) {
            try User.validate(json: invalidNestedArray3)
        }
        #expect(jsonError3?.description == "allergies at index 0 title contains '€' (allowed: A-Z, a-z)")
        
        let validNestedArray = """
        {
            "name": "Tanner",
            "age": 24,
            "hobbies": [
                {
                    "title": "Football"
                }
            ],
        }
        """
        #expect(throws: Never.self) {
            try User.validate(json: validNestedArray)
        }
    }

    @Test("Test Validate Nested Each Index")
    func testValidateNestedEachIndex() throws {
        struct User: Validatable {
            var name: String
            var age: Int
            var hobbies: [Hobby]

            struct Hobby: Codable {
                var title: String
                init(title: String) {
                    self.title = title
                }
            }

            static func validations(_ v: inout Validations) {
                v.add("name", as: String.self, is: .count(5...) && .alphanumeric)
                v.add("age", as: Int.self, is: .range(18...))
                v.add(each: "hobbies") { i, hobby in
                    // don't validate first item
                    if i != 0 {
                        hobby.add("title", as: String.self, is: .characterSet(.alphanumerics + .whitespaces))
                    }
                }
                v.add("hobbies", as: [Hobby].self, is: !.empty)
            }
        }

        #expect(throws: Never.self) {
            try User.validate(json: """
        {
            "name": "Tanner",
            "age": 24,
            "hobbies": [
                {
                    "title": "€"
                },
                {
                    "title": "hello"
                }
            ]
        }
        """)
        }

        let validationError = #expect(throws: ValidationsError.self) {
            try User.validate(json: """
        {
            "name": "Tanner",
            "age": 24,
            "hobbies": [
                {
                    "title": "hello"
                },
                {
                    "title": "€"
                }
            ]
        }
        """)
        }
        #expect(validationError?.description == "hobbies at index 1 title contains '€' (allowed: whitespace, A-Z, a-z, 0-9)")
    }

    @Test("Test Catch Error")
    func testCatchError() throws {
        struct User: Validatable, Codable {
            var name: String
            var age: Int
            static func validations(_ v: inout Validations) {
                v.add("name", as: String.self, is: .count(5...) && .alphanumeric)
                v.add("age", as: Int.self, is: .range(18...))
            }
        }

        let invalidUser = """
        {
            "name": "Tan!ner",
            "age": 24
        }
        """
        do {
            try User.validate(json: invalidUser)
        } catch let error as ValidationsError {
            #expect(error.failures.count == 1)
            let name = error.failures[0]
            #expect(name.key.stringValue == "name")
            #expect(name.result.isFailure == true)
            #expect(name.result.failureDescription == "contains '!' (allowed: A-Z, a-z, 0-9)")
            let and = name.result as! ValidatorResults.And
            let count = and.left as! ValidatorResults.Range<Int>
            #expect(count.result == .greaterThanOrEqualToMin(5))
            let character = and.right as! ValidatorResults.CharacterSet
            #expect(character.invalidSlice == "!")
        }
    }

    @Test("Test Not Readability")
    func testNotReadability() {
        expect("vapor!🤠", fails: .ascii && .alphanumeric, "contains '🤠' (allowed: ASCII) and contains '!' (allowed: A-Z, a-z, 0-9)")
        expect("vapor", fails: !(.ascii && .alphanumeric), "contains only ASCII and contains only A-Z, a-z, 0-9")
    }

    @Test("Test ASCII")
    func testASCII() {
        expect("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", passes: .ascii)
        expect("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", fails: !.ascii, "contains only ASCII")
        expect("\n\r\t", passes: .ascii)
        expect("\n\r\t\u{129}", fails: .ascii, "contains 'ĩ' (allowed: ASCII)")
        expect(" !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~", passes: .ascii)
        expect("ABCDEFGHIJKLMNOPQR🤠STUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", fails: .ascii, "contains '🤠' (allowed: ASCII)")
    }

    @Test("Test Collection ASCII")
    func testCollectionASCII() {
        expect(["ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"], passes: .ascii)
        expect(["ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"], fails: !.ascii, "contains only ASCII")
        expect(["\n\r\t"], passes: .ascii)
        expect(["\n\r\t", "\u{129}"], fails: .ascii, "string at index 1 contains 'ĩ' (allowed: ASCII)")
        expect([" !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"], passes: .ascii)
        expect(["ABCDEFGHIJKLMNOPQR🤠STUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"], fails: .ascii, "string at index 0 contains '🤠' (allowed: ASCII)")
    }

    @Test("Test Alphanumeric")
    func testAlphanumeric() {
        expect("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", passes: .alphanumeric)
        expect("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", fails: .alphanumeric, "contains '+' (allowed: A-Z, a-z, 0-9)")
    }

    @Test("Test Collection Alphanumeric")
    func testCollectionAlphanumeric() {
        expect(["ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"], passes: .alphanumeric)
        expect(["ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef", "ghijklmnopqrstuvwxyz0123456789+/"], fails: .alphanumeric, "string at index 1 contains '+' (allowed: A-Z, a-z, 0-9)")
    }

    @Test("Test Empty")
    func testEmpty() {
        expect("", passes: .empty)
        expect("something", fails: .empty, "is not empty")
        expect([Int](), passes: .empty)
        expect([Int](), fails: !.empty, "is empty")
        expect([1, 2], fails: .empty, "is not empty")
        expect([1, 2], passes: !.empty)
    }

    @Test("Test Email")
    func testEmail() {
        expect("tanner@vapor.codes", passes: .email)
        expect("tanner@VAPOR.codes", passes: .email)
        expect("tanner@vapor.codes", fails: !.email, "is a valid email address")
        expect("tanner@VAPOR.codes", fails: !.email, "is a valid email address")
        expect("tanner@vapor.codestanner@vapor.codes", fails: .email, "is not a valid email address")
        expect("tanner@vapor.codes.", fails: .email, "is not a valid email address")
        expect("tanner@@vapor.codes", fails: .email, "is not a valid email address")
        expect("@vapor.codes", fails: .email, "is not a valid email address")
        expect("tanner@codes", fails: .email, "is not a valid email address")
        expect("asdf", fails: .email, "is not a valid email address")
        expect("asdf", passes: !.email)
    }

    @Test("Test Email With Special Characters")
    func testEmailWithSpecialCharacters() {
        expect("ß@b.com", passes: .internationalEmail)
        expect("ß@b.com", fails: !.internationalEmail, "is a valid email address")
        expect("b@ß.com", passes: .internationalEmail)
        expect("b@ß.com", fails: !.internationalEmail, "is a valid email address")
    }

    @Test("Test Range")
    func testRange() {
        expect(4, passes: .range(-5...5))
        expect(4, passes: .range(..<5))
        expect(5, fails: .range(..<5), "is greater than maximum of 4")
        expect(5, passes: .range(...10))
        expect(11, fails: .range(...10), "is greater than maximum of 10")
        expect(4, fails: !.range(-5...5), "is between -5 and 5")
        expect(5, passes: .range(-5...5))
        expect(-5, passes: .range(-5...5))
        expect(6, fails: .range(-5...5), "is greater than maximum of 5")
        expect(-6, fails: .range(-5...5), "is less than minimum of -5")
        expect(.max, passes: .range(5...))
        expect(4, fails: .range(5...), "is less than minimum of 5")
        expect(-5, passes: .range(-5..<6))
        expect(-4, passes: .range(-5..<6))
        expect(5, passes: .range(-5..<6))
        expect(-6, fails: .range(-5..<6), "is less than minimum of -5")
        expect(6, fails: .range(-5..<6), "is greater than maximum of 5")
        expect(6, passes: !.range(-5..<6))
        expect(Float.nan, passes: !.range(-5..<6))
    }

    @Test("Test Count Characters")
    func testCountCharacters() {
        expect("1", passes: .count(1...6))
        expect("1", fails: !.count(1...6), "is between 1 and 6 character(s)")
        expect("123", passes: .count(1...6))
        expect("123456", passes: .count(1...6))
        expect("", fails: .count(1...6), "is less than minimum of 1 character(s)")
        expect("1234567", fails: .count(1...6), "is greater than maximum of 6 character(s)")
    }

    @Test("Test Count Items")
    func testCountItems() {
        expect([1], passes: .count(1...6))
        expect([1], fails: !.count(1...6), "is between 1 and 6 item(s)")
        expect([1], passes: .count(...1))
        expect([1], fails: .count(..<1), "is greater than maximum of 0 item(s)")
        expect([1, 2, 3], passes: .count(1...6))
        expect([1, 2, 3, 4, 5, 6], passes: .count(1...6))
        expect([Int](), fails: .count(1...6), "is less than minimum of 1 item(s)")
        expect([1, 2, 3, 4, 5, 6, 7], fails: .count(1...6), "is greater than maximum of 6 item(s)")
    }

    @Test("Test URL")
    func testURL() {
        expect("https://www.somedomain.com/somepath.png", passes: .url)
        expect("https://www.somedomain.com/somepath.png", fails: !.url, "is a valid URL")
        expect("https://www.somedomain.com/", passes: .url)
        expect("file:///Users/vapor/rocks/somePath.png", passes: .url)
        expect("www.somedomain.com/", fails: .url, "is an invalid URL")
        expect("bananas", fails: .url, "is an invalid URL")
        expect("bananas", passes: !.url)
    }

    @Test("Test Valid")
    func testValid() {
        expect("some random string", passes: .valid)
        expect(true, passes: .valid)
        expect("123", passes: .valid)
        expect([1, 2, 3], passes: .valid)
        expect(Date.init(), passes: .valid)
        expect("some random string", fails: !.valid, "is valid")
        expect(true, fails: !.valid, "is valid")
        expect("123", fails: !.valid, "is valid")
    }

    @Test("Test Pattern")
    func testPattern() {
        expect("this are not numbers", fails: .pattern("^[0-9]*$"), "is not a valid pattern ^[0-9]*$")
        expect("12345", passes: .pattern("^[0-9]*$"))
    }

    @Test("Test Preexisting ValidatorResult Is Included")
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
        #expect(error?.description == "key custom description")
    }

    @Test("Test Double Negation Is Avoided")
    func testDoubleNegationIsAvoided() throws {
        var validations = Validations()
        validations.add("key", as: String.self, is: !.empty)
        let error = try validations.validate(json: #"{"key": ""}"#).error
        #expect(error?.description == "key is empty")
    }

    @Test("Test Case Of")
    func testCaseOf() {
        enum StringEnumType: String, CaseIterable {
            case case1, case2, case3 = "CASE3"
        }
        expect("case1", passes: .case(of: StringEnumType.self))
        expect("case2", passes: .case(of: StringEnumType.self))
        expect("case1", fails: !.case(of: StringEnumType.self), "is case1, case2, or CASE3")
        expect("case3", fails: .case(of: StringEnumType.self), "is not case1, case2, or CASE3")

        enum IntEnumType: Int, CaseIterable {
            case case1 = 1, case2 = 2
        }
        expect(1, passes: .case(of: IntEnumType.self))
        expect(2, passes: .case(of: IntEnumType.self))
        expect(1, fails: !.case(of: IntEnumType.self), "is 1 or 2")
        expect(3, fails: .case(of: IntEnumType.self), "is not 1 or 2")

        enum SingleCaseEnum: String, CaseIterable {
            case case1 = "CASE1"
        }
        expect("CASE1", passes: .case(of: SingleCaseEnum.self))
        expect("CASE1", fails: !.case(of: SingleCaseEnum.self), "is CASE1")
        expect("CASE2", fails: .case(of: SingleCaseEnum.self), "is not CASE1")
    }

    @Test("Test Custom Response Middleware")
    func testCustomResponseMiddleware() async throws {
        // Test item
        struct User: Validatable {
            let name: String
            let age: Int

            static func validations(_ v: inout Validations) {
                // validate name is at least 5 characters and alphanumeric
                v.add("name", as: String.self, is: .count(5...) && .alphanumeric)
                // validate age is 18 or older
                v.add("age", as: Int.self, is: .range(18...))
            }
        }

        // Setup
        let app = try await Application(.testing)

        // Converts validation errors to a custom response.
        final class ValidationErrorMiddleware: Middleware {
            // Defines the format of the custom error response.
            struct ErrorResponse: Content {
                var errors: [String]
            }

            func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
                do {
                    return try await next.respond(to: request)
                } catch {
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
        try await app.testing().test(.post, "users", beforeRequest: { req async throws in
            try req.content.encode([
                "name": "Vapor",
                "age": "asdf"
            ])
        }, afterResponse: { res in 
            #expect(res.status == .badRequest)
            let content = try await res.content.decode(ValidationErrorMiddleware.ErrorResponse.self)
            #expect(content.errors.count == 1)
        })

        try await app.shutdown()
    }

    @Test("Test Validate Null When Not Required")
    func testValidateNullWhenNotRequired() throws {
        struct Site: Validatable, Codable {
            var url: String?
            var number: Int?
            var name: String?

            static func validations(_ v: inout Validations) {
                v.add("url", as: String.self, is: .url, required: false)
                v.add("number", as: Int.self, required: false)
                v.add("name", as: String.self, required: false)
            }
        }

        let valid = """
        {
            "url": null
        }
        """
        #expect(throws: Never.self) {
            try Site.validate(json: valid)
        }

        let valid2 = """
        {
        }
        """
        #expect(throws: Never.self) {
            try Site.validate(json: valid2)
        }

        let valid3 = """
        {
            "name": "Tim"
        }
        """
        #expect(throws: Never.self) {
            try Site.validate(json: valid3)
        }

        let valid4 = """
        {
            "name": null
        }
        """
        #expect(throws: Never.self) {
            try Site.validate(json: valid4)
        }

        let valid5 = """
        {
            "number": 3
        }
        """
        #expect(throws: Never.self) {
            try Site.validate(json: valid5)
        }

        let valid6 = """
        {
            "number": null
        }
        """
        #expect(throws: Never.self) {
            try Site.validate(json: valid6)
        }

        let invalid1 = """
        {
            "number": "Tim"
        }
        """

        do {
            try Site.validate(json: invalid1)
        } catch let error as ValidationsError {
            #expect(error.failures.count == 1)
            let name = error.failures[0]
            #expect(name.key.stringValue == "number")
            #expect(name.result.isFailure == true)
            #expect(name.result.failureDescription == "is not a(n) Int")
        }

        let invalid2 = """
        {
            "name": 3
        }
        """
        do {
            try Site.validate(json: invalid2)
        } catch let error as ValidationsError {
            #expect(error.failures.count == 1)
            let name = error.failures[0]
            #expect(name.key.stringValue == "name")
            #expect(name.result.isFailure == true)
            #expect(name.result.failureDescription == "is not a(n) String")
        }
    }
    
    @Test("Test Custom Validator")
    func testCustomValidator() {
        let value = "test123"
        let validationDescription = "test \'\(value)'"

        // These tests are used to make sure that the custom validator pass and fail correctly.
        expect(
            value,
            fails: !.custom(validationDescription) { x in
                return x == value
            },
            "is successfully validated for custom validation '\(validationDescription)'."
        )
        expect(
            value,
            passes: !.custom(validationDescription) { x in
                return x != value
            }
        )
        expect(
            value,
            fails: .custom(validationDescription) { x in
                return x != value
            },
            "is not successfully validated for custom validation '\(validationDescription)'."
        )
        expect(
            value,
            passes: .custom(validationDescription) { x in
                return x == value
            }
        )
    }

    @Test("Test Custom Failure Descriptions")
    func testCustomFailureDescriptions() throws {
        struct User: Validatable {
            var name: String
            var age: Int
            var hobbies: [Hobby]

            struct Hobby: Codable {
                var title: String
                init(title: String) {
                    self.title = title
                }
            }

            static func validations(_ v: inout Validations) {
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

                v.add("key", result: CustomValidatorResult(), customFailureDescription: "Something went wrong with the provided data")
                v.add("name", as: String.self, is: .count(5...) && !.alphanumeric, customFailureDescription: "The provided name is invalid")
                v.add(each: "hobbies", customFailureDescription: "A provided hobby value was not alphanumeric") { i, hobby in
                    hobby.add("title", as: String.self, is: .count(5...) && .characterSet(.alphanumerics + .whitespaces))
                }
                v.add("hobbies", customFailureDescription: "A provided hobby value was empty") { hobby in
                    hobby.add("title", as: String.self, is: !.empty)
                }
            }
        }

        let invalidNestedArray = """
        {
            "name": "Andre",
            "age": 26,
            "hobbies": [
                {
                    "title": "Running€"
                },
                {
                    "title": "Co"
                },
                {
                    "title": ""
                }
            ]
        }
        """
        let error = #expect(throws: ValidationsError.self) {
            try User.validate(json: invalidNestedArray)
        }
        #expect(error?.description == "Something went wrong with the provided data, The provided name is invalid, A provided hobby value was not alphanumeric, A provided hobby value was empty")
    }
}

private func expect<T>(
    _ data: T,
    fails validator: Validator<T>,
    _ description: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let result = validator.validate(data)
    let comment = Comment(stringLiteral: result.failureDescription ?? "n/a")
    #expect(result.isFailure, comment, sourceLocation: sourceLocation)
    #expect(description == result.failureDescription ?? "n/a", sourceLocation: sourceLocation)
}

private func expect<T>(
    _ data: T,
    passes validator: Validator<T>,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let result = validator.validate(data)
    let comment = Comment(stringLiteral: result.failureDescription ?? "n/a")
    #expect(!result.isFailure, comment, sourceLocation: sourceLocation)
}
