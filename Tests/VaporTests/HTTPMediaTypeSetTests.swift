import NIOHTTP1
import XCTest

@testable import Vapor

final class HTTPMediaTypeSetTests: XCTestCase {
    func testEmptySet() {
        let mediaSet = HTTPMediaTypeSet.none

        XCTAssertFalse(mediaSet.contains(.any))
        XCTAssertFalse(mediaSet.contains(.html))
        XCTAssertFalse(mediaSet.contains(.multipart))

        XCTAssertEqual(mediaSet.mediaTypeLookup, [:])
        XCTAssertTrue(mediaSet.allowsNone)
        XCTAssertFalse(mediaSet.allowsAny)
    }

    func testAllSet() {
        let mediaSet = HTTPMediaTypeSet.all

        XCTAssertTrue(mediaSet.contains(.any))
        XCTAssertTrue(mediaSet.contains(.html))
        XCTAssertTrue(mediaSet.contains(.multipart))

        XCTAssertEqual(mediaSet.mediaTypeLookup, ["*": ["*": [.any]]])
        XCTAssertFalse(mediaSet.allowsNone)
        XCTAssertTrue(mediaSet.allowsAny)
    }

    func testInitialization() {
        var mediaSet: HTTPMediaTypeSet

        mediaSet = []
        XCTAssertEqual(mediaSet.mediaTypeLookup, [:])

        mediaSet = [.any]
        XCTAssertEqual(mediaSet.mediaTypeLookup, ["*": ["*": [.any]]])

        mediaSet = [.html]
        XCTAssertEqual(mediaSet.mediaTypeLookup, ["text": ["html": [.html]]])

        mediaSet = [.html, .css]
        XCTAssertEqual(mediaSet.mediaTypeLookup, ["text": ["css": [.css], "html": [.html]]])

        mediaSet = [.html, .png]
        XCTAssertEqual(mediaSet.mediaTypeLookup, ["text": ["html": [.html]], "image": ["png": [.png]]])
    }

    func testContains() {
        let mediaSet: HTTPMediaTypeSet = [
            HTTPMediaType(type: "a", subType: "1"),
            HTTPMediaType(type: "a", subType: "2"),
            HTTPMediaType(type: "a", subType: "-", parameters: ["A": "a"]),
            HTTPMediaType(type: "b", subType: "3"),
            HTTPMediaType(type: "b", subType: "4"),
            HTTPMediaType(type: "b", subType: "-", parameters: ["A": "a"]),
            HTTPMediaType(type: "b", subType: "-", parameters: ["B": "b"]),
        ]

        XCTAssertTrue(mediaSet.contains(HTTPMediaType(type: "a", subType: "1")))
        XCTAssertTrue(mediaSet.contains(HTTPMediaType(type: "a", subType: "2")))
        XCTAssertTrue(mediaSet.contains(HTTPMediaType(type: "a", subType: "-", parameters: ["A": "a"])))
        XCTAssertTrue(mediaSet.contains(HTTPMediaType(type: "b", subType: "3")))
        XCTAssertTrue(mediaSet.contains(HTTPMediaType(type: "b", subType: "4")))
        XCTAssertTrue(mediaSet.contains(HTTPMediaType(type: "b", subType: "-", parameters: ["A": "a"])))
        XCTAssertTrue(mediaSet.contains(HTTPMediaType(type: "b", subType: "-", parameters: ["B": "b"])))

        XCTAssertTrue(mediaSet.contains(HTTPMediaType(type: "a", subType: "2", parameters: ["A": "a"])))

        XCTAssertFalse(mediaSet.contains(HTTPMediaType(type: "a", subType: "3")))
        XCTAssertFalse(mediaSet.contains(HTTPMediaType(type: "b", subType: "1")))
        XCTAssertFalse(mediaSet.contains(HTTPMediaType(type: "c", subType: "1")))
        XCTAssertFalse(mediaSet.contains(HTTPMediaType(type: "c", subType: "5")))

        /// These are currently allowed because `HTTPMediaType` current performs equality by ignoring the parameters, which we may not want in a set like this in the future. This does not currently impact anything, but leaving this note here in case a future version of Vapor would like to change the behavior to meet these expectations.
        XCTAssertTrue(mediaSet.contains(HTTPMediaType(type: "a", subType: "-")))
        XCTAssertTrue(mediaSet.contains(HTTPMediaType(type: "a", subType: "-", parameters: ["A": "b"])))
        XCTAssertTrue(mediaSet.contains(HTTPMediaType(type: "a", subType: "-", parameters: ["B": "b"])))
    }

    func testCompressibleSample() {
        let compressible = HTTPMediaTypeSet.compressible
        XCTAssertTrue(compressible.contains(.html))
        XCTAssertTrue(compressible.contains(.jsonAPI))
        XCTAssertTrue(compressible.contains(.json))
        XCTAssertTrue(compressible.contains(.svg))
        XCTAssertTrue(compressible.contains(.formData))

        XCTAssertFalse(compressible.contains(.png))
        XCTAssertFalse(compressible.contains(.mp3))
        XCTAssertFalse(compressible.contains(.mpeg))
        XCTAssertFalse(compressible.contains(.tar))

        XCTAssertFalse(compressible.contains(.any))
    }

    func testIncompressibleSample() {
        let incompressible = HTTPMediaTypeSet.incompressible
        XCTAssertFalse(incompressible.contains(.html))
        XCTAssertFalse(incompressible.contains(.jsonAPI))
        XCTAssertFalse(incompressible.contains(.json))
        XCTAssertFalse(incompressible.contains(.svg))
        XCTAssertFalse(incompressible.contains(.formData))

        XCTAssertTrue(incompressible.contains(.png))
        XCTAssertTrue(incompressible.contains(.mp3))
        XCTAssertTrue(incompressible.contains(.mpeg))
        XCTAssertTrue(incompressible.contains(.tar))

        XCTAssertFalse(incompressible.contains(.any))
    }
}
