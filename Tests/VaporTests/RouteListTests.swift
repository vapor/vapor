
import XCTest
import HTTP
@testable import Vapor

class RouteListTests: XCTestCase {
    static let allTests = [
        ("testMakeTable", testMakeTable),
        ("testLogTable", testLogTable),
    ]

    func testMakeTable() throws {
        let drop = try Droplet()
        let list = RouteList(drop)
        let table = list.makeTable(routes: ["* GET foo", "* PATCH not-foo", "* PUT foo/bar/:id"])
        let expectation = [["*", "GET", "/foo"], ["", "PUT", "/foo/bar/:id"], ["", "PATCH", "/not-foo"]]
        XCTAssertEqual(table.description, expectation.description)
    }

    func testLogTable() throws {
        // Setup drop routes
        let drop = try Droplet(arguments: ["vapor", "routes"])
        drop.get("foo") { _ in return "" }
        drop.put("foo/bar/:id") { _ in return "" }

        // Test Console
        let console = TestConsoleDriver()
        drop.console = console

        // Run command
        try drop.runCommands()

        // Verify
        let logged = console.buffer.makeString()
        var expectation = ""
        expectation += "+------+--------+--------------+\n"
        expectation += "| Host | Method | Path         | \n"
        expectation += "+------+--------+--------------+\n"
        expectation += "| *    | GET    | /foo         | \n"
        expectation += "|      | PUT    | /foo/bar/:id | \n"
        expectation += "+------+--------+--------------+\n"
        XCTAssertEqual(logged, expectation)
    }
}
