import Foundation
import XCTest
import libc

@testable import Vapor

class URIParserTests: XCTestCase {
    static var allTests: [(String, (URIParserTests) -> () throws -> Void)] {
        return [
            ("testParsing", testParsing)
        ]
    }

    func testParsing() throws {
        /*
         ******** [WARNING] *********

         A lot of these are probably bad URIs, but the test expectations ARE correct.
         Please do not alter tests that look strange without carefully 
         consulting RFC in great detail.
         */
        try makeSure(input: "//google.c@@om:80",
                     equalsScheme: "",
                     host: "@om",
                     username: "google.c",
                     pass: "",
                     port: 80,
                     path: "",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "foo://example.com:8042/over/there?name=ferret#nose",
                     equalsScheme: "foo",
                     host: "example.com",
                     username: "",
                     pass: "",
                     port: 8042,
                     path: "/over/there",
                     query: "name=ferret",
                     fragment: "nose")

        try makeSure(input: "urn:example:animal:ferret:nose",
                     equalsScheme: "urn",
                     host: "",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "example:animal:ferret:nose",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "ftp://ftp.is.co.za/rfc/rfc1808.txt",
                     equalsScheme: "ftp",
                     host: "ftp.is.co.za",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "/rfc/rfc1808.txt",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "http://www.ietf.org/rfc/rfc2396.txt",
                     equalsScheme: "http",
                     host: "www.ietf.org",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "/rfc/rfc2396.txt",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "ldap://[2001:db8::7]/c=GB?objectClass?one",
                     equalsScheme: "ldap",
                     host: "[2001:db8::7]",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "/c=GB",
                     query: "objectClass?one",
                     fragment: nil)

        try makeSure(input: "mailto:John.Doe@example.com",
                     equalsScheme: "mailto",
                     host: "",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "John.Doe@example.com",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "news:comp.infosystems.www.servers.unix",
                     equalsScheme: "news",
                     host: "",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "comp.infosystems.www.servers.unix",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "tel:+1-816-555-1212",
                     equalsScheme: "tel",
                     host: "",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "+1-816-555-1212",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "telnet://192.0.2.16:80/",
                     equalsScheme: "telnet",
                     host: "192.0.2.16",
                     username: "",
                     pass: "",
                     port: 80,
                     path: "/",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "urn:oasis:names:specification:docbook:dtd:xml:4.1.2",
                     equalsScheme: "urn",
                     host: "",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "oasis:names:specification:docbook:dtd:xml:4.1.2",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "foo://info.example.com?fred",
                     equalsScheme: "foo",
                     host: "info.example.com",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "",
                     query: "fred",
                     fragment: nil)
    }

    func testPercentEncodedInsideParsing() throws {
        // Some percent encoded characters MUST be filtered BEFORE parsing, this test
        // is designed to ensure that's true
        let period = "%2E"
        // made one lower cuz it should still parse
        try makeSure(input: "http://www\(period)google\(period.lowercased())com",
                     equalsScheme: "http",
                     host: "www.google.com",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "",
                     query: nil,
                     fragment: nil)
    }

    func testPercentEncodedOutsideParsing() throws {

        // encoded at: http://www.url-encode-decode.com/
        var encoded = ""
        encoded += "jo%3Da9cy%23%24%3B%40%7E-+%2Bd3c%40+%C2%B5%C2%A"
        encoded += "A%E2%88%86%E2%88%82%C2%A2%C2%A7%C2%B6+%C2%AA%E2"
        encoded += "%80%93o+%E2%80%A2%C2%A1de%CB%87%C3%93%C2%B4%E2%"
        encoded += "80%BA%C2%B0%CB%9B%E2%97%8A%C3%85%C3%9A+whoo%21+"
        encoded += "%26%26"

        var decoded = ""
        decoded += "jo=a9cy#$;@~- +d3c@ µª∆∂¢§¶ ª–o •¡deˇÓ´›°˛◊ÅÚ wh"
        decoded += "oo! &&"

        try makeSure(input: "http://www.google.com?\(encoded)",
                     equalsScheme: "http",
                     host: "www.google.com",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "",
                     query: decoded,
                     fragment: nil)
    }

    private func makeSure(input: String,
                          equalsScheme scheme: String,
                          host: String,
                          username: String,
                          pass: String,
                          port: Int?,
                          path: String,
                          query: String?,
                          fragment: String?) throws {
        let uri = try! URIParser.parse(uri: input.utf8.array)
        XCTAssert(uri.scheme == scheme, "\(input) -- expected scheme: \(scheme) got: \(uri.scheme)")
        XCTAssert(uri.host == host, "\(input) -- expected host: \(host) got: \(uri.host)")
        let testUsername = uri.userInfo?.username ?? ""
        let testPass = uri.userInfo?.password ?? ""
        XCTAssert(testUsername == username, "\(input) -- expected username: \(username) got: \(testUsername)")
        XCTAssert(testPass == pass, "\(input) -- expected password: \(pass), got: \(testPass)")
        XCTAssert(uri.port == port, "\(input) -- expected port: \(port) got: \(uri.port)")
        XCTAssert(uri.path == path, "\(input) -- expected path: \(path) got: \(uri.path)")
        XCTAssert(uri.query == query, "\(input) -- expected query: \(query) got: \(uri.query)")
        XCTAssert(uri.fragment == fragment, "\(input) -- expected fragment: \(fragment) got: \(fragment)")
    }
}
