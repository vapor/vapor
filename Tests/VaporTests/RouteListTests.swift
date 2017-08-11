import XCTest
import HTTP
@testable import Vapor
import Console
import Service

class RouteListTests: XCTestCase {
    static let allTests = [
        ("testMakeTable", testMakeTable),
        ("testLogTable", testLogTable),
    ]

    func testMakeTable() throws {
        let drop = try Droplet()
        let list = try RouteList(drop.make(), drop.router())
        let table = list.makeTable(routes: ["* GET foo", "* PATCH not-foo", "* PUT foo/bar/:id"])
        let expectation = [["*", "GET", "/foo"], ["", "PUT", "/foo/bar/:id"], ["", "PATCH", "/not-foo"]]
        XCTAssertEqual(table.description, expectation.description)
    }

    func testLogTable() throws {
        let console = TestConsoleDriver()
        // Setup drop routes
        var config = Config.default()
        config.arguments = ["vapor", "routes"]
        try config.set("droplet", "console", to: "test")
        
        var services = Services.default()
        services.register(console, name: "test", supports: [ConsoleProtocol.self])
        
        let drop = try Droplet(config, services)
        
        drop.get("foo") { _ in return "" }
        drop.put("foo/bar/:id") { _ in return "" }

        console.buffer = []
        
        // Run command
        try! drop.runCommands()

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
