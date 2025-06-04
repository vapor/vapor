@testable import Vapor
import Testing
import HTTPTypes

@Suite("HTTP Media Type Set Tests")
struct HTTPMediaTypeSetTests {
    @Test("Test empty set")
    func testEmptySet() {
        let mediaSet = HTTPMediaTypeSet.none
        
        #expect(mediaSet.contains(.any) == false)
        #expect(mediaSet.contains(.html) == false)
        #expect(mediaSet.contains(.multipart) == false)

        #expect(mediaSet.mediaTypeLookup == [:])
        #expect(mediaSet.allowsNone)
        #expect(mediaSet.allowsAny == false)
    }

    @Test("Test All Set")
    func testAllSet() {
        let mediaSet = HTTPMediaTypeSet.all
        
        #expect(mediaSet.contains(.any))
        #expect(mediaSet.contains(.html))
        #expect(mediaSet.contains(.multipart))

        #expect(mediaSet.mediaTypeLookup == ["*": ["*" : [.any]]])
        #expect(mediaSet.allowsNone == false)
        #expect(mediaSet.allowsAny)
    }

    @Test("Test Initialisation")
    func testInitialization() {
        var mediaSet: HTTPMediaTypeSet
        
        mediaSet = []
        #expect(mediaSet.mediaTypeLookup == [:])

        mediaSet = [.any]
        #expect(mediaSet.mediaTypeLookup == ["*" : ["*" : [.any]]])

        mediaSet = [.html]
        #expect(mediaSet.mediaTypeLookup == ["text" : ["html" : [.html]]])

        mediaSet = [.html, .css]
        #expect(mediaSet.mediaTypeLookup == ["text" : ["css" : [.css], "html": [.html]]])

        mediaSet = [.html, .png]
        #expect(mediaSet.mediaTypeLookup == ["text" : ["html": [.html]], "image" : ["png" : [.png]]])
    }

    @Test("Test Contains")
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
        
        #expect(mediaSet.contains(HTTPMediaType(type: "a", subType: "1")))
        #expect(mediaSet.contains(HTTPMediaType(type: "a", subType: "2")))
        #expect(mediaSet.contains(HTTPMediaType(type: "a", subType: "-", parameters: ["A": "a"])))
        #expect(mediaSet.contains(HTTPMediaType(type: "b", subType: "3")))
        #expect(mediaSet.contains(HTTPMediaType(type: "b", subType: "4")))
        #expect(mediaSet.contains(HTTPMediaType(type: "b", subType: "-", parameters: ["A": "a"])))
        #expect(mediaSet.contains(HTTPMediaType(type: "b", subType: "-", parameters: ["B": "b"])))

        #expect(mediaSet.contains(HTTPMediaType(type: "a", subType: "2", parameters: ["A": "a"])))

        #expect(mediaSet.contains(HTTPMediaType(type: "a", subType: "3")) == false)
        #expect(mediaSet.contains(HTTPMediaType(type: "b", subType: "1")) == false)
        #expect(mediaSet.contains(HTTPMediaType(type: "c", subType: "1")) == false)
        #expect(mediaSet.contains(HTTPMediaType(type: "c", subType: "5")) == false)

        /// These are currently allowed because `HTTPMediaType` current performs equality by ignoring the parameters, which we may not want in a set like this in the future. This does not currently impact anything, but leaving this note here in case a future version of Vapor would like to change the behavior to meet these expectations.
        #expect(mediaSet.contains(HTTPMediaType(type: "a", subType: "-")))
        #expect(mediaSet.contains(HTTPMediaType(type: "a", subType: "-", parameters: ["A": "b"])))
        #expect(mediaSet.contains(HTTPMediaType(type: "a", subType: "-", parameters: ["B": "b"])))
    }

    @Test("Test Compressible Sample")
    func testCompressibleSample() {
        let compressible = HTTPMediaTypeSet.compressible
        #expect(compressible.contains(.html))
        #expect(compressible.contains(.jsonAPI))
        #expect(compressible.contains(.json))
        #expect(compressible.contains(.svg))
        #expect(compressible.contains(.formData))

        #expect(compressible.contains(.png) == false)
        #expect(compressible.contains(.mp3) == false)
        #expect(compressible.contains(.mpeg) == false)
        #expect(compressible.contains(.tar) == false)

        #expect(compressible.contains(.any) == false)
    }

    @Test("Test Incompressible Sample")
    func testIncompressibleSample() {
        let incompressible = HTTPMediaTypeSet.incompressible
        #expect(incompressible.contains(.html) == false)
        #expect(incompressible.contains(.jsonAPI) == false)
        #expect(incompressible.contains(.json) == false)
        #expect(incompressible.contains(.svg) == false)
        #expect(incompressible.contains(.formData) == false)

        #expect(incompressible.contains(.png) == true)
        #expect(incompressible.contains(.mp3) == true)
        #expect(incompressible.contains(.mpeg) == true)
        #expect(incompressible.contains(.tar) == true)

        #expect(incompressible.contains(.any) == false)
    }
}
