import XCTest
import Foundation
@testable import Vapor

class FooErrorTests: XCTestCase {
    static let allTests = [
        ("testPrintable", testPrintable),
        ("testOmitEmptyFields", testOmitEmptyFields),
        ("testReadableName", testReadableName),
        ("testIdentifier", testIdentifier),
        ("testCausesAndSuggestions", testCausesAndSuggestions),
    ]

    let error: FooError = .noFoo

    func testPrintable() throws {
        print(error.debugDescription)
        XCTAssertEqual(
            error.debugDescription,
            expectedPrintable,
            "`error`'s `debugDescription` should equal `expectedPrintable`."
        )
    }

    func testOmitEmptyFields() {
        XCTAssertTrue(
            error.stackOverflowQuestions.isEmpty,
            "There should be no `stackOverflowQuestions`."
        )

        XCTAssertFalse(
            error.debugDescription.contains("Stack Overflow"),
            "The `debugDescription` should contain no mention of Stack Overflow."
        )
    }

    func testReadableName() {
        XCTAssertEqual(
            FooError.readableName,
            "Foo Error",
            "`readableName` should be a well-formatted `String`."
        )
    }

    func testIdentifier() {
        XCTAssertEqual(
            error.identifier,
            "noFoo",
            "`instanceIdentifier` should equal `'noFoo'`."
        )
    }

    func testCausesAndSuggestions() {
        XCTAssertEqual(
            error.possibleCauses,
            expectedPossibleCauses,
            "`possibleCauses` should match `expectedPossibleCauses`"
        )

        XCTAssertEqual(error.suggestedFixes,
                       expectedSuggestedFixes,
                       "`suggestedFixes` should match `expectedSuggestFixes`")

        XCTAssertEqual(error.documentationLinks,
                       expectedDocumentedLinks,
                       "`documentationLinks` should match `expectedDocumentedLinks`")
    }
}

// MARK: - Fixtures
private let expectedPrintable: String = {
    var expectation = "⚠️ Foo Error: You do not have a `foo`.\n"
    expectation += "- id: FooError.noFoo\n\n"

    expectation += "Here are some possible causes: \n"
    expectation += "- You did not set the flongwaffle.\n"
    expectation += "- The session ended before a `Foo` could be made.\n"
    expectation += "- The universe conspires against us all.\n"
    expectation += "- Computers are hard.\n\n"

    expectation += "These suggestions could address the issue: \n"
    expectation += "- You really want to use a `Bar` here.\n"
    expectation += "- Take up the guitar and move to the beach.\n\n"

    expectation += "Vapor's documentation talks about this: \n"
    expectation += "- http://documentation.com/Foo\n"
    expectation += "- http://documentation.com/foo/noFoo\n"
    return expectation
}()

private let expectedPossibleCauses = [
    "You did not set the flongwaffle.",
    "The session ended before a `Foo` could be made.",
    "The universe conspires against us all.",
    "Computers are hard."
]

private let expectedSuggestedFixes = [
    "You really want to use a `Bar` here.",
    "Take up the guitar and move to the beach."
]

private let expectedDocumentedLinks = [
    "http://documentation.com/Foo",
    "http://documentation.com/foo/noFoo"
]
