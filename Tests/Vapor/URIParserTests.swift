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
            let parser = ALT_URIParser.init(data: uriData)
            try parser.parse()
            print("\n\n")
        }
    }

    private func makeSure(input: String, equalsScheme: String, authority: String?, path: String, query: String?, fragment: String?) {

    }
}