import Vapor
import NIOCore
import NIOHTTP1
import _NIOFileSystem
import Crypto
import Vapor
import VaporTestUtils
import Testing
import VaporTesting
import Foundation

@Suite("File Tests")
struct FileTests {

    @Test("Test Stream File")
    func testStreamFile() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                return try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true) { result in
                    do {
                        try result.get()
                    } catch {
                        Issue.record("File Stream should have succeeded")
                    }
                }
            }

            try await app.testing(method: .running).test(.GET, "/file-stream") { res async in
                let test = "the quick brown fox"
                #expect(res.headers.first(name: .eTag) != nil)
                #expect(res.body.string.contains(test))
            }
        }
    }

    @Test("Test Stream File Connection Close")
    func testStreamFileConnectionClose() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                return try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true)
            }

            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .connection, value: "close")
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headers) { res async in
                let test = "the quick brown fox"
                #expect(res.headers.first(name: .eTag) != nil)
                #expect(res.body.string.contains(test))
            }
        }
    }

    @Test("Test Stream File Null")
    func testStreamFileNull() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                var tmpPath: String
                repeat {
                    tmpPath = try await FileSystem.shared.temporaryDirectory.appending(UUID().uuidString).string
                } while try await FileSystem.shared.info(forFileAt: .init(tmpPath)) != nil

                return try await req.fileio.streamFile(at: tmpPath, advancedETagComparison: true) { result in
                    do {
                        try result.get()
                        Issue.record("File Stream should have failed")
                    } catch {
                    }
                }
            }

            try await app.testing(method: .running(port: 0)).test(.GET, "/file-stream") { res async in
                #expect(res.status == .internalServerError)
            }
        }
    }

    @Test("Test Advanced ETag Headers")
    func testAdvancedETagHeaders() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                return try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true) { result in
                    do {
                        try result.get()
                    } catch {
                        Issue.record("File Stream should have succeeded")
                    }
                }
            }

            try await app.testing(method: .running).test(.GET, "/file-stream") { res async throws in
                let fileData = try Data(contentsOf: URL(fileURLWithPath: #filePath))
                let digest = SHA256.hash(data: fileData)
                let eTag = res.headers.first(name: "etag")
                #expect(eTag == digest.hex)
            }
        }
    }

    @Test("Test Simple ETag Headers")
    func testSimpleETagHeaders() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                return try await req.fileio.streamFile(at: #filePath, advancedETagComparison: false) { result in
                    do {
                        try result.get()
                    } catch {
                        Issue.record("File Stream should have succeeded")
                    }
                }
            }

            try await app.testing(method: .running).test(.GET, "/file-stream") { res in
                guard let fileInfo = try await FileSystem.shared.info(forFileAt: .init(#filePath)) else {
                    Issue.record("Missing File Info")
                    return
                }
                let fileETag = "\"\(Int(fileInfo.lastDataModificationTime.date.timeIntervalSince1970))-\(fileInfo.size)\""
                #expect(res.headers.first(name: .eTag) == fileETag)
            }
        }
    }

    @Test("Test Stream File Content Header Tail")
    func testStreamFileContentHeaderTail() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                return try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true) { result in
                    do {
                        try result.get()
                    } catch {
                        Issue.record("File Stream should have succeeded")
                    }
                }
            }

            var headerRequest = HTTPHeaders()
            headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: 20)])
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headerRequest) { res async in

                let contentRange = res.headers.first(name: "content-range")
                let contentLength = res.headers.first(name: "content-length")

                let lowerRange = Int((contentRange?.split(separator: "-")[0].split(separator: " ")[1])!)!
                let upperRange = Int((contentRange?.split(separator: "-")[1].split(separator: "/")[0])!)!

                let range = upperRange - lowerRange + 1
                let length = Int(contentLength!)!

                #expect(range == length)
            }
        }
    }

    @Test("Test Stream File Content Header Start")
    func testStreamFileContentHeaderStart() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                return try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true) { result in
                    do {
                        try result.get()
                    } catch {
                        Issue.record("File Stream should have succeeded")
                    }
                }
            }

            var headerRequest = HTTPHeaders()
            headerRequest.range = .init(unit: .bytes, ranges: [.start(value: 20)])
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headerRequest) { res async in

                let contentRange = res.headers.first(name: "content-range")
                let contentLength = res.headers.first(name: "content-length")

                let lowerRange = Int((contentRange?.split(separator: "-")[0].split(separator: " ")[1])!)!
                let upperRange = Int((contentRange?.split(separator: "-")[1].split(separator: "/")[0])!)!

                let range = upperRange - lowerRange + 1
                let length = Int(contentLength!)!

                #expect(range == length)
            }
        }
    }

    @Test("Test Stream File Content Headers Within")
    func testStreamFileContentHeadersWithin() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true) { result in
                    #expect(throws: Never.self) {
                        try result.get()
                    }
                }
            }

            var headerRequest = HTTPHeaders()
            headerRequest.range = .init(unit: .bytes, ranges: [.within(start: 20, end: 25)])
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headerRequest) { res async in

                let contentRange = res.headers.first(name: "content-range")
                let contentLength = res.headers.first(name: "content-length")

                let lowerRange = Int((contentRange?.split(separator: "-")[0].split(separator: " ")[1])!)!
                let upperRange = Int((contentRange?.split(separator: "-")[1].split(separator: "/")[0])!)!

                let range = upperRange - lowerRange + 1
                let length = Int(contentLength!)!

                #expect(range == length)
            }
        }
    }

    @Test("Test Stream File Content Headers Only First Byte")
    func testStreamFileContentHeadersOnlyFirstByte() async throws {
        try await withApp { app in
            app.get("file-stream") { req in
                try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true) { result in
                    #expect(throws: Never.self) {
                        try result.get()
                    }
                }
            }

            var headers = HTTPHeaders()
            headers.range = .init(unit: .bytes, ranges: [.within(start: 0, end: 0)])
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headers) { res async in
                #expect(res.status == .partialContent)

                #expect(res.headers.first(name: .contentLength) == "1")
                let range = res.headers.first(name: .contentRange)!.split(separator: "/").first!.split(separator: " ").last!
                #expect(range == "0-0")

                #expect(res.body.readableBytes == 1)
            }
        }
    }

    @Test("Test Stream File Content Headers Within Fail")
    func testStreamFileContentHeadersWithinFail() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true) { result in
                    #expect(throws: Never.self) {
                        try result.get()
                    }
                }
            }

            var headerRequest = HTTPHeaders()
            headerRequest.range = .init(unit: .bytes, ranges: [.within(start: -20, end: 25)])
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headerRequest) { res async in
                #expect(res.status == .badRequest)
            }

            headerRequest.range = .init(unit: .bytes, ranges: [.within(start: 10, end: 100000000)])
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headerRequest) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test("Test Stream File Content Headers Start Fail")
    func testStreamFileContentHeadersStartFail() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true) { result in
                    #expect(throws: Never.self) {
                        try result.get()
                    }
                }
            }

            var headerRequest = HTTPHeaders()
            headerRequest.range = .init(unit: .bytes, ranges: [.start(value: -20)])
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headerRequest) { res async in
                #expect(res.status == .badRequest)
            }

            headerRequest.range = .init(unit: .bytes, ranges: [.start(value: 100000000)])
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headerRequest) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test("Test Stream File Content Headers Tail Fail")
    func testStreamFileContentHeadersTailFail() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true) { result in
                    #expect(throws: Never.self) {
                        try result.get()
                    }
                }
            }

            var headerRequest = HTTPHeaders()
            headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: -20)])
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headerRequest) { res async in
                #expect(res.status == .badRequest)
            }

            headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: 100000000)])
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headerRequest) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test("Test Percent Decoded File Path")
    func testPercentDecodedFilePath() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path))

            try await app.testing().test(.GET, "/Utilities/foo%20bar.html") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "<h1>Hello</h1>\n")
            }
        }
    }

    @Test("Test Percent Decoded Relative Path")
    func testPercentDecodedRelativePath() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path))

            try await app.testing().test(.GET, "%2e%2e/VaporTests/Utilities/foo.txt") { res async in
                #expect(res.status == .forbidden)
            }.test(.GET, "Utilities/foo.txt") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "bar\n")
            }
        }
    }

    @Test("Test Default File Relative Path")
    func testDefaultFileRelative() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path, defaultFile: "index.html"))

            try await app.testing().test(.GET, "Utilities/") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "<h1>Root Default</h1>\n")
            }.test(.GET, "Utilities/SubUtilities/") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "<h1>Subdirectory Default</h1>\n")
            }
        }
    }

    @Test("Test Default File Absolute Path")
    func testDefaultFileAbsolute() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path, defaultFile: "/Utilities/index.html"))

            try await app.testing().test(.GET, "Utilities/") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "<h1>Root Default</h1>\n")
            }.test(.GET, "Utilities/SubUtilities/") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "<h1>Root Default</h1>\n")
            }
        }
    }

    @Test("Test No Default File")
    func testNoDefaultFile() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path))

            try await app.testing().test(.GET, "Utilities/") { res in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test("Test Redirect")
    func testRedirect() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(
                FileMiddleware(
                    publicDirectory: "/" + path,
                    defaultFile: "index.html",
                    directoryAction: .redirect
                )
            )

            try await app.testing().test(.GET, "Utilities") { res in
                #expect(res.status == .movedPermanently)
            }.test(.GET, "Utilities/SubUtilities") { res in
                #expect(res.status == .movedPermanently)
            }
        }
    }

    @Test("Test Redirect With Query Params")
    func testRedirectWithQueryParams() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(
                FileMiddleware(
                    publicDirectory: "/" + path,
                    defaultFile: "index.html",
                    directoryAction: .redirect
                )
            )

            try await app.testing().test(.GET, "Utilities?vaporTest=test") { res in
                #expect(res.status == .movedPermanently)
                #expect(res.headers.first(name: .location) == "/Utilities/?vaporTest=test")
            }.test(.GET, "Utilities/SubUtilities?vaporTest=test") { res in
                #expect(res.status == .movedPermanently)
                #expect( res.headers.first(name: .location) == "/Utilities/SubUtilities/?vaporTest=test")
            }.test(.GET, "Utilities/SubUtilities?vaporTest=test#vapor") { res in
                #expect(res.status == .movedPermanently)
                #expect( res.headers.first(name: .location) == "/Utilities/SubUtilities/?vaporTest=test#vapor")
            }
        }
    }

    @Test("Test No Redirect")
    func testNoRedirect() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(
                FileMiddleware(
                    publicDirectory: "/" + path,
                    defaultFile: "index.html",
                    directoryAction: .none
                )
            )

            try await app.testing().test(.GET, "Utilities") { res in
                #expect(res.status == .notFound)
            }.test(.GET, "Utilities/SubUtilities") { res in
                #expect(res.status == .notFound)
            }
        }
    }

    // https://github.com/vapor/vapor/security/advisories/GHSA-vj2m-9f5j-mpr5
    @Test("Test Invalid Range Header Does Not Crash")
    func testInvalidRangeHeaderDoesNotCrash() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true)
            }

            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .range, value: "bytes=0-9223372036854775807")
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headers) { res async in
                #expect(res.status == .badRequest)
            }

            headers.replaceOrAdd(name: .range, value: "bytes=-1-10")
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headers) { res async in
                #expect(res.status == .badRequest)
            }

            headers.replaceOrAdd(name: .range, value: "bytes=100-10")
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headers) { res async in
                #expect(res.status == .badRequest)
            }

            headers.replaceOrAdd(name: .range, value: "bytes=10--100")
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headers) { res async in
                #expect(res.status == .badRequest)
            }

            headers.replaceOrAdd(name: .range, value: "bytes=9223372036854775808-")
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headers) { res async in
                #expect(res.status == .badRequest)
            }

            headers.replaceOrAdd(name: .range, value: "bytes=922337203-")
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headers) { res async in
                #expect(res.status == .badRequest)
            }

            headers.replaceOrAdd(name: .range, value: "bytes=-922337203")
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headers) { res async in
                #expect(res.status == .badRequest)
            }

            headers.replaceOrAdd(name: .range, value: "bytes=-9223372036854775808")
            try await app.testing(method: .running).test(.GET, "/file-stream", headers: headers) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }

    #warning("Consider whether we should offer these anymoer instead of just deferring to NIOFileSystem")
//    func testFileRead() async throws {
//        let request = Request(application: app, on: app.eventLoopGroup.next())
//
//        let path = "/" + #filePath.split(separator: "/").dropLast().joined(separator: "/") + "/Utilities/long-test-file.txt"
//
//        let content = try String(contentsOfFile: path, encoding: .utf8)
//
//        var readContent = ""
//        let file = try await request.fileio.readFile(at: path, chunkSize: 16 * 1024) // 32Kb, ~5 chunks
//        for try await chunk in file {
//            readContent += String(buffer: chunk)
//        }
//
//        XCTAssertEqual(readContent, content, "The content read from the file does not match the expected content.")
//    }
//    func testFileWrite() async throws {
//        let data = "Hello"
//        let path = "/tmp/fileio_write.txt"
//
//        do {
//            let request = Request(application: app, on: app.eventLoopGroup.next())
//
//            try await request.fileio.writeFile(ByteBuffer(string: data), at: path)
//
//            let result = try String(contentsOfFile: path, encoding: .utf8)
//            XCTAssertEqual(result, data)
//        } catch {
//            try await FileSystem.shared.removeItem(at: .init(path))
//            throw error
//        }
//    }
}
