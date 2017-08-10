import Vapor
import HTTP
import Testing
import XCTest
import JSONs


class ResponderTests: XCTestCase {
    override func setUp() {
        Testing.onFail = XCTFail
    }

    func testSee() throws {
        let drop = try! Droplet()
        drop.get("foo") { req in
            return "bar"
        }
        drop.get("json") { req in
            var json = JSON()
            try json.set("hello", to: "world")
            try json.set("nested", to: ["1", "2"])
            try json.set("foo", to: "bar")
            return json
        }

        try drop.testResponse(to: .get, at: "foo")
            .assertBody(contains: "bar")
            .assertStatus(is: .ok)
            .assertHeader(.contentType, contains: "text/plain")
            
        try drop.testResponse(to: .get, at: "json")
            .assertJSON("hello", equals: "world")
            .assertJSON("foo", contains: "ar")
            .assertJSON("foo", contains: "ba")
            .assertJSON("nested", 1, fuzzyEquals: 2)
    }

    static let allTests = [
        ("testSee", testSee)
    ]
}
