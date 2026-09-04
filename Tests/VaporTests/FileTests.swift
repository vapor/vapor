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

            try await app.testing(method: .running()).test(.get, "/file-stream") { res in
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
            try await app.testing(method: .running()).test(.get, "/file-stream", headers: headers) { res in
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

            try await app.testing(method: .running()).test(.get, "/file-stream") { res in
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

            try await app.testing(method: .running()).test(.get, "/file-stream") { res async throws in
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

            try await app.test(method: .running()) { runner in
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

            try await app.testing(method: .running()).test(.get, "/file-stream") { res in
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
            try await app.testing(method: .running()).test(.get, "/file-stream", headers: headerRequest) { res in
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
            try await app.testing(method: .running()).test(.get, "/file-stream", headers: headerRequest) { res in

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
            try await app.testing(method: .running()).test(.get, "/file-stream", headers: headerRequest) { res in

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
            try await app.testing(method: .running()).test(.get, "/file-stream", headers: headers) { res in
                #expect(res.status == .partialContent)

                #expect(res.headers[.contentLength] == "1")
                let range = res.headers[.contentRange]!.split(separator: "/").first!.split(separator: " ").last!
                #expect(range == "0-0")

                try #expect(await res.body.data()?.count == 1)
            }
        }
    }

    // MARK: Byte ranges

    /// The file the range tests below are served from, and its contents for comparison. Big enough
    /// that a range spans several of `streamFile`'s 128 KB chunks.
    private static var rangeTestFile: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Utilities/long-test-file.txt")
            .path
    }

    /// Serves ``rangeTestFile`` at `/file-stream` and hands the block a live server plus the file's
    /// bytes, so a response can be compared against exactly the slice that was asked for.
    private func withRangeServer(
        _ body: (any VaporTestingRunner, Data) async throws -> Void
    ) async throws {
        let path = Self.rangeTestFile
        let contents = try Data(contentsOf: URL(fileURLWithPath: path))
        try await withApp { app in
            app.get("file-stream") { req in
                try await app.fileio.streamFile(at: path, for: req)
            }
            try await app.test(method: .running()) { runner in
                try await body(runner, contents)
            }
        }
    }

    @Test("A file response advertises range support with Accept-Ranges")
    func testFileResponseAdvertisesAcceptRanges() async throws {
        try await withRangeServer { runner, _ in
            // A whole-file response is what tells a client it may ask for a range at all, so it
            // carries the header just as a partial one does.
            let whole = try await runner.sendRequest(.get, "/file-stream")
            #expect(whole.status == .ok)
            #expect(whole.headers[.acceptRanges] == "bytes")

            var headers = HTTPFields()
            headers.range = .init(unit: .bytes, ranges: [.within(start: 0, end: 99)])
            let partial = try await runner.sendRequest(.get, "/file-stream", headers: headers)
            #expect(partial.status == .partialContent)
            #expect(partial.headers[.acceptRanges] == "bytes")

            // `Accept` is a request header describing the client's media-type preferences. A
            // response claiming `Accept: bytes` is meaningless, and is what was sent before.
            #expect(whole.headers[.accept] == nil)
            #expect(partial.headers[.accept] == nil)
        }
    }

    @Test("A byte range serves exactly the bytes it asked for",
          .bug("https://github.com/vapor/vapor/issues/2566"))
    func testByteRangeServesExactlyTheRequestedBytes() async throws {
        try await withRangeServer { runner, contents in
            // The three ranges from the issue, which each came back with `end + 1` bytes (the range
            // start was ignored) rather than `end - start + 1`.
            for (start, end) in [(1024, 24601), (24602, 68000), (0, 0), (168_000, 168_502)] {
                var headers = HTTPFields()
                headers.range = .init(unit: .bytes, ranges: [.within(start: start, end: end)])
                let res = try await runner.sendRequest(.get, "/file-stream", headers: headers)

                let expected = contents[start...end]
                #expect(res.status == .partialContent, "bytes=\(start)-\(end)")
                #expect(
                    res.headers[.contentRange] == "bytes \(start)-\(end)/\(contents.count)",
                    "bytes=\(start)-\(end)")
                #expect(
                    res.headers[.contentLength] == "\(expected.count)",
                    "bytes=\(start)-\(end)")

                let body = try await res.body.data() ?? Data()
                #expect(body.count == expected.count, "bytes=\(start)-\(end)")
                #expect(body == Data(expected), "bytes=\(start)-\(end) served the wrong bytes")
            }
        }
    }

    @Test("An open-ended and a suffix range serve exactly the bytes they asked for",
          .bug("https://github.com/vapor/vapor/issues/2566"))
    func testOpenEndedAndSuffixRangesServeExactBytes() async throws {
        try await withRangeServer { runner, contents in
            let size = contents.count

            // `bytes=1024-` is everything from 1024 to the last byte.
            var headers = HTTPFields()
            headers.range = .init(unit: .bytes, ranges: [.start(value: 1024)])
            let open = try await runner.sendRequest(.get, "/file-stream", headers: headers)
            #expect(open.status == .partialContent)
            #expect(open.headers[.contentRange] == "bytes 1024-\(size - 1)/\(size)")
            #expect(open.headers[.contentLength] == "\(size - 1024)")
            #expect(try await open.body.data() == Data(contents[1024...]))

            // `bytes=-500` is the last 500 bytes.
            headers.range = .init(unit: .bytes, ranges: [.tail(value: 500)])
            let suffix = try await runner.sendRequest(.get, "/file-stream", headers: headers)
            #expect(suffix.status == .partialContent)
            #expect(suffix.headers[.contentRange] == "bytes \(size - 500)-\(size - 1)/\(size)")
            #expect(suffix.headers[.contentLength] == "500")
            #expect(try await suffix.body.data() == Data(contents[(size - 500)...]))
        }
    }

    @Test("A byte range running past the end of the file is clamped to the end",
          .bug("https://github.com/vapor/vapor/issues/2991"))
    func testRangePastEndOfFileIsClamped() async throws {
        try await withRangeServer { runner, contents in
            let size = contents.count

            // The case from the issue: an end past EOF used to be a 400. Other servers serve up to
            // the end of the file, and RFC 9110 §14.1.2 says a range should be clamped, not refused.
            var headers = HTTPFields()
            headers.range = .init(unit: .bytes, ranges: [.within(start: 100, end: size + 5000)])
            let clamped = try await runner.sendRequest(.get, "/file-stream", headers: headers)
            #expect(clamped.status == .partialContent)
            #expect(clamped.headers[.contentRange] == "bytes 100-\(size - 1)/\(size)")
            #expect(clamped.headers[.contentLength] == "\(size - 100)")
            #expect(try await clamped.body.data() == Data(contents[100...]))

            // An end exactly one past the last byte is the off-by-one edge of the same case. It
            // used to declare one byte more than the file holds, which truncated the response
            // mid-stream and broke the connection.
            headers.range = .init(unit: .bytes, ranges: [.within(start: 0, end: size)])
            let offByOne = try await runner.sendRequest(.get, "/file-stream", headers: headers)
            #expect(offByOne.status == .partialContent)
            #expect(offByOne.headers[.contentRange] == "bytes 0-\(size - 1)/\(size)")
            #expect(offByOne.headers[.contentLength] == "\(size)")
            #expect(try await offByOne.body.data() == contents)

            // A suffix longer than the file selects the whole file, per RFC 9110 §14.1.2.
            headers.range = .init(unit: .bytes, ranges: [.tail(value: size + 5000)])
            let suffix = try await runner.sendRequest(.get, "/file-stream", headers: headers)
            #expect(suffix.status == .partialContent)
            #expect(suffix.headers[.contentRange] == "bytes 0-\(size - 1)/\(size)")
            #expect(suffix.headers[.contentLength] == "\(size)")
            #expect(try await suffix.body.data() == contents)
        }
    }

    @Test("A byte range that selects no bytes is 416, not 400",
          .bug("https://github.com/vapor/vapor/issues/2991"))
    func testRangePastEndOfFileIs416() async throws {
        try await withRangeServer { runner, contents in
            let size = contents.count

            // A range whose *start* is at or past the end selects nothing, so there is nothing to
            // clamp to. RFC 9110 §15.5.17 wants a 416 carrying the representation's real length.
            let unsatisfiable: [HTTPFields.Range.Value] = [
                .start(value: size),
                .start(value: size + 5000),
                .within(start: size, end: size + 10),
                .within(start: size + 5000, end: size + 6000),
                .tail(value: 0),
            ]

            for range in unsatisfiable {
                var headers = HTTPFields()
                headers.range = .init(unit: .bytes, ranges: [range])
                let res = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res.status == .rangeNotSatisfiable, "\(range.serialize())")
                #expect(res.headers[.contentRange] == "bytes */\(size)", "\(range.serialize())")
            }
        }
    }

    @Test("A malformed byte range is a 400, not a 416",
          .bug("https://github.com/vapor/vapor/issues/2991"))
    func testMalformedRangeIsBadRequest() async throws {
        // A malformed range is rejected outright rather than narrowed. Unlike one that merely runs
        // past the end of the file, there is no sensible window to clamp these to: the client asked
        // for something that isn't a range at all. The well-formed-but-unsatisfiable cases, which
        // are a 416, live in `testRangePastEndOfFileIs416`.
        try await withRangeServer { runner, _ in
            let malformed: [HTTPFields.Range.Value] = [
                // Negative bounds, for each of the three range shapes.
                .start(value: -20),
                .tail(value: -20),
                .within(start: -20, end: 25),
                // Inverted: the end precedes the start.
                .within(start: 25, end: 20),
            ]

            for range in malformed {
                var headers = HTTPFields()
                headers.range = .init(unit: .bytes, ranges: [range])
                let res = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res.status == .badRequest, "\(range.serialize())")
                // A 400 says nothing about the representation, so unlike a 416 it carries no
                // `Content-Range`.
                #expect(res.headers[.contentRange] == nil, "\(range.serialize())")
            }
        }
    }

    @Test("Every byte range against an empty file is unsatisfiable",
          .bug("https://github.com/vapor/vapor/issues/2991"))
    func testRangeAgainstEmptyFileIs416() async throws {
        let path = try await makeTemporaryFile(size: 0)
        defer { try? FileManager.default.removeItem(atPath: path) }
        try await withApp { app in
            app.get("file-stream") { req in
                try await app.fileio.streamFile(at: path, for: req)
            }
            try await app.test(method: .running()) { runner in
                for range in [HTTPFields.Range.Value.start(value: 0), .within(start: 0, end: 0), .tail(value: 10)] {
                    var headers = HTTPFields()
                    headers.range = .init(unit: .bytes, ranges: [range])
                    let res = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                    #expect(res.status == .rangeNotSatisfiable, "\(range.serialize())")
                    #expect(res.headers[.contentRange] == "bytes */0", "\(range.serialize())")
                }
            }
        }
    }

    @Test("FileMiddleware clamps a range past the end of the file too",
          .bug("https://github.com/vapor/vapor/issues/2991"))
    func testFileMiddlewareRangePastEndOfFile() async throws {
        // The issue was reported against `FileMiddleware`, which reaches the same range handling
        // through `FileIO`. Checked here so the fix can't regress for only one of the two entry points.
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let contents = try Data(contentsOf: directory.appendingPathComponent("Utilities/long-test-file.txt"))
        let size = contents.count

        try await withApp { app in
            app.middleware.use(FileMiddleware(publicDirectory: directory.path, etagCache: app.fileETagHashCache))

            try await app.test(method: .running()) { runner in
                var headers = HTTPFields()
                headers.range = .init(unit: .bytes, ranges: [.within(start: 64, end: size * 2)])
                let clamped = try await runner.sendRequest(.get, "/Utilities/long-test-file.txt", headers: headers)
                #expect(clamped.status == .partialContent)
                #expect(clamped.headers[.contentRange] == "bytes 64-\(size - 1)/\(size)")
                #expect(try await clamped.body.data() == Data(contents[64...]))

                headers.range = .init(unit: .bytes, ranges: [.start(value: size)])
                let unsatisfiable = try await runner.sendRequest(.get, "/Utilities/long-test-file.txt", headers: headers)
                #expect(unsatisfiable.status == .rangeNotSatisfiable)
                #expect(unsatisfiable.headers[.contentRange] == "bytes */\(size)")
            }
        }
    }

    @Test("Range resolution clamps and rejects the same way the file streamer does",
          .bug("https://github.com/vapor/vapor/issues/2991"))
    func testAsResponseContentRangeLeniency() throws {
        // The header-level API backing the streamer, checked directly so the semantics are pinned
        // without needing a server.
        #expect(try HTTPFields.Range.Value.within(start: 200, end: 1000)
            .asResponseContentRange(limit: 600) == .withinWithLimit(start: 200, end: 599, limit: 600))
        #expect(try HTTPFields.Range.Value.within(start: 0, end: 600)
            .asResponseContentRange(limit: 600) == .withinWithLimit(start: 0, end: 599, limit: 600))
        #expect(try HTTPFields.Range.Value.start(value: 200)
            .asResponseContentRange(limit: 600) == .withinWithLimit(start: 200, end: 599, limit: 600))
        #expect(try HTTPFields.Range.Value.tail(value: 1000)
            .asResponseContentRange(limit: 600) == .withinWithLimit(start: 0, end: 599, limit: 600))

        func expectStatus(_ status: HTTPResponse.Status, _ range: HTTPFields.Range.Value) {
            #expect(performing: {
                _ = try range.asResponseContentRange(limit: 600)
            }, throws: { error in
                (error as? Abort)?.status == status
            })
        }
        // Unsatisfiable: selects no bytes.
        expectStatus(.rangeNotSatisfiable, .start(value: 600))
        expectStatus(.rangeNotSatisfiable, .within(start: 600, end: 700))
        expectStatus(.rangeNotSatisfiable, .tail(value: 0))
        // Malformed: negative or inverted.
        expectStatus(.badRequest, .start(value: -1))
        expectStatus(.badRequest, .tail(value: -1))
        expectStatus(.badRequest, .within(start: -1, end: 10))
        expectStatus(.badRequest, .within(start: 10, end: 5))
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

            let size = try Data(contentsOf: URL(fileURLWithPath: #filePath)).count

            try await app.test(method: .running()) { runner in
                // An end of `Int.max` must not overflow when the served length is worked out. Since
                // vapor#2991 it is clamped to the last byte rather than rejected, so what this pins
                // is that the arithmetic stays safe on the lenient path too.
                var headers = HTTPFields()
                headers[.range] = "bytes=0-9223372036854775807"
                let res1 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res1.status == .partialContent)
                #expect(res1.headers[.contentRange] == "bytes 0-\(size - 1)/\(size)")

                // `bytes=1-10` is a satisfiable range on this file, so it's served as 206, not rejected.
                headers[.range] = "bytes=1-10"
                let res2 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res2.status == .partialContent)

                // Inverted: malformed, still a 400.
                headers[.range] = "bytes=100-10"
                let res3 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res3.status == .badRequest)

                // Negative end: malformed, still a 400.
                headers[.range] = "bytes=10--100"
                let res4 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res4.status == .badRequest)

                // Doesn't fit in an `Int`, so the header doesn't parse at all: a 400.
                headers[.range] = "bytes=9223372036854775808-"
                let res5 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res5.status == .badRequest)

                // A start far past the end selects no bytes: unsatisfiable, so a 416 since vapor#2991.
                headers[.range] = "bytes=922337203-"
                let res6 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res6.status == .rangeNotSatisfiable)
                #expect(res6.headers[.contentRange] == "bytes */\(size)")

                // A suffix far longer than the file selects all of it, again since vapor#2991.
                headers[.range] = "bytes=-922337203"
                let res7 = try await runner.sendRequest(.get, "/file-stream", headers: headers)
                #expect(res7.status == .partialContent)
                #expect(res7.headers[.contentRange] == "bytes 0-\(size - 1)/\(size)")

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

            try await app.testing(.running) { client in
                let res = try await client.send(ClientRequest(method: .head, url: "/file-stream"))

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

            try await app.testing(.running) { client in
                let get = try await client.get("/Utilities/foo.txt")
                #expect(get.status == .ok)
                try #expect(await (get.body.data()?.count ?? 0) > 0)

                // HEAD gets the headers a GET would have returned, with no body.
                let headRequest = ClientRequest(method: .head, url: "/Utilities/foo.txt")
                let head = try await client.send(headRequest)
                #expect(head.status == .ok)
                #expect(head.headers[.contentLength] == get.headers[.contentLength])
                try #expect(await head.body.data()?.count == 0)

                // Everything else falls through the middleware; nothing else is registered here,
                // so it 404s rather than being answered with the file.
                for method in [HTTPRequest.Method.options, .post, .delete] {
                    let request = ClientRequest(method: method, url: "/Utilities/foo.txt")
                    let res = try await client.send(request)
                    #expect(res.status == .notFound, "\(method) was served by FileMiddleware")
                }
            }
        }
    }
}
