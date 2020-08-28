import XCTVapor

final class FileTests: XCTestCase {
    func testStreamFile() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #file)
        }

        try app.testable(method: .running).test(.GET, "/file-stream") { res in
            let test = "the quick brown fox"
            XCTAssertNotNil(res.headers.first(name: .eTag))
            XCTAssertContains(res.body.string, test)
        }
    }

    func testStreamFileConnectionClose() throws {
        let app = Application(.detect(default: .testing))
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
    
    func testFileWrite() throws {
        let app = Application(.detect(default: .testing))
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
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        let path = #file.split(separator: "/").dropLast().joined(separator: "/")
        app.middleware.use(FileMiddleware(publicDirectory: "/" + path))

        try app.test(.GET, "/Utilities/foo%20bar.html") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "<h1>Hello</h1>\n")
        }
    }
}
