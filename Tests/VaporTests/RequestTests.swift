import NIOPosix
import Vapor
import NIOCore
import AsyncHTTPClient
import Atomics
import NIOConcurrencyHelpers
import Testing
import VaporTesting
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPTypes
import NIOHTTP1
import NIOHTTPTypesHTTP1
import RoutingKit
import NIOFoundationEssentialsCompat
import Logging

@Suite("Request Tests")
struct RequestTests {
    @Test("Test Redirect", .timeLimit(.minutes(1)))
    func testRedirect() async throws {
        try await withApp { app in
            let httpClient = HTTPClient(eventLoopGroupProvider: .singleton, configuration: .init(redirectConfiguration: .disallow))

            app.get("redirect_normal") {
                $0.redirect(to: "foo", redirectType: .normal)
            }
            app.get("redirect_permanent") {
                $0.redirect(to: "foo", redirectType: .permanent)
            }
            app.post("redirect_temporary") {
                $0.redirect(to: "foo", redirectType: .temporary)
            }
            app.post("redirect_permanentPost") {
                $0.redirect(to: "foo", redirectType: .permanentPost)
            }

            do {
                try await withRunningApp(app: app) { port throws in
                    #expect(try await httpClient.get("http://127.0.0.1:\(port)/redirect_normal").status == .seeOther)
                    #expect(try await httpClient.get("http://127.0.0.1:\(port)/redirect_permanent").status == .movedPermanently)
                    #expect(try await httpClient.post("http://127.0.0.1:\(port)/redirect_temporary").status == .temporaryRedirect)
                    #expect(try await httpClient.post("http://127.0.0.1:\(port)/redirect_permanentPost").status == .permanentRedirect)
                }
            } catch {
                try await httpClient.shutdown()
                throw error
            }

            try await httpClient.shutdown()
        }
    }

    @Test("Test Streaming Request")
    func testStreamingRequest() async throws {
        try await withApp { app in
            let testValue = String.randomDigits()

            app.on(.post, "stream", body: .stream) { req in
                var receivedBuffer = ByteBuffer()
                for try await part in req.body {
                    var part = part
                    receivedBuffer.writeBuffer(&part)
                }
                let string = String(buffer: receivedBuffer)
                return string
            }

            try await withRunningApp(app: app) { port in
                var request = HTTPClientRequest(url: "http://127.0.0.1:\(port)/stream")
                request.method = .POST
                request.body = .stream(testValue.utf8.async, length: .unknown)

                let response: HTTPClientResponse = try await HTTPClient.shared.execute(request, timeout: .seconds(5))
                #expect(response.status == .ok)
                let body = try await response.body.collect(upTo: 1024 * 1024)
                #expect(body.string == testValue)
            }
        }
    }

    @Test("Test Streaming Request Is Echoed Back As A Streaming Response")
    func testStreamingRequestEcho() async throws {
        try await withApp { app in
            let testValue = String.randomDigits()

            // Read the streamed request body chunk by chunk and write each chunk straight back
            // out as the streamed response body, exercising request streaming and response
            // streaming together in a single round-trip.
            app.on(.post, "echo", body: .stream) { req -> Response in
                Response(body: .init(stream: { writer in
                    for try await chunk in req.body {
                        try await writer.write(chunk.readableBytesView)
                    }
                }))
            }

            try await withRunningApp(app: app) { port in
                var request = HTTPClientRequest(url: "http://127.0.0.1:\(port)/echo")
                request.method = .POST
                request.body = .stream(testValue.utf8.async, length: .unknown)

                let response: HTTPClientResponse = try await HTTPClient.shared.execute(request, timeout: .seconds(5))
                #expect(response.status == .ok)
                let body = try await response.body.collect(upTo: 1024 * 1024)
                #expect(body.string == testValue)
            }
        }
    }

