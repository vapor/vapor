import Foundation
import XCTest
import libc

@testable import Vapor

class URIParserTests: XCTestCase {
    static var allTests: [(String, (URIParserTests) -> () throws -> Void)] {
        return [

        ]
    }

    func test() throws {
        let test: [String] = ["foo://example.com:8042/over/there?name=ferret#nose", "urn:example:animal:ferret:nose"]
        try test.forEach { uri in
            let uriData = Data(uri)
            let parser = URIParser.init(data: uriData)
            try parser.parse()
            print("\n\n")
        }
    }

    let testCases: [String: __URIParser.URI] = [:]
    let test: [String] = [
        "//google.c@@om:80",
        "foo://example.com:8042/over/there?name=ferret#nose",
        "urn:example:animal:ferret:nose",
        "ftp://ftp.is.co.za/rfc/rfc1808.txt",
        "http://www.ietf.org/rfc/rfc2396.txt",
        "ldap://[2001:db8::7]/c=GB?objectClass?one",
        "mailto:John.Doe@example.com",
        "news:comp.infosystems.www.servers.unix",
        "tel:+1-816-555-1212",
        "telnet://192.0.2.16:80/",
        "urn:oasis:names:specification:docbook:dtd:xml:4.1.2",
        "foo://info.example.com?fred"
    ]
    private func testUriParsing
    private func makeSure(input: String, equalsScheme: String, authority: String?, path: String, query: String?, fragment: String?) {

    }
}