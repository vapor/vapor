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
                return try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true) { result in
                    do {
                        try result.get()
                    } catch {
                        Issue.record("File Stream should have succeeded")
                    }
                }
            }

            try await app.testing(method: .running).test(.get, "/file-stream") { res in
                let test = "the quick brown fox"
                #expect(res.headers[.eTag] != nil)
                try #expect(await res.body.requireString().contains(test))
            }
        }
    }

    @Test("Test Stream File Connection Close")
    func testStreamFileConnectionClose() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                return try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true)
            }

            var headers = HTTPFields()
            headers[.connection] = "close"
            try await app.testing(method: .running).test(.get, "/file-stream", headers: headers) { res in
                let test = "the quick brown fox"
                #expect(res.headers[.eTag] != nil)
                try #expect(await res.body.requireString().contains(test))
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

                return try await app.fileio.streamFile(at: tmpPath, for: req, advancedETagComparison: true) { result in
                    do {
                        try result.get()
                        Issue.record("File Stream should have failed")
                    } catch {
                    }
                }
            }

            try await app.testing(method: .running).test(.get, "/file-stream") { res in
                #expect(res.status == .internalServerError)
            }
        }
    }

    @Test("Test Advanced ETag Headers")
    func testAdvancedETagHeaders() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                return try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true) { result in
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

    @Test("Advanced ETag hashes are cached across requests")
    func testAdvancedETagHashIsCached() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true)
            }

            #expect(await app.fileETagHashCache.entry(forFileAt: #filePath) == nil)

            try await app.test(method: .running) { runner in
                let first = try await runner.sendRequest(.get, "/file-stream")
                let firstETag = try #require(first.headers[.eTag])

                // Without a populated cache every request re-reads and re-hashes the whole file.
                let cached = try #require(await app.fileETagHashCache.entry(forFileAt: #filePath))
                #expect(cached.digestHex == firstETag)

                let second = try await runner.sendRequest(.get, "/file-stream")
                #expect(second.headers[.eTag] == firstETag)
            }
        }
    }

    @Test("Test Simple ETag Headers")
    func testSimpleETagHeaders() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                return try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: false) { result in
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
                return try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true) { result in
                    do {
                        try result.get()
                    } catch {
                        Issue.record("File Stream should have succeeded")
                    }
                }
            }

            var headerRequest = HTTPFields()
            headerRequest.range = .init(unit: .bytes, ranges: [.tail(value: 20)])
            try await app.testing(method: .running).test(.get, "/file-stream", headers: headerRequest) { res in
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
                return try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true) { result in
                    do {
                        try result.get()
                    } catch {
                        Issue.record("File Stream should have succeeded")
                    }
                }
            }

            var headerRequest = HTTPFields()
            headerRequest.range = .init(unit: .bytes, ranges: [.start(value: 20)])
            try await app.testing(method: .running).test(.get, "/file-stream", headers: headerRequest) { res in

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
                try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true) { result in
                    #expect(throws: Never.self) {
                        try result.get()
                    }
                }
            }

            var headerRequest = HTTPFields()
            headerRequest.range = .init(unit: .bytes, ranges: [.within(start: 20, end: 25)])
            try await app.testing(method: .running).test(.get, "/file-stream", headers: headerRequest) { res in

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
                try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true) { result in
                    #expect(throws: Never.self) {
                        try result.get()
                    }
                }
            }

            var headers = HTTPFields()
            headers.range = .init(unit: .bytes, ranges: [.within(start: 0, end: 0)])
            try await app.testing(method: .running).test(.get, "/file-stream", headers: headers) { res in
                #expect(res.status == .partialContent)

                #expect(res.headers[.contentLength] == "1")
                let range = res.headers[.contentRange]!.split(separator: "/").first!.split(separator: " ").last!
                #expect(range == "0-0")

                try #expect(await res.body.data()?.count == 1)
            }
        }
    }

    @Test("Test Stream File Content Headers Within Fail")
    func testStreamFileContentHeadersWithinFail() async throws {
        try await withApp { app in
            app.get("file-stream") { req -> Response in
                try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true) { result in
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
                try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true) { result in
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
                try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true) { result in
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
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path, etagCache: app.fileETagHashCache))

            try await app.testing().test(.get, "/Utilities/foo%20bar.html") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "<h1>Hello</h1>\n")
            }
        }
    }

    @Test("Test Percent Decoded Relative Path")
    func testPercentDecodedRelativePath() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path, etagCache: app.fileETagHashCache))

            try await app.testing().test(.get, "%2e%2e/VaporTests/Utilities/foo.txt") { res in
                #expect(res.status == .forbidden)
            }

            try await app.testing().test(.get, "Utilities/foo.txt") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "bar\n")
            }
        }
    }

    @Test("Test Default File Relative Path")
    func testDefaultFileRelative() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path, defaultFile: "index.html", etagCache: app.fileETagHashCache))

            try await app.testing().test(.get, "Utilities/") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "<h1>Root Default</h1>\n")
            }

            try await app.testing().test(.get, "Utilities/SubUtilities/") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "<h1>Subdirectory Default</h1>\n")
            }
        }
    }

    @Test("Test Default File Absolute Path")
    func testDefaultFileAbsolute() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path, defaultFile: "/Utilities/index.html", etagCache: app.fileETagHashCache))

            try await app.testing().test(.get, "Utilities/") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "<h1>Root Default</h1>\n")
            }

            try await app.testing().test(.get, "Utilities/SubUtilities/") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "<h1>Root Default</h1>\n")
            }
        }
    }

    @Test("Test No Default File")
    func testNoDefaultFile() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path, etagCache: app.fileETagHashCache))

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
                    directoryAction: .redirect,
                    etagCache: app.fileETagHashCache
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
                    directoryAction: .redirect,
                    etagCache: app.fileETagHashCache
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
                    directoryAction: .none,
                    etagCache: app.fileETagHashCache
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
                try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true)
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

    @Test("Cancelling a file stream still closes the file handle")
    func testCancelledFileStreamClosesHandle() async throws {
        // Large enough that a read is still in flight when the cancellation lands: the whole point
        // is to cancel between opening the handle and closing it.
        let filePath = try await makeTemporaryFile(size: 8 << 20)

        try await withApp { app in
            let request = Request()

            // `close()` is dispatched through a thread pool that refuses cancelled work, so a
            // handle closed naively from a cancelled task stays open and trips NIOFileSystem's
            // `deinit` precondition — which traps the process rather than throwing. Cancelling
            // repeatedly at slightly different points covers the window between open and close.
            for iteration in 1...10 {
                let response = try await app.fileio.streamFile(
                    at: filePath, for: request, advancedETagComparison: false)

                // `collect()` is mutating, so the Task works on its own copy of the body. That
                // is fine here: this test is about descriptor cleanup on cancellation, not the
                // collected value.
                let collecting = Task { () -> Data? in
                    var body = response.body
                    return try await body.collect()
                }
                try await Task.sleep(for: .microseconds(200 * iteration))
                collecting.cancel()
                _ = try? await collecting.value
            }
        }

        // Getting here at all is the assertion: a leaked descriptor would have killed the process.
    }

    // MARK: Bodyless methods

    @Test("HEAD request does not read the file")
    func testHeadRequestDoesNotReadFile() async throws {
        try await withApp { app in
            let fileWasRead = NIOLockedValueBox(false)
            app.get("file-stream") { req -> Response in
                try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: false) { _ in
                    fileWasRead.withLockedValue { $0 = true }
                }
            }

            try await app.test(method: .running) { runner in
                let res = try await runner.sendRequest(.head, "/file-stream")
                #expect(res.status == .ok)
                // The length is advertised even though no body follows it.
                #expect(res.headers[.contentLength] != nil)
                try #expect(await res.body.data()?.count == 0)
            }

            // A HEAD response carries no body, so opening and reading the file would be wasted
            // work: the transport discards every byte before it reaches the client. The server
            // handler concludes HEAD responses without running the body stream at all.
            #expect(fileWasRead.withLockedValue { $0 } == false)
        }
    }

    @Test("FileMiddleware only serves GET and HEAD")
    func testFileMiddlewareOnlyServesGetAndHead() async throws {
        try await withApp { app in
            let path = #filePath.split(separator: "/").dropLast().joined(separator: "/")
            app.middleware.use(FileMiddleware(publicDirectory: "/" + path, etagCache: app.fileETagHashCache))

            try await app.test(method: .running) { runner in
                let get = try await runner.sendRequest(.get, "/Utilities/foo.txt")
                #expect(get.status == .ok)
                try #expect(await (get.body.data()?.count ?? 0) > 0)

                // HEAD gets the headers a GET would have returned, with no body.
                let head = try await runner.sendRequest(.head, "/Utilities/foo.txt")
                #expect(head.status == .ok)
                #expect(head.headers[.contentLength] == get.headers[.contentLength])
                try #expect(await head.body.data()?.count == 0)

                // Everything else falls through the middleware; nothing else is registered here,
                // so it 404s rather than being answered with the file.
                for method in [HTTPRequest.Method.options, .post, .delete] {
                    let res = try await runner.sendRequest(method, "/Utilities/foo.txt")
                    #expect(res.status == .notFound, "\(method) was served by FileMiddleware")
                }
            }
        }
    }
}