    @Test("Test Streaming Request Content Decoding", .timeLimit(.minutes(1)))
    func testStreamingRequestContentDecoding() async throws {
        struct Payload: Content, Equatable {
            var message: String
        }

        try await withApp { app in
            app.on(.post, "stream-decode", body: .stream) { req async throws -> String in
                // NOTE: dropped an upstream `#expect(req.body.data != nil)` here — with lazy request
                // streaming the body isn't buffered until `content.decode` collects it. Flagged for
                // @0xTim (test added in #3552). See PR description.
                return try await req.content.decode(Payload.self).message
            }

            try await withRunningApp(app: app) { port in
                let testValue = String.randomDigits()
                let json = #"{"message":"\#(testValue)"}"#

                var request = HTTPClientRequest(url: "http://127.0.0.1:\(port)/stream-decode")
                request.method = .POST
                request.headers.add(name: "content-type", value: "application/json")
                request.body = .stream(json.utf8.async, length: .unknown)

                // Not a measurement of how fast this has to be: a budget tight enough to catch a
                // loaded machine fails for that reason instead of a real one, which is how this
                // test failed in CI. The `.timeLimit` on the test is the real backstop.
                let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
                #expect(response.status == .ok)
                let body = try await response.body.collect(upTo: 1024 * 1024)
                #expect(body.string == testValue)
            }
        }
    }

    @Test("Test Streaming Request Body Cleanup")
    func testStreamingRequestBodyCleansUp() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            let bytesTheServerRead = ManagedAtomic<Int>(0)

            app.on(.post, "hello", body: .stream) { req async throws -> Response in
                var bodyIterator = req.body.makeAsyncIterator()
                let firstChunk = try await bodyIterator.next()
                bytesTheServerRead.wrappingIncrement(by: firstChunk?.readableBytes ?? 0, ordering: .relaxed)
                throw Abort(.internalServerError)
            }

