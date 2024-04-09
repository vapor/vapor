import XCTVapor
import XCTest
import Vapor
import NIOCore
import NIOHTTP1

final class FileTests: XCTestCase {
    func testStreamFile() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #filePath) { result in
                do {
                    try result.get()
                } catch { 
                    XCTFail("File Stream should have succeeded")
                }
            }
        }

        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream") { res in
            let test = "the quick brown fox"
            XCTAssertNotNil(res.headers.first(name: .eTag))
            XCTAssertContains(res.body.string, test)
        }
    }

    func testStreamFileConnectionClose() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #filePath)
        }

        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .connection, value: "close")
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res in
            let test = "the quick brown fox"
            XCTAssertNotNil(res.headers.first(name: .eTag))
            XCTAssertContains(res.body.string, test)
        }
    }

    func testStreamFileNull() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req -> Response in
            var tmpPath: String
            repeat {
                tmpPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
            } while (FileManager.default.fileExists(atPath: tmpPath))

            return req.fileio.streamFile(at: tmpPath) { result in
                do {
                    try result.get()
                    XCTFail("File Stream should have failed")
                } catch { 
                }
            }
        }

        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream") { res in
            XCTAssertTrue(res.body.string.isEmpty)
        }
    }
    
    func testStreamFileContentHeaderTail() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #filePath) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: 20)])
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res in
            
            let contentRange = res.headers.first(name: "content-range")
            let contentLength = res.headers.first(name: "content-length")
            
            let lowerRange = Int((contentRange?.split(separator: "-")[0].split(separator: " ")[1])!)!
            let upperRange = Int((contentRange?.split(separator: "-")[1].split(separator: "/")[0])!)!
            
            let range = upperRange - lowerRange + 1
            let length = Int(contentLength!)!

            XCTAssertTrue(range == length)
        }
    }
    
    func testStreamFileContentHeaderStart() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #filePath) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.start(value: 20)])
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res in
            
            let contentRange = res.headers.first(name: "content-range")
            let contentLength = res.headers.first(name: "content-length")
            
            let lowerRange = Int((contentRange?.split(separator: "-")[0].split(separator: " ")[1])!)!
            let upperRange = Int((contentRange?.split(separator: "-")[1].split(separator: "/")[0])!)!
            
            let range = upperRange - lowerRange + 1
            let length = Int(contentLength!)!

            XCTAssertTrue(range == length)
        }
    }
    
    func testStreamFileContentHeadersWithin() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #filePath) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.within(start: 20, end: 25)])
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res in
            
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
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #filePath) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }

        var headers = HTTPHeaders()
        headers.range = .init(unit: .bytes, ranges: [.within(start: 0, end: 0)])
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res in
            XCTAssertEqual(res.status, .partialContent)

            XCTAssertEqual(res.headers.first(name: .contentLength), "1")
            let range = res.headers.first(name: .contentRange)!.split(separator: "/").first!.split(separator: " ").last!
            XCTAssertEqual(range, "0-0")

            XCTAssertEqual(res.body.readableBytes, 1)
        }
    }
    
    func testStreamFileContentHeadersWithinFail() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #filePath) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.within(start: -20, end: 25)])
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res in
            XCTAssertEqual(res.status, .badRequest)
        }

        headerRequest.range = .init(unit: .bytes, ranges: [.within(start: 10, end: 100000000)])
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }
    
    func testStreamFileContentHeadersStartFail() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #filePath) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.start(value: -20)])
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res in
            XCTAssertEqual(res.status, .badRequest)
        }

        headerRequest.range = .init(unit: .bytes, ranges: [.start(value: 100000000)])
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }
    
    func testStreamFileContentHeadersTailFail() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #filePath) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: -20)])
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res in
            XCTAssertEqual(res.status, .badRequest)
        }

        headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: 100000000)])
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headerRequest) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }
    
    func testFileWrite() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let request = Request(application: app, on: app.eventLoopGroup.next())
        
        let data = "Hello"
        let path = "/tmp/fileio_write.txt"
        
        try request.fileio.writeFile(ByteBuffer(string: data), at: path).wait()
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        let result = try String(contentsOfFile: path)
        XCTAssertEqual(result, data)
    }

    func testPercentDecodedFilePath() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
        app.middleware.use(FileMiddleware(publicDirectory: "/" + path))

        try app.test(.GET, "/Utilities/foo%20bar.html") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "<h1>Hello</h1>\n")
        }
    }

    func testPercentDecodedRelativePath() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
        app.middleware.use(FileMiddleware(publicDirectory: "/" + path))

        try app.test(.GET, "%2e%2e/VaporTests/Utilities/foo.txt") { res in
            XCTAssertEqual(res.status, .forbidden)
        }.test(.GET, "Utilities/foo.txt") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "bar\n")
        }
    }
    
    func testDefaultFileRelative() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
        app.middleware.use(FileMiddleware(publicDirectory: "/" + path, defaultFile: "index.html"))

        try app.test(.GET, "Utilities/") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "<h1>Root Default</h1>\n")
        }.test(.GET, "Utilities/SubUtilities/") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "<h1>Subdirectory Default</h1>\n")
        }
    }
    
    func testDefaultFileAbsolute() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
        app.middleware.use(FileMiddleware(publicDirectory: "/" + path, defaultFile: "/Utilities/index.html"))

        try app.test(.GET, "Utilities/") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "<h1>Root Default</h1>\n")
        }.test(.GET, "Utilities/SubUtilities/") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "<h1>Root Default</h1>\n")
        }
    }
    
    func testNoDefaultFile() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
        app.middleware.use(FileMiddleware(publicDirectory: "/" + path))

        try app.test(.GET, "Utilities/") { res in
            XCTAssertEqual(res.status, .notFound)
        }
    }
    
    func testRedirect() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
        app.middleware.use(
            FileMiddleware(
                publicDirectory: "/" + path,
                defaultFile: "index.html",
                directoryAction: .redirect
            )
        )

        try app.test(.GET, "Utilities") { res in
            XCTAssertEqual(res.status, .movedPermanently)
        }.test(.GET, "Utilities/SubUtilities") { res in
            XCTAssertEqual(res.status, .movedPermanently)
        }
    }
    
    func testRedirectWithQueryParams() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
        app.middleware.use(
            FileMiddleware(
                publicDirectory: "/" + path,
                defaultFile: "index.html",
                directoryAction: .redirect
            )
        )

        try app.test(.GET, "Utilities?vaporTest=test") { res in
            XCTAssertEqual(res.status, .movedPermanently)
            XCTAssertEqual(res.headers.first(name: .location), "/Utilities/?vaporTest=test")
        }.test(.GET, "Utilities/SubUtilities?vaporTest=test") { res in
            XCTAssertEqual(res.status, .movedPermanently)
            XCTAssertEqual( res.headers.first(name: .location), "/Utilities/SubUtilities/?vaporTest=test")
        }.test(.GET, "Utilities/SubUtilities?vaporTest=test#vapor") { res in
            XCTAssertEqual(res.status, .movedPermanently)
            XCTAssertEqual( res.headers.first(name: .location), "/Utilities/SubUtilities/?vaporTest=test#vapor")
        }
    }
    
    func testNoRedirect() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
        app.middleware.use(
            FileMiddleware(
                publicDirectory: "/" + path,
                defaultFile: "index.html",
                directoryAction: .none
            )
        )

        try app.test(.GET, "Utilities") { res in
            XCTAssertEqual(res.status, .notFound)
        }.test(.GET, "Utilities/SubUtilities") { res in
            XCTAssertEqual(res.status, .notFound)
        }
    }
    
    // https://github.com/vapor/vapor/security/advisories/GHSA-vj2m-9f5j-mpr5
    func testInvalidRangeHeaderDoesNotCrash() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #filePath)
        }

        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .range, value: "bytes=0-9223372036854775807")
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=-1-10")
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=100-10")
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=10--100")
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=9223372036854775808-")
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=922337203-")
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=-922337203")
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
        
        headers.replaceOrAdd(name: .range, value: "bytes=-9223372036854775808")
        try app.testable(method: .running(port: 0)).test(.GET, "/file-stream", headers: headers) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }
    
    func testAsyncFileWrite() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let request = Request(application: app, on: app.eventLoopGroup.next())
        
        let data = "Hello"
        let path = "/tmp/fileio_write.txt"
        
        try await request.fileio.writeFile(ByteBuffer(string: data), at: path)
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        let result = try String(contentsOfFile: path)
        XCTAssertEqual(result, data)
    }

    func testAsyncFileRead() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let request = Request(application: app, on: app.eventLoopGroup.next())

        let path = "/" + #filePath.split(separator: "/").dropLast().joined(separator: "/") + "/Utilities/foo.txt"

        let content = try String(contentsOfFile: path)

        var readContent = ""
        let file = try await request.fileio.readFile(at: path)
        for try await chunk in file {
            if let string = chunk.getString(at: 0, length: chunk.readableBytes) {
                readContent += string
            }
        }

        XCTAssertEqual(readContent, content, "The content read from the file does not match the expected content.")
    }
}
