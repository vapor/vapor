import Vapor
import Logging
import Testing
import VaporTesting
import Foundation

@Suite("Error Tests")
struct ErrorTests {

    @Test("Test Debug Description of Errors")
    func testPrintable() throws {
        let expectedPrintable = """
        FooError.noFoo: You do not have a `foo`.
        Here are some possible causes:
        - You did not set the flongwaffle.
        - The session ended before a `Foo` could be made.
        - The universe conspires against us all.
        - Computers are hard.
        These suggestions could address the issue:
        - You really want to use a `Bar` here.
        - Take up the guitar and move to the beach.
        Vapor's documentation talks about this:
        - http://documentation.com/Foo
        - http://documentation.com/foo/noFoo

        """
        #expect(FooError.noFoo.debugDescription == expectedPrintable)
    }

    @Test("Test Omitting Empty Fields")
    func testOmitEmptyFields() {
        #expect(FooError.noFoo.stackOverflowQuestions.isEmpty == true)
        #expect(FooError.noFoo.debugDescription.contains("Stack Overflow") == false)
    }

    @Test("Test Readable Names")
    func testReadableName() {
        #expect(FooError.readableName == "Foo Error")
    }

    @Test("Test Error Identifier")
    func testIdentifier() {
        #expect(FooError.noFoo.identifier == "noFoo")
    }

    @Test("Test Error Causes")
    func testCausesAndSuggestions() {
        #expect(FooError.noFoo.possibleCauses == [
            "You did not set the flongwaffle.",
            "The session ended before a `Foo` could be made.",
            "The universe conspires against us all.",
            "Computers are hard."
        ])

        #expect(FooError.noFoo.suggestedFixes == [
            "You really want to use a `Bar` here.",
            "Take up the guitar and move to the beach."
        ])

        #expect(FooError.noFoo.documentationLinks == [
            "http://documentation.com/Foo",
            "http://documentation.com/foo/noFoo"
        ])
    }

    @Test("Test Minimum Conformance")
    func testMinimumConformance() {
        let minimum = MinimumError.alpha
        let description = minimum.debugDescription
        let expectation = """
        MinimumError.alpha: Not enabled
        
        """
        #expect(description == expectation)
    }

    @Test("Test Abort Error")
    func testAbortError() async throws {
        try await withApp { app in
            app.get("foo") { req -> String in
                throw Abort(.internalServerError, reason: "Foo")
            }

            app.post("foo") { req -> Foo in
                try await req.content.decode(Foo.self)
            }

            struct AbortResponse: Content {
                var reason: String
            }

            try await app.testing().test(.get, "foo") { res in
                #expect(res.status == .internalServerError)
                let abort = try await res.content.decode(AbortResponse.self)
                #expect(abort.reason == "Foo")
            }.test(.post, "foo", beforeRequest: { req in
                try req.content.encode(Foo(bar: 42))
            }, afterResponse: { res in
                #expect(res.status == .internalServerError)
                let abort = try await res.content.decode(AbortResponse.self)
                #expect(abort.reason == "After decode")
            })
        }
    }

    @Test("Test Error Middleware Uses Content Configuration")
    func testErrorMiddlewareUsesContentConfiguration() async throws {
        var contentConfiguration = ContentConfiguration.default()
        contentConfiguration.use(encoder: URLEncodedFormEncoder(), for: .json)
        let app = try await Application(.testing, services: .init(contentConfiguration: contentConfiguration))
        app.get("foo") { req -> String in
            throw Abort(.internalServerError, reason: "Foo")
        }

        try await app.testing().test(.get, "foo") { res in
            #expect(res.status == HTTPStatus.internalServerError)
            let option1 = "error=true&reason=Foo"
            let option2 = "reason=Foo&error=true"
            guard res.body.string == option1 || res.body.string == option2 else {
                Issue.record("Response does not match")
                return
            }
        }

        try await app.shutdown()
    }
}

private struct Foo: Content {
    let bar: Int

    func afterDecode() throws {
        throw Abort(.internalServerError, reason: "After decode")
    }
}

private enum MinimumError: String, DebuggableError {
    case alpha, bravo, charlie

    /// The reason for the error.
    /// Typical implementations will switch over `self`
    /// and return a friendly `String` describing the error.
    /// - note: It is most convenient that `self` be a `Swift.Error`.
    ///
    /// Here is one way to do this:
    ///
    ///     switch self {
    ///     case someError:
    ///        return "A `String` describing what went wrong including the actual error: `Error.someError`."
    ///     // other cases
    ///     }
    var reason: String {
        switch self {
            case .alpha:
                return "Not enabled"
            case .bravo:
                return "Enabled, but I'm not configured"
            case .charlie:
                return "Broken beyond repair"
        }
    }

    var identifier: String {
        return rawValue
    }

    /// A `String` array describing the possible causes of the error.
    /// - note: Defaults to an empty array.
    /// Provide a custom implementation to give more context.
    var possibleCauses: [String] {
        return []
    }

    var suggestedFixes: [String] {
        return []
    }
}


private enum FooError: String, DebuggableError {
    case noFoo

    static var readableName: String {
        return "Foo Error"
    }

    var identifier: String {
        return rawValue
    }

    var reason: String {
        switch self {
        case .noFoo:
            return "You do not have a `foo`."
        }
    }

    var possibleCauses: [String] {
        switch self {
        case .noFoo:
            return [
                "You did not set the flongwaffle.",
                "The session ended before a `Foo` could be made.",
                "The universe conspires against us all.",
                "Computers are hard."
            ]
        }
    }

    var suggestedFixes: [String] {
        switch self {
        case .noFoo:
            return [
                "You really want to use a `Bar` here.",
                "Take up the guitar and move to the beach."
            ]
        }
    }

    var documentationLinks: [String] {
        switch self {
        case .noFoo:
            return [
                "http://documentation.com/Foo",
                "http://documentation.com/foo/noFoo"
            ]
        }
    }
}