            try await withRunningApp(app: app) { port in
                var oneMBBB = ByteBuffer(repeating: 0x41, count: 1024 * 1024)
                let oneMB = try #require(oneMBBB.readData(length: oneMBBB.readableBytes) as Data?)
                var request = HTTPClientRequest(url: "http://127.0.0.1:\(port)/hello")
                request.method = .POST
                request.body = .stream(oneMB.async, length: .known(Int64(oneMB.count)))
                if let response = try? await HTTPClient.shared.execute(request, timeout: .seconds(5)) {
                    #expect(bytesTheServerRead.load(ordering: .relaxed) > 0)
                    #expect(response.status == .internalServerError)
                }
            }
        }
    }

    @Test("Test Request Body Backpressure Works with Async Streaming")
    func testRequestBodyBackpressureWorksWithAsyncStreaming() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            let numberOfTimesTheServerGotOfferedBytes = ManagedAtomic<Int>(0)
            let bytesTheServerSaw = ManagedAtomic<Int>(0)
            let bytesTheClientSent = ManagedAtomic<Int>(0)
            let serverSawEnd = ManagedAtomic<Bool>(false)
            let serverSawRequest = ManagedAtomic<Bool>(false)

            let requestHandlerTask: NIOLockedValueBox<Task<Response, any Error>?> = .init(nil)

            app.on(.post, "hello", body: .stream) { req async throws -> Response in
                requestHandlerTask.withLockedValue {
                    $0 = Task {
                        #expect(serverSawRequest.compareExchange(expected: false, desired: true, ordering: .relaxed).exchanged == true)
                        var bodyIterator = req.body.makeAsyncIterator()
                        let firstChunk = try await bodyIterator.next() // read only first chunk
                        numberOfTimesTheServerGotOfferedBytes.wrappingIncrement(ordering: .sequentiallyConsistent)
                        bytesTheServerSaw.wrappingIncrement(by: firstChunk?.readableBytes ?? 0, ordering: .sequentiallyConsistent)
                        defer {
                            _ = bodyIterator // make sure to not prematurely cancelling the sequence
                        }
                        try await Task.sleep(nanoseconds: 10_000_000_000) // wait "forever"
                        serverSawEnd.store(true, ordering: .sequentiallyConsistent)
                        return Response(status: .ok)
                    }
                }

                do {
                    let task = requestHandlerTask.withLockedValue { $0 }
                    return try await task!.value
                } catch {
                    throw Abort(.internalServerError)
                }
            }

            try await withRunningApp(app: app) { port in
                final class ResponseDelegate: HTTPClientResponseDelegate {
                    typealias Response = Void

                    private let bytesTheClientSent: ManagedAtomic<Int>

                    init(bytesTheClientSent: ManagedAtomic<Int>) {
                        self.bytesTheClientSent = bytesTheClientSent
                    }

                    func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Response {
                        return ()
                    }

                    func didSendRequestPart(task: HTTPClient.Task<Response>, _ part: IOData) {
                        self.bytesTheClientSent.wrappingIncrement(by: part.readableBytes, ordering: .sequentiallyConsistent)
                    }
                }

                let tenMB = ByteBuffer(repeating: 0x41, count: 10 * 1024 * 1024)
                let request = try! HTTPClient.Request(url: "http://127.0.0.1:\(port)/hello",
                                                      method: .POST,
                                                      headers: [:],
                                                      body: .byteBuffer(tenMB))
                let delegate = ResponseDelegate(bytesTheClientSent: bytesTheClientSent)
                let httpClient = HTTPClient(eventLoopGroup: MultiThreadedEventLoopGroup.singleton)
                await #expect(performing: {
                    try await httpClient.execute(request: request, delegate: delegate, deadline: .now() + .milliseconds(500)).get()

                }, throws: { error in
                    let httpClientError = try #require(error as? HTTPClientError)
                    return httpClientError == HTTPClientError.readTimeout || httpClientError == HTTPClientError.deadlineExceeded
                })

                #expect(numberOfTimesTheServerGotOfferedBytes.load(ordering: .sequentiallyConsistent) == 1)
                #expect(tenMB.readableBytes >= bytesTheServerSaw.load(ordering: .sequentiallyConsistent))
                #expect(tenMB.readableBytes >= bytesTheClientSent.load(ordering: .sequentiallyConsistent))
                #expect(bytesTheClientSent.load(ordering: .sequentiallyConsistent) == 0) // We'd only see this if we sent the full 10 MB.
                #expect(serverSawEnd.load(ordering: .sequentiallyConsistent) == false)
                #expect(serverSawRequest.load(ordering: .sequentiallyConsistent) == true)

                requestHandlerTask.withLockedValue { $0?.cancel() }
                try await httpClient.shutdown()
            }
        }
    }

    @Test("Test Large Body Collection Doesn't Crash", .bug("https://github.com/vapor/vapor/issues/2985"))
    func testLargeBodyCollectionDoesntCrash() async throws {
        try await withApp { app in
            app.on(.post, "upload", body: .stream, use: { request async throws -> String  in
                let buffer = try await request.body.collect(max: Int.max) ?? ByteBuffer()
                return "Received \(buffer.readableBytes) bytes"
            })

            try await withRunningApp(app: app) { port in
                let fiftyMB = ByteBuffer(repeating: 0x41, count: 600 * 1024 * 1024)
                var request = HTTPClientRequest(url: "http://127.0.0.1:\(port)/upload")
                request.method = .POST
                request.body = .bytes(fiftyMB)

                for _ in 0..<10 {
                    let response: HTTPClientResponse = try await HTTPClient.shared.execute(request, timeout: .seconds(5))
                    #expect(response.status == .ok)
                    let body = try await response.body.collect(upTo: 1024 * 1024)
                    #expect(body.string == "Received \(fiftyMB.readableBytes) bytes")
                }
            }
        }
    }

    @Test("Test Empty Streaming Request Body")
    func testEmptyStreamingRequestBody() async throws {
        try await withApp { app in
            // Streaming a request with no body must simply produce zero chunks, not hang or fail.
            app.on(.post, "count", body: .stream) { req -> String in
                var total = 0
                for try await chunk in req.body {
                    total += chunk.readableBytes
                }
                return "\(total)"
            }

            try await withRunningApp(app: app) { port in
                var request = HTTPClientRequest(url: "http://localhost:\(port)/count")
                request.method = .POST

                let response: HTTPClientResponse = try await HTTPClient.shared.execute(request, timeout: .seconds(5))
                #expect(response.status == .ok)
                let body = try await response.body.collect(upTo: 1024 * 1024)
                #expect(body.string == "0")
            }
        }
    }

    @Test("Test Large Multi-Chunk Streaming Request Body Is Fully Received")
    func testLargeMultiChunkStreamingRequest() async throws {
        let bodySize = 4 * 1024 * 1024
        try await withApp { app in
            // Read a multi-megabyte streamed body chunk by chunk and report the total size, so the
            // test fails if any chunk is dropped or the reassembly across reads is wrong.
            app.on(.post, "count", body: .stream) { req -> String in
                var total = 0
                for try await chunk in req.body {
                    total += chunk.readableBytes
                }
                return "\(total)"
            }

            try await withRunningApp(app: app) { port in
                var request = HTTPClientRequest(url: "http://localhost:\(port)/count")
                request.method = .POST
                request.body = .bytes(ByteBuffer(repeating: 0x41, count: bodySize))

                let response: HTTPClientResponse = try await HTTPClient.shared.execute(request, timeout: .seconds(10))
                #expect(response.status == .ok)
                let body = try await response.body.collect(upTo: 1024 * 1024)
                #expect(body.string == "\(bodySize)")
            }
        }
    }

    @Test("Test Server Survives A Handler That Ignores The Streamed Request Body")
    func testServerSurvivesHandlerIgnoringStreamedBody() async throws {
        try await withApp { app in
            // The handler returns without reading the request body. For a body within the drain
            // limit the server drains it so the keep-alive connection stays usable for the next
            // request. (An oversized unread body is handled by closing the connection instead —
            // see `testUnknownRouteWithLargeBodyDoesNotHang`.)
            app.on(.post, "ignore", body: .stream) { _ in "ignored" }
            app.get("ok") { _ in "ok" }

            try await withRunningApp(app: app) { port in
                var request = HTTPClientRequest(url: "http://localhost:\(port)/ignore")
                request.method = .POST
                request.body = .bytes(ByteBuffer(repeating: 0x41, count: 4 * 1024))

                let response: HTTPClientResponse = try await HTTPClient.shared.execute(request, timeout: .seconds(10))
                #expect(response.status == .ok)
                #expect(try await response.body.collect(upTo: 1024 * 1024).string == "ignored")

                // The server must keep serving subsequent requests.
                let ok = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://localhost:\(port)/ok"), timeout: .seconds(10))
                #expect(ok.status == .ok)
                #expect(try await ok.body.collect(upTo: 1024 * 1024).string == "ok")
            }
        }
    }

    @Test("Test Collecting A Streaming Body Over The Max Returns 413")
    func testStreamingBodyExceedingCollectMaxReturns413() async throws {
        try await withApp { app in
            // Collecting a streamed body with an explicit limit must abort with 413 once the body
            // exceeds it, and the server must stay alive for later requests. The body is kept small
            // (over the collect limit but within the drain limit) so the unread remainder is drained
            // and the 413 is delivered on a reusable connection rather than racing a close.
            app.on(.post, "limited", body: .stream) { req -> String in
                _ = try await req.body.collect(max: 1024)
                return "ok"
            }
            app.get("ok") { _ in "ok" }

            try await withRunningApp(app: app) { port in
                var request = HTTPClientRequest(url: "http://localhost:\(port)/limited")
                request.method = .POST
                request.body = .bytes(ByteBuffer(repeating: 0x41, count: 2048))

                let response: HTTPClientResponse = try await HTTPClient.shared.execute(request, timeout: .seconds(10))
                #expect(response.status.code == 413)

                // The server must keep serving subsequent requests.
                let ok = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://localhost:\(port)/ok"), timeout: .seconds(10))
                #expect(ok.status == .ok)
                #expect(try await ok.body.collect(upTo: 1024 * 1024).string == "ok")
            }
        }
    }

    @Test("Test Collecting A Streaming Body Is Accepted At The Max And Rejected One Byte Over")
    func testStreamingBodyCollectMaxBoundary() async throws {
        let maxSize = 1024
        try await withApp { app in
            // Collect with an explicit limit and report the byte count so we can assert the exact
            // boundary: a body of exactly `maxSize` is accepted, one byte more is rejected with 413.
            app.on(.post, "limited", body: .stream) { req -> String in
                let buffer = try await req.body.collect(max: maxSize) ?? ByteBuffer()
                return "\(buffer.readableBytes)"
            }

            try await withRunningApp(app: app) { port in
                var atLimit = HTTPClientRequest(url: "http://localhost:\(port)/limited")
                atLimit.method = .POST
                atLimit.body = .bytes(ByteBuffer(repeating: 0x41, count: maxSize))
                let accepted = try await HTTPClient.shared.execute(atLimit, timeout: .seconds(10))
                #expect(accepted.status == .ok)
                #expect(try await accepted.body.collect(upTo: 1024 * 1024).string == "\(maxSize)")

                var overLimit = HTTPClientRequest(url: "http://localhost:\(port)/limited")
                overLimit.method = .POST
                overLimit.body = .bytes(ByteBuffer(repeating: 0x41, count: maxSize + 1))
                let rejected = try await HTTPClient.shared.execute(overLimit, timeout: .seconds(10))
                #expect(rejected.status.code == 413)
            }
        }
    }

    @Test("Test Unknown Route With A Large Body Is Not Fully Drained")
    func testUnknownRouteWithLargeBodyDoesNotHang() async throws {
        try await withApp { app in
            // No route matches POST /unknown, so it 404s without reading the body. The server must
            // answer promptly and stay alive without draining the whole (large) upload — otherwise an
            // unknown route would be a trivial DoS vector.
            app.get("known") { _ in "ok" }

            try await withRunningApp(app: app) { port in
                var unknown = HTTPClientRequest(url: "http://localhost:\(port)/unknown")
                unknown.method = .POST
                unknown.body = .bytes(ByteBuffer(repeating: 0x41, count: 50 * 1024 * 1024))

                // Because the server refuses to read the whole body, it closes the connection rather
                // than draining 50 MB — so the client sees either a 404 or a dropped connection.
                // Both are fine; the point is the request resolves quickly (no unbounded drain) and
                // the server stays up. A hang would trip the timeout and fail here.
                _ = try? await HTTPClient.shared.execute(unknown, timeout: .seconds(10))

                // The server must keep serving subsequent requests.
                let ok = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://localhost:\(port)/known"), timeout: .seconds(10))
                #expect(ok.status == .ok)
                #expect(try await ok.body.collect(upTo: 1024 * 1024).string == "ok")
            }
        }
    }

    @Test("Test The Drain Limit Is Method-Aware (GET/HEAD Never Consume A Body)")
    func testDrainLimitIsMethodAware() async throws {
        try await withApp { app in
            // Unknown paths (404) so no `.collect` gate consumes the body first — the unread body
            // reaches the handler's `defer` drain, which is what we're exercising. A raw socket lets
            // us see whether the server kept the connection alive or closed it.
            try await withRunningApp(app: app) { port in
                let body = String(repeating: "A", count: 128)

                // GET/HEAD → drain budget 0: any body is left unread, so the server closes the connection.
                let get = try await rawExchange(
                    port: port,
                    rawRequest: "GET /nope HTTP/1.1\r\nHost: localhost\r\nContent-Length: \(body.count)\r\n\r\n\(body)")
                #expect(get.serverClosed)

                let head = try await rawExchange(
                    port: port,
                    rawRequest: "HEAD /nope HTTP/1.1\r\nHost: localhost\r\nContent-Length: \(body.count)\r\n\r\n\(body)")
                #expect(head.serverClosed)

                // A body-less GET/HEAD drains nothing (just reads `.end`), so the connection stays alive.
                let bodylessHead = try await rawExchange(
                    port: port,
                    rawRequest: "HEAD /nope HTTP/1.1\r\nHost: localhost\r\n\r\n")
                #expect(!bodylessHead.serverClosed)

                // POST → drain budget is the (large default) limit: 128 bytes are drained, so the
                // connection stays alive.
                let post = try await rawExchange(
                    port: port,
                    rawRequest: "POST /nope HTTP/1.1\r\nHost: localhost\r\nContent-Length: \(body.count)\r\n\r\n\(body)")
                #expect(!post.serverClosed)
            }
        }
    }

    @Test("Test Draining Stops Once The Configured Budget Is Exceeded")
    func testDrainStopsOverConfiguredBudget() async throws {
        try await withApp { app in
            app.serverConfiguration.maxDrainBytes = 8

            try await withRunningApp(app: app) { port in
                // Over the 8-byte budget → the server stops draining and closes the connection.
                let big = String(repeating: "A", count: 128)
                let over = try await rawExchange(
                    port: port,
                    rawRequest: "POST /nope HTTP/1.1\r\nHost: localhost\r\nContent-Length: \(big.count)\r\n\r\n\(big)")
                #expect(over.serverClosed)

                // Within the budget → fully drained, connection stays alive.
                let small = "AAAA"
                let under = try await rawExchange(
                    port: port,
                    rawRequest: "POST /nope HTTP/1.1\r\nHost: localhost\r\nContent-Length: \(small.count)\r\n\r\n\(small)")
                #expect(!under.serverClosed)
            }
        }
    }

    @Test("Test Collecting Rejects When The Declared Content-Length Exceeds The Max")
    func testCollectRejectsWhenDeclaredContentLengthExceedsMax() async throws {
        try await withApp { app in
            // A collected body sets Content-Length to its own size. Declaring 2048 while collecting
            // with a 1024 limit must be rejected up front with 413.
            let request = Request(
                method: .post,
                collectedBody: ByteBuffer(repeating: 0x41, count: 2048))

            await #expect(performing: {
                _ = try await request.body.collect(max: 1024)
            }, throws: { error in
                (error as? any AbortError)?.status.code == 413
            })
        }
    }

    @Test("Test Collecting Rejects On The Declared Content-Length Before Reading The Body")
    func testCollectRejectsOnDeclaredContentLengthBeforeReadingBody() async throws {
        try await withApp { app in
            // No body is attached (storage is `.none`, which would normally collect to `nil`), but the
            // request claims a huge Content-Length. The reject must fire from the header check *before*
            // the storage switch — proving it's the declared length, not the bytes, that drives it.
            var request = Request(method: .post)
            request.headers[.contentLength] = "1000000"

            await #expect(performing: {
                _ = try await request.body.collect(max: 1024)
            }, throws: { error in
                (error as? any AbortError)?.status.code == 413
            })
        }
    }

    @Test("Test Collecting Accepts When The Declared Content-Length Is Within The Max")
    func testCollectAcceptsWhenDeclaredContentLengthWithinMax() async throws {
        try await withApp { app in
            // A declared length at or under the limit must not be rejected: the body collects normally.
            let request = Request(
                method: .post,
                collectedBody: ByteBuffer(repeating: 0x41, count: 512))

            let collected = try await request.body.collect(max: 1024)
            #expect(collected?.readableBytes == 512)
        }
    }

    @Test("Test Collecting With No Max Never Rejects On Content-Length")
    func testCollectWithNilMaxDoesNotRejectOnContentLength() async throws {
        try await withApp { app in
            // `max: nil` means no limit, so even a large declared Content-Length must pass the check
            // and collect the whole body.
            let request = Request(
                method: .post,
                collectedBody: ByteBuffer(repeating: 0x41, count: 2048))

            let collected = try await request.body.collect(max: nil)
            #expect(collected?.readableBytes == 2048)
        }
    }

    @Test("Test Custom Host Address")
    func testCustomHostAddress() async throws {
        try await withApp { app in
            app.get("vapor", "is", "fun") {
                return $0.remoteAddress?.hostname ?? "n/a"
            }

            let ipV4Hostname = "127.0.0.1"
            try await app.testing(method: .running(hostname: ipV4Hostname, port: 0)).test(.get, "vapor/is/fun") { res in
                try #expect(await res.body.requireString() == ipV4Hostname)
            }
        }
    }

    @Test("Test Request IDs are Unique")
    func testRequestIdsAreUnique() async throws {
        try await withApp { app in
            let request1 = Request()
            let request2 = Request()

            #expect(request1.id != request2.id)
        }
    }

    @Test("Test Request ID in Logger Metadata")
    func testRequestIdInLoggerMetadata() async throws {
        try await withApp { app in
            app.get("remote") { req -> String in
                guard case .string(let string) = Logger.current[metadataKey: "request-id"] else {
                    Issue.record("Did not find request-id key in logger metadata.")
                    throw Abort(.notFound)
                }
                #expect(string == req.id)
                return req.id
            }

            try await app.testing(method: .running).test(.get, "remote") { res in
                #expect(res.status == .ok)
            }
        }
    }

    @Test("Test Request Peer Address Forwarded")
    func testRequestPeerAddressForwarded() async throws {
        try await withApp { app in
            app.get("remote") { request -> String in
                var req = request
                req.headers[.forwarded] = "for=192.0.2.60; proto=http; by=203.0.113.43"
                guard let peerAddress = req.peerAddress else {
                    return "n/a"
                }
                return peerAddress.description
            }

            try await app.testing(method: .running).test(.get, "remote") { res in
                try #expect(await res.body.requireString() == "[IPv4]192.0.2.60:80")
            }
        }
    }

    @Test("Test Request Peer Address X-Forwarded-For")
    func testRequestPeerAddressXForwardedFor() async throws {
        try await withApp { app in
            app.get("remote") { request -> String in
                var req = request
                req.headers[.xForwardedFor] = "5.6.7.8"
                guard let peerAddress = req.peerAddress else {
                    return "n/a"
                }
                return peerAddress.description
            }

            try await app.testing(method: .running).test(.get, "remote") { res in
                try #expect(await res.body.requireString() == "[IPv4]5.6.7.8:80")
            }
        }
    }

    @Test("Test Request Peer Address Remote Address")
    func testRequestPeerAddressRemoteAddress() async throws {
        try await withApp { app in
            app.get("remote") { req -> String in
                guard let peerAddress = req.peerAddress else {
                    return "n/a"
                }
                return peerAddress.description
            }

            let ipV4Hostname = "127.0.0.1"
            try await app.testing(method: .running(hostname: ipV4Hostname, port: 0)).test(.get, "remote") { res in
                try #expect(await res.body.requireString().contains("[IPv4]\(ipV4Hostname)"))
            }
        }
    }

    @Test("Test Request Peer Address Multiple Headers Order")
    func testRequestPeerAddressMultipleHeadersOrder() async throws {
        try await withApp { app in
            app.get("remote") { request -> String in
                var req = request
                req.headers[.xForwardedFor] = "5.6.7.8"
                req.headers[.forwarded] = "for=192.0.2.60; proto=http; by=203.0.113.43"
                guard let peerAddress = req.peerAddress else {
                    return "n/a"
                }
                return peerAddress.description
            }

            let ipV4Hostname = "127.0.0.1"
            try await app.testing(method: .running(hostname: ipV4Hostname, port: 0)).test(.get, "remote") { res in
                try #expect(await res.body.requireString() == "[IPv4]192.0.2.60:80")
            }
        }
    }

    @Test("Test Request ID Forwarding")
    func testRequestIdForwarding() async throws {
        try await withApp { app in
            app.get("remote") {
                if case .string(let string) = Logger.current[metadataKey: "request-id"], string == $0.id {
                    return string
                } else {
                    throw Abort(.notFound)
                }
            }

            try await app.testing(method: .running).test(.get, "remote", beforeRequest: { req in
                req.headers[.xRequestId] = "test"
            }, afterResponse: { res in
                try #expect(await res.body.requireString() == "test")
            })
        }
    }

    @Test("Test Request Remote Address")
    func testRequestRemoteAddress() async throws {
        try await withApp { app in
            app.get("remote") {
                $0.remoteAddress?.description ?? "n/a"
            }

            try await app.testing(method: .running).test(.get, "remote") { res in
                try #expect(await res.body.requireString().contains("IP"))
            }
        }
    }

