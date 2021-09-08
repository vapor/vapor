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
    
    func testDefaultFile() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let path = #file.split(separator: "/").dropLast().joined(separator: "/")
        app.middleware.use(FileMiddleware(publicDirectory: "/" + path, defaultFile: "index.html"))

        try app.test(.GET, "Utilities/") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "<h1>Default</h1>\n")
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
