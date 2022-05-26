import XCTVapor

final class FileTests: XCTestCase {
    func testStreamFile() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #file) { result in
                do {
                    try result.get()
                } catch { 
                    XCTFail("File Stream should have succeeded")
                }
            }
        }

        try app.testable(method: .running).test(.GET, "/file-stream") { res in
            let test = "the quick brown fox"
            XCTAssertNotNil(res.headers.first(name: .eTag))
            XCTAssertContains(res.body.string, test)
        }
    }

    func testStreamFileConnectionClose() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #file)
        }

        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .connection, value: "close")
        try app.testable(method: .running).test(.GET, "/file-stream", headers: headers) { res in
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

        try app.testable(method: .running).test(.GET, "/file-stream") { res in
            XCTAssertTrue(res.body.string.isEmpty)
        }
    }
    
//    func testStreamFileContentHeaderTail() throws {
//        let app = Application(.testing)
//        defer { app.shutdown() }
//
//        app.get("file-stream") { req in
//            return req.fileio.streamFile(at: #file) { result in
//                do {
//                    try result.get()
//                } catch {
//                    XCTFail("File Stream should have succeeded")
//                }
//            }
//        }
//        
//        var headerRequest = HTTPHeaders()
//        headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: 20)])
//        try app.testable(method: .running).test(.GET, "/file-stream", headers: headerRequest) { res in
//            
//            let contentRange = res.headers.first(name: "content-range")
//            let contentLength = res.headers.first(name: "content-length")
//            
//            let lowerRange = Int((contentRange?.split(separator: "-")[0].split(separator: " ")[1])!)!
//            let upperRange = Int((contentRange?.split(separator: "-")[1].split(separator: "/")[0])!)!
//            
//            let range = upperRange - lowerRange + 1
//            let length = Int(contentLength!)!
//            print("\(range) : \(length)")
//
//            XCTAssertTrue(range == length)
//        }
//    }
    
    func testStreamFileContentHeaderStart() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #file) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.start(value: 20)])
        try app.testable(method: .running).test(.GET, "/file-stream", headers: headerRequest) { res in
            
            let contentRange = res.headers.first(name: "content-range")
            let contentLength = res.headers.first(name: "content-length")
            
            let lowerRange = Int((contentRange?.split(separator: "-")[0].split(separator: " ")[1])!)!
            let upperRange = Int((contentRange?.split(separator: "-")[1].split(separator: "/")[0])!)!
            
            let range = upperRange - lowerRange + 1
            let length = Int(contentLength!)!
            print("\(range) : \(length)")

            XCTAssertTrue(range == length)
        }
    }
    
    func testStreamFileContentHeadersWithin() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #file) { result in
                do {
                    try result.get()
                } catch {
                    XCTFail("File Stream should have succeeded")
                }
            }
        }
        
        var headerRequest = HTTPHeaders()
        headerRequest.range = .init(unit: .bytes, ranges: [.within(start: 20, end: 25)])
        try app.testable(method: .running).test(.GET, "/file-stream", headers: headerRequest) { res in
            
            let contentRange = res.headers.first(name: "content-range")
            let contentLength = res.headers.first(name: "content-length")
            
            let lowerRange = Int((contentRange?.split(separator: "-")[0].split(separator: " ")[1])!)!
            let upperRange = Int((contentRange?.split(separator: "-")[1].split(separator: "/")[0])!)!
            
            let range = upperRange - lowerRange + 1
            let length = Int(contentLength!)!
            print("\(range) : \(length)")

            XCTAssertTrue(range == length)
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

        let path = #file.split(separator: "/").dropLast().joined(separator: "/")
        app.middleware.use(FileMiddleware(publicDirectory: "/" + path))

        try app.test(.GET, "/Utilities/foo%20bar.html") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "<h1>Hello</h1>\n")
        }
    }

    func testPercentDecodedRelativePath() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let path = #file.split(separator: "/").dropLast().joined(separator: "/")
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

        let path = #file.split(separator: "/").dropLast().joined(separator: "/")
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

        let path = #file.split(separator: "/").dropLast().joined(separator: "/")
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

        let path = #file.split(separator: "/").dropLast().joined(separator: "/")
        app.middleware.use(FileMiddleware(publicDirectory: "/" + path))

        try app.test(.GET, "Utilities/") { res in
            XCTAssertEqual(res.status, .notFound)
        }
    }
}