//    @Test("Test Collected Body Drain")
//    func testCollectedBodyDrain() throws {
//        try await withApp { app in
//            let request = Request(
//                application: app,
//                collectedBody: .init(string: ""),
//                on: app.eventLoopGroup.any()
//            )
//
//            let handleBufferExpectation = XCTestExpectation()
//            let endDrainExpectation = XCTestExpectation()
//
//            request.body.drain { part in
//                switch part {
//                case .buffer:
//                    return request.eventLoop.makeFutureWithTask {
//                        handleBufferExpectation.fulfill()
//                    }
//                case .error:
//                    XCTAssertTrue(false)
//                    return request.eventLoop.makeSucceededVoidFuture()
//                case .end:
//                    endDrainExpectation.fulfill()
//                    return request.eventLoop.makeSucceededVoidFuture()
//                }
//            }
//
//            self.wait(for: [handleBufferExpectation, endDrainExpectation], timeout: 1.0, enforceOrder: true)
//        }
//    }
}

// This was taken from AsyncHTTPClients's AsyncRequestTests.swift code.
// The license for the original work is reproduced below. See NOTICES.txt for
// more.

//===----------------------------------------------------------------------===//
//
// This source file is part of the AsyncHTTPClient open source project
//
// Copyright (c) 2022 Apple Inc. and the AsyncHTTPClient project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of AsyncHTTPClient project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

