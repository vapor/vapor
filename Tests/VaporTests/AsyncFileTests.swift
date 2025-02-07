import XCTVapor
import XCTest
import Vapor
import NIOCore
import NIOHTTP1
import _NIOFileSystem
import Crypto

final class AsyncFileTests: XCTestCase, @unchecked Sendable {
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
    }
    
    func testStreamFile() async throws {
        app.get("file-stream") { req -> Response in
            return try await req.fileio.asyncStreamFile(at: #filePath, advancedETagComparison: true) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }

        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream") { res async in
            let test = "the quick brown fox"
            XCTAssertNotNil(res.headers.first(name: .eTag))
            XCTAssertContains(res.body.string, test)
        }
    }

    func testStreamFileConnectionClose() async throws {
        app.get("file-stream") { req -> Response in
            return try await req.fileio.asyncStreamFile(at: #filePath, advancedETagComparison: true)
        }

        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .connection, value: "close")
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res async in
            let test = "the quick brown fox"
            XCTAssertNotNil(res.headers.first(name: .eTag))
            XCTAssertContains(res.body.string, test)
        }
    }

    func testStreamFileNull() async throws {
        app.get("file-stream") { req -> Response in
            var tmpPath: String
            repeat {
                tmpPath = try await FileSystem.shared.temporaryDirectory.appending(UUID().uuidString).string
            } while try await self.fileExists(at: tmpPath)

            return try await req.fileio.asyncStreamFile(at: tmpPath, advancedETagComparison: true) { result in
                do {
                    try result.get()
                    XCTFail("File Stream should have failed")
                } catch {
                }
            }
        }

        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream") { res async in
            XCTAssertEqual(res.status, .internalServerError)
        }
    }
    
    private func fileExists(at path: String) async throws -> Bool {
        return try await FileSystem.shared.info(forFileAt: .init(path)) != nil
    }

    func testAdvancedETagHeaders() async throws {
        app.get("file-stream") { req -> Response in
            return try await req.fileio.asyncStreamFile(at: #filePath, advancedETagComparison: true) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }

        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream") { res async throws in
            let fileData = try Data(contentsOf: URL(fileURLWithPath: #filePath))
            let digest = SHA256.hash(data: fileData)
            let eTag = res.headers.first(name: "etag")
            XCTAssertEqual(eTag, digest.hex)
        }
    }

    func testSimpleETagHeaders() async throws {
        app.get("file-stream") { req -> Response in
            return try await req.fileio.asyncStreamFile(at: #filePath, advancedETagComparison: false) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }

        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream") { res in
            guard let fileInfo = try await FileSystem.shared.info(forFileAt: .init(#filePath)) else {
                XCTFail("Missing File Info")
                return
            }
            let fileETag = "\"\(Int(fileInfo.lastDataModificationTime.date.timeIntervalSince1970))-\(fileInfo.size)\""
            XCTAssertEqual(res.headers.first(name: .eTag), fileETag)
        }
    }
    
    func testStreamFileContentHeaderTail() async throws {
        app.get("file-stream") { req -> Response in
            return try await req.fileio.asyncStreamFile(at: #filePath, advancedETagComparison: true) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: 20)])
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res async in
            
            let contentRange = res.headers.first(name: "content-range")
            let contentLength = res.headers.first(name: "content-length")
            
            let lowerRange = Int((contentRange?.split(separator: "-")[0].split(separator: " ")[1])!)!
            let upperRange = Int((contentRange?.split(separator: "-")[1].split(separator: "/")[0])!)!
            
            let range = upperRange - lowerRange + 1
            let length = Int(contentLength!)!

            XCTAssertTrue(range == length)
        }
    }
    
    func testStreamFileContentHeaderStart() async throws {
        app.get("file-stream") { req -> Response in
            return try await req.fileio.asyncStreamFile(at: #filePath, advancedETagComparison: true) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }

        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.start(value: 20)])
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res async in
            
            let contentRange = res.headers.first(name: "content-range")
            let contentLength = res.headers.first(name: "content-length")
            
            let lowerRange = Int((contentRange?.split(separator: "-")[0].split(separator: " ")[1])!)!
            let upperRange = Int((contentRange?.split(separator: "-")[1].split(separator: "/")[0])!)!
            
            let range = upperRange - lowerRange + 1
            let length = Int(contentLength!)!

            XCTAssertTrue(range == length)
        }
    }
    
    func testStreamFileContentHeadersWithin() async throws {
        app.get("file-stream") { req -> Response in
            try await req.fileio.asyncStreamFile(at: #filePath, advancedETagComparison: true) { result in
                XCTAssertNoThrow(try result.get())
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.within(start: 20, end: 25)])
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res async in
            
            let contentRange = res.headers.first(name: "content-range")
            let contentLength = res.headers.first(name: "content-length")
            
            let lowerRange = Int((contentRange?.split(separator: "-")[0].split(separator: " ")[1])!)!
            let upperRange = Int((contentRange?.split(separator: "-")[1].split(separator: "/")[0])!)!
            
            let range = upperRange - lowerRange + 1
            let length = Int(contentLength!)!

            XCTAssertTrue(range == length)
        }
    }

    func testStreamFileContentHeadersOnlyFirstByte() async throws {
        app.get("file-stream") { req in
            try await req.fileio.asyncStreamFile(at: #filePath, advancedETagComparison: true) { result in
                XCTAssertNoThrow(try result.get())
            }
        }

        var headers = HTTPHeaders()
        headers.range = .init(unit: .bytes, ranges: [.within(start: 0, end: 0)])
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res async in
            XCTAssertEqual(res.status, .partialContent)

            XCTAssertEqual(res.headers.first(name: .contentLength), "1")
            let range = res.headers.first(name: .contentRange)!.split(separator: "/").first!.split(separator: " ").last!
            XCTAssertEqual(range, "0-0")

            XCTAssertEqual(res.body.readableBytes, 1)
        }
    }
    
    func testStreamFileContentHeadersWithinFail() async throws {
        app.get("file-stream") { req -> Response in
            try await req.fileio.asyncStreamFile(at: #filePath, advancedETagComparison: true) { result in
                XCTAssertNoThrow(try result.get())
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.within(start: -20, end: 25)])
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }

        headerRequest.range = .init(unit: .bytes, ranges: [.within(start: 10, end: 100000000)])
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
    }
    
    func testStreamFileContentHeadersStartFail() async throws {
        app.get("file-stream") { req -> Response in
            try await req.fileio.asyncStreamFile(at: #filePath, advancedETagComparison: true) { result in
                XCTAssertNoThrow(try result.get())
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.start(value: -20)])
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }

        headerRequest.range = .init(unit: .bytes, ranges: [.start(value: 100000000)])
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
    }
    
    func testStreamFileContentHeadersTailFail() async throws {
        app.get("file-stream") { req -> Response in
            try await req.fileio.asyncStreamFile(at: #filePath, advancedETagComparison: true) { result in
                XCTAssertNoThrow(try result.get())
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: -20)])
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }

        headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: 100000000)])
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
    }
    
    func testFileWrite() async throws {
        let data = "Hello"
        let path = "/tmp/fileio_write.txt"
        
        do {
            let request = Request(application: app, on: app.eventLoopGroup.next())
            
            try await request.fileio.writeFile(ByteBuffer(string: data), at: path)
            
            let result = try String(contentsOfFile: path)
            XCTAssertEqual(result, data)
        } catch {
            try await FileSystem.shared.removeItem(at: .init(path))
            throw error
        }
    }
    
    // https://github.com/vapor/vapor/security/advisories/GHSA-vj2m-9f5j-mpr5
    func testInvalidRangeHeaderDoesNotCrash() async throws {
        app.get("file-stream") { req -> Response in
            try await req.fileio.asyncStreamFile(at: #filePath, advancedETagComparison: true)
        }

        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .range, value: "bytes=0-9223372036854775807")
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=-1-10")
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=100-10")
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=10--100")
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=9223372036854775808-")
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=922337203-")
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=-922337203")
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=-9223372036854775808")
        try await app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testAsyncFileRead() async throws {
        let request = Request(application: app, on: app.eventLoopGroup.next())

        let path = "/" + #filePath.split(separator: "/").dropLast().joined(separator: "/") + "/Utilities/long-test-file.txt"

        let content = try String(contentsOfFile: path)

        var readContent = ""
        let file = try await request.fileio.readFile(at: path, chunkSize: 16 * 1024) // 32Kb, ~5 chunks
        for try await chunk in file {
            readContent += String(buffer: chunk)
        }

        XCTAssertEqual(readContent, content, "The content read from the file does not match the expected content.")
    }
}
