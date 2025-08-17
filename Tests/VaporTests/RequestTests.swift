import NIOPosix
import Vapor
import NIOCore
import AsyncHTTPClient
import Atomics
import NIOConcurrencyHelpers
import Testing
import VaporTesting
import Foundation

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

            try await withRunningApp(app: app) { port throws in
                #expect(try await httpClient.get("http://localhost:\(port)/redirect_normal").status == .seeOther)
                #expect(try await httpClient.get("http://localhost:\(port)/redirect_permanent").status == .movedPermanently)
                #expect(try await httpClient.post("http://localhost:\(port)/redirect_temporary").status == .temporaryRedirect)
                #expect(try await httpClient.post("http://localhost:\(port)/redirect_permanentPost").status == .permanentRedirect)
            }

            try await httpClient.shutdown()
        }
    }

    @Test("Test Streaming Request", .disabled())
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
                var request = HTTPClientRequest(url: "http://localhost:\(port)/stream")
                request.method = .POST
                request.body = .stream(testValue.utf8.async, length: .unknown)

                let response: HTTPClientResponse = try await HTTPClient.shared.execute(request, timeout: .seconds(5))
                #expect(response.status == .ok)
                let body = try await response.body.collect(upTo: 1024 * 1024)
                #expect(body.string == testValue)
            }
        }
    }

    @Test("Test Streaming Request Body Cleanup", .disabled())
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

            app.environment.arguments = ["serve"]
            try await app.startup()

            let localAddress = try #require(app.http.server.shared.localAddress)
            let ip = try #require(localAddress.ipAddress)
            let port = try #require(localAddress.port)

            var oneMBBB = ByteBuffer(repeating: 0x41, count: 1024 * 1024)
            let oneMB = try #require(oneMBBB.readData(length: oneMBBB.readableBytes) as Data?)
            var request = HTTPClientRequest(url: "http://\(ip):\(port)/hello")
            request.method = .POST
            request.body = .stream(oneMB.async, length: .known(Int64(oneMB.count)))
            if let response = try? await HTTPClient.shared.execute(request, timeout: .seconds(5)) {
                #expect(bytesTheServerRead.load(ordering: .relaxed) > 0)
                #expect(response.status == .internalServerError)
            }
        }
    }

#warning("Try when new server working")
    // TODO: Re-enable once it reliably works and doesn't cause issues with trying to shut the application down
    // This may require some work in Vapor
    @Test("Test Request Body Backpressure Works with Async Streaming", .disabled())
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

            app.environment.arguments = ["serve"]
            try await app.startup()

            let localAddress = try #require(app.http.server.shared.localAddress)
            let ip = try #require(localAddress.ipAddress)
            let port = try #require(localAddress.port)

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
            let request = try! HTTPClient.Request(url: "http://\(ip):\(port)/hello",
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

    @Test("Test Large Body Collection Doesn't Crash", .bug("https://github.com/vapor/vapor/issues/2985"), .disabled())
    func testLargeBodyCollectionDoesntCrash() async throws {
        try await withApp { app in
            app.on(.post, "upload", body: .stream, use: { request async throws -> String  in
                let buffer = try await request.body.collect(upTo: Int.max)
                return "Received \(buffer.readableBytes) bytes"
            })

            try await withRunningApp(app: app) { port in
                let fiftyMB = ByteBuffer(repeating: 0x41, count: 600 * 1024 * 1024)
                var request = HTTPClientRequest(url: "http://localhost:\(port)/upload")
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

    @Test("Test Custom Host Address")
    func testCustomHostAddress() async throws {
        try await withApp { app in
            app.get("vapor", "is", "fun") {
                return $0.remoteAddress?.hostname ?? "n/a"
            }

            let ipV4Hostname = "127.0.0.1"
            try await app.testing(method: .running(hostname: ipV4Hostname, port: 0)).test(.get, "vapor/is/fun") { res in
                #expect(res.body.string == ipV4Hostname)
            }
        }
    }

    @Test("Test Request IDs are Unique")
    func testRequestIdsAreUnique() async throws {
        try await withApp { app in
            let request1 = Request(application: app, on: app.eventLoopGroup.next())
            let request2 = Request(application: app, on: app.eventLoopGroup.next())

            #expect(request1.id != request2.id)
        }
    }

    @Test("Test Request ID in Logger Metadata")
    func testRequestIdInLoggerMetadata() async throws {
        try await withApp { app in
            let request = Request(application: app, on: app.eventLoopGroup.next())
            guard case .string(let string) = request.logger[metadataKey: "request-id"] else {
                Issue.record("Did not find request-id key in logger metadata.")
                return
            }
            #expect(string == request.id)
        }
    }

    @Test("Test Request Peer Address Forwarded")
    func testRequestPeerAddressForwarded() async throws {
        try await withApp { app in
            app.get("remote") { req -> String in
                req.headers[.forwarded] = "for=192.0.2.60; proto=http; by=203.0.113.43"
                guard let peerAddress = req.peerAddress else {
                    return "n/a"
                }
                return peerAddress.description
            }

            try await app.testing(method: .running).test(.get, "remote") { res in
                #expect(res.body.string == "[IPv4]192.0.2.60:80")
            }
        }
    }

    @Test("Test Request Peer Address X-Forwarded-For")
    func testRequestPeerAddressXForwardedFor() async throws {
        try await withApp { app in
            app.get("remote") { req -> String in
                req.headers[.xForwardedFor] = "5.6.7.8"
                guard let peerAddress = req.peerAddress else {
                    return "n/a"
                }
                return peerAddress.description
            }

            try await app.testing(method: .running).test(.get, "remote") { res in
                #expect(res.body.string == "[IPv4]5.6.7.8:80")
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
                #expect(res.body.string.contains("[IPv4]\(ipV4Hostname)"))
            }
        }
    }

    @Test("Test Request Peer Address Multiple Headers Order")
    func testRequestPeerAddressMultipleHeadersOrder() async throws {
        try await withApp { app in
            app.get("remote") { req -> String in
                req.headers[.xForwardedFor] = "5.6.7.8"
                req.headers[.forwarded] = "for=192.0.2.60; proto=http; by=203.0.113.43"
                guard let peerAddress = req.peerAddress else {
                    return "n/a"
                }
                return peerAddress.description
            }

            let ipV4Hostname = "127.0.0.1"
            try await app.testing(method: .running(hostname: ipV4Hostname, port: 0)).test(.get, "remote") { res in
                #expect(res.body.string == "[IPv4]192.0.2.60:80")
            }
        }
    }

    @Test("Test Request ID Forwarding")
    func testRequestIdForwarding() async throws {
        try await withApp { app in
            app.get("remote") {
                if case .string(let string) = $0.logger[metadataKey: "request-id"], string == $0.id {
                    return string
                } else {
                    throw Abort(.notFound)
                }
            }

            try await app.testing(method: .running).test(.get, "remote", beforeRequest: { req in
                req.headers[.xRequestId] = "test"
            }, afterResponse: { res in
                #expect(res.body.string == "test")
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
                #expect(res.body.string.contains("IP"))
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
    func get(_ url: String) async throws -> HTTPClientResponse {
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        return try await self.execute(request, deadline: .now())
    }

    func post(_ url: String) async throws -> HTTPClientResponse {
        var request = HTTPClientRequest(url: url)
        request.method = .POST
        return try await self.execute(request, deadline: .now())
    }
}