struct AsyncLazySequence<Base: Sequence>: AsyncSequence {
    typealias Element = Base.Element
    struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: Base.Iterator
        init(iterator: Base.Iterator) {
            self.iterator = iterator
        }

        mutating func next() async throws -> Base.Element? {
            self.iterator.next()
        }
    }

    var base: Base

    init(base: Base) {
        self.base = base
    }

    func makeAsyncIterator() -> AsyncIterator {
        .init(iterator: self.base.makeIterator())
    }
}

extension AsyncLazySequence: Sendable where Base: Sendable {}
extension AsyncLazySequence.AsyncIterator: Sendable where Base.Iterator: Sendable {}

extension Sequence {
    /// Turns `self` into an `AsyncSequence` by vending each element of `self` asynchronously.
    var async: AsyncLazySequence<Self> {
        .init(base: self)
    }
}

fileprivate extension String {
    static func randomDigits(length: Int = 999) -> String {
        var string = ""
        for _ in 0...999 {
            string += String(Int.random(in: 0...9))
        }
        return string
    }
}

extension HTTPClient {
    func get(_ url: String, headers: HTTPFields = .init()) async throws -> HTTPClientResponse {
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers = HTTPHeaders(headers)
        return try await self.execute(request, deadline: .distantFuture)
    }

    func post(_ url: String, body: ByteBuffer? = nil) async throws -> HTTPClientResponse {
        var request = HTTPClientRequest(url: url)
        request.method = .POST
        if let body = body {
            request.body = .bytes(body)
        }
        return try await self.execute(request, deadline: .distantFuture)
    }
}
