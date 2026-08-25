import Vapor
import NIOCore
import NIOConcurrencyHelpers
import HTTPTypes
import _NIOFileSystem
import Crypto
import Vapor
import Testing
import VaporTesting
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import RoutingKit
import _NIOFileSystemFoundationCompat

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

            try await app.testing(method: .running).test(.get, "/file-stream") { res async in
                let test = "the quick brown fox"
                #expect(res.headers[.eTag] != nil)
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

            var headers = HTTPFields()
            headers[.connection] = "close"
            try await app.testing(method: .running).test(.get, "/file-stream", headers: headers) { res async in
                let test = "the quick brown fox"
                #expect(res.headers[.eTag] != nil)
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
                    tmpPath = try await FilePath(FileSystem.shared.temporaryDirectory.description).appending(UUID().uuidString).string
                } while try await FileSystem.shared.info(forFileAt: .init(tmpPath)) != nil

                return try await req.fileio.streamFile(at: tmpPath, advancedETagComparison: true) { result in
                    do {
                        try result.get()
                        Issue.record("File Stream should have failed")
                    } catch {
                    }
                }
            }

            try await app.testing(method: .running).test(.get, "/file-stream") { res async in
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

            try await app.testing(method: .running).test(.get, "/file-stream") { res async throws in
                let fileData = try Data(contentsOf: URL(fileURLWithPath: #filePath))
                let digest = SHA256.hash(data: fileData)
                let eTag = res.headers[.eTag]
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

            try await app.testing(method: .running).test(.get, "/file-stream") { res in
                guard let fileInfo = try await FileSystem.shared.info(forFileAt: .init(#filePath)) else {
                    Issue.record("Missing File Info")
                    return
                }
                let fileETag = "\"\(Int(fileInfo.lastDataModificationTime.date.timeIntervalSince1970))-\(fileInfo.size)\""
                #expect(res.headers[.eTag] == fileETag)
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

            var headerRequest = HTTPFields()
            headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: 20)])
            try await app.testing(method: .running).test(.get, "/file-stream", headers: headerRequest) { res async in
                let contentRange = res.headers[.contentRange]
                let contentLength = res.headers[.contentLength]

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

            var headerRequest = HTTPFields()
            headerRequest.range = .init(unit: .bytes, ranges: [.start(value: 20)])
            try await app.testing(method: .running).test(.get, "/file-stream", headers: headerRequest) { res async in

                let contentRange = res.headers[.contentRange]
                let contentLength = res.headers[.contentLength]

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

            var headerRequest = HTTPFields()
            headerRequest.range = .init(unit: .bytes, ranges: [.within(start: 20, end: 25)])
            try await app.testing(method: .running).test(.get, "/file-stream", headers: headerRequest) { res async in

                let contentRange = res.headers[.contentRange]
                let contentLength = res.headers[.contentLength]

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

            var headers = HTTPFields()
            headers.range = .init(unit: .bytes, ranges: [.within(start: 0, end: 0)])
            try await app.testing(method: .running).test(.get, "/file-stream", headers: headers) { res async in
                #expect(res.status == .partialContent)

                #expect(res.headers[.contentLength] == "1")
                let range = res.headers[.contentRange]!.split(separator: "/").first!.split(separator: " ").last!
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

            // Run against a real server so range validation is exercised end-to-end. A single boot
            // serves every request in the block; multiple `.test` calls would re-boot (see vapor#3521).
            try await app.test(method: .running) { runner in
                var headerRequest = HTTPFields()
                headerRequest.range = .init(unit: .bytes, ranges: [.within(start: -20, end: 25)])
                let res1 = try await runner.sendRequest(.get, "/file-stream", headers: headerRequest)
                #expect(res1.status == .badRequest)

                headerRequest.range = .init(unit: .bytes, ranges: [.within(start: 10, end: 100000000)])
                let res2 = try await runner.sendRequest(.get, "/file-stream", headers: headerRequest)
                #expect(res2.status == .badRequest)
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

            try await app.test(method: .running) { runner in
                var headerRequest = HTTPFields()
                headerRequest.range = .init(unit: .bytes, ranges: [.start(value: -20)])
                let res1 = try await runner.sendRequest(.get, "/file-stream", headers: headerRequest)
                #expect(res1.status == .badRequest)

                headerRequest.range = .init(unit: .bytes, ranges: [.start(value: 100000000)])
                let res2 = try await runner.sendRequest(.get, "/file-stream", headers: headerRequest)
                #expect(res2.status == .badRequest)
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

            try await app.test(method: .running) { runner in
                var headerRequest = HTTPFields()
                headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: -20)])
                let res1 = try await runner.sendRequest(.get, "/file-stream", headers: headerRequest)
                #expect(res1.status == .badRequest)

                headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: 100000000)])
                let res2 = try await runner.sendRequest(.get, "/file-stream", headers: headerRequest)
                #expect(res2.status == .badRequest)
            }
        }
    }

    @Test("Test Percent Decoded File Path")
    func testPercentDecodedFilePath() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path))

            try await app.testing().test(.get, "/Utilities/foo%20bar.html") { res async in
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

            try await app.testing().test(.get, "%2e%2e/VaporTests/Utilities/foo.txt") { res async in
                #expect(res.status == .forbidden)
            }

            try await app.testing().test(.get, "Utilities/foo.txt") { res async in
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

            try await app.testing().test(.get, "Utilities/") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "<h1>Root Default</h1>\n")
            }

            try await app.testing().test(.get, "Utilities/SubUtilities/") { res async in
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

            try await app.testing().test(.get, "Utilities/") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "<h1>Root Default</h1>\n")
            }

            try await app.testing().test(.get, "Utilities/SubUtilities/") { res async in
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

            try await app.testing().test(.get, "Utilities/") { res in
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

            try await app.testing().test(.get, "Utilities") { res in
                #expect(res.status == .movedPermanently)
            }

            try await app.testing().test(.get, "Utilities/SubUtilities") { res in
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

            try await app.testing().test(.get, "Utilities?vaporTest=test") { res in
                #expect(res.status == .movedPermanently)
                #expect(res.headers[.location] == "/Utilities/?vaporTest=test")
            }

            try await app.testing().test(.get, "Utilities/SubUtilities?vaporTest=test") { res in
                #expect(res.status == .movedPermanently)
                #expect(res.headers[.location] == "/Utilities/SubUtilities/?vaporTest=test")
            }

            try await app.testing().test(.get, "Utilities/SubUtilities?vaporTest=test#vapor") { res in
                #expect(res.status == .movedPermanently)
                #expect(res.headers[.location] == "/Utilities/SubUtilities/?vaporTest=test#vapor")
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

            try await app.testing().test(.get, "Utilities") { res in
                #expect(res.status == .notFound)
            }

            try await app.testing().test(.get, "Utilities/SubUtilities") { res in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test("Test Invalid Range Header Does Not Crash", .bug("https://github.com/vapor/vapor/security/advisories/GHSA-vj2m-9f5j-mpr5"))
    func testInvalidRangeHeaderDoesNotCrash() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true)
            }

            try await app.test(method: .running) { runner in
                var headers = HTTPFields()
                headers[.range] = "bytes=0-9223372036854775807"
                let res1 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res1.status == .badRequest)

                // `bytes=1-10` is a satisfiable range on this file, so it's served as 206, not rejected.
                headers[.range] = "bytes=1-10"
                let res2 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res2.status == .partialContent)

                headers[.range] = "bytes=100-10"
                let res3 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res3.status == .badRequest)

                headers[.range] = "bytes=10--100"
                let res4 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res4.status == .badRequest)

                headers[.range] = "bytes=9223372036854775808-"
                let res5 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res5.status == .badRequest)

                headers[.range] = "bytes=922337203-"
                let res6 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res6.status == .badRequest)

                headers[.range] = "bytes=-922337203"
                let res7 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res7.status == .badRequest)

                headers[.range] = "bytes=-9223372036854775808-"
                let res8 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res8.status == .badRequest)
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

    // MARK: Bodyless methods

    @Test("HEAD request does not read the file")
    func testHeadRequestDoesNotReadFile() async throws {
        try await withApp { app in
            let fileWasRead = NIOLockedValueBox(false)
            app.get("file-stream") { req -> Response in
                try await req.fileio.streamFile(at: #filePath, advancedETagComparison: false) { _ in
                    fileWasRead.withLockedValue { $0 = true }
                }
            }

            try await app.test(method: .running) { runner in
                let res = try await runner.sendRequest(.head, "/file-stream")
                #expect(res.status == .ok)
                // The length is advertised even though no body follows it.
                #expect(res.headers[.contentLength] != nil)
                #expect(res.body.readableBytes == 0)
            }

            // A HEAD response carries no body, so opening and reading the file is wasted work:
            // the transport discards every byte before it reaches the client. Vapor 4 skipped body
            // serialisation entirely via `Response.forHeadRequest`; the new server doesn't, so the
            // whole file is still read off disk.
            withKnownIssue("HEAD still runs the body stream and reads the file") {
                #expect(fileWasRead.withLockedValue { $0 } == false)
            }
        }
    }

    @Test("OPTIONS request does not read the file")
    func testOptionsRequestDoesNotReadFile() async throws {
        try await withApp { app in
            let fileWasRead = NIOLockedValueBox(false)
            app.on(.options, "file-stream") { req -> Response in
                try await req.fileio.streamFile(at: #filePath, advancedETagComparison: false) { _ in
                    fileWasRead.withLockedValue { $0 = true }
                }
            }

            try await app.test(method: .running) { runner in
                let res = try await runner.sendRequest(.options, "/file-stream")
                // Unlike HEAD, nothing downstream strips the body for OPTIONS, so the whole file
                // goes out on the wire.
                withKnownIssue("OPTIONS returns the file body") {
                    #expect(res.body.readableBytes == 0)
                }
            }

            withKnownIssue("OPTIONS reads the file") {
                #expect(fileWasRead.withLockedValue { $0 } == false)
            }
        }
    }

    @Test("FileMiddleware does not send a file body for HEAD and OPTIONS")
    func testFileMiddlewareBodylessMethods() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path))

            try await app.test(method: .running) { runner in
                let head = try await runner.sendRequest(.head, "/Utilities/foo.txt")
                #expect(head.status == .ok)
                #expect(head.body.readableBytes == 0)

                // `FileMiddleware` doesn't look at the method at all: any method whose path matches
                // a file is served the file.
                let options = try await runner.sendRequest(.options, "/Utilities/foo.txt")
                withKnownIssue("FileMiddleware serves the file body for OPTIONS") {
                    #expect(options.body.readableBytes == 0)
                }
            }
        }
    }
}
