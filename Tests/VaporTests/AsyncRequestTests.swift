import XCTVapor
import XCTest
import Vapor
import NIOCore
import NIOFoundationCompat
import AsyncHTTPClient
import Atomics
import NIOConcurrencyHelpers

fileprivate extension String {
    static func randomDigits(length: Int = 999) -> String {
        var string = ""
        for _ in 0...999 {
            string += String(Int.random(in: 0...9))
        }
        return string
    }
}

final class AsyncRequestTests: XCTestCase {
    
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
    }
    
    func testStreamingRequest() async throws {
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0
        
        let testValue = String.randomDigits()

        app.on(.POST, "stream", body: .stream) { req in
            var receivedBuffer = ByteBuffer()
            for try await part in req.body {
                XCTAssertNotNil(part)
                var part = part
                receivedBuffer.writeBuffer(&part)
            }
            let string = String(buffer: receivedBuffer)
            return string
        }

        app.environment.arguments = ["serve"]
        try await app.startup()
        
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let ip = localAddress.ipAddress,
              let port = localAddress.port else {
            return XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
        }
        
        var request = HTTPClientRequest(url: "http://\(ip):\(port)/stream")
        request.method = .POST
        request.body = .stream(testValue.utf8.async, length: .unknown)
        
        let response: HTTPClientResponse = try await app.http.client.shared.execute(request, timeout: .seconds(5))
        XCTAssertEqual(response.status, .ok)
        let body = try await response.body.collect(upTo: 1024 * 1024)
        XCTAssertEqual(body.string, testValue)
    }
    
    func testStreamingRequestBodyCleansUp() async throws {
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0
        
        let bytesTheServerRead = ManagedAtomic<Int>(0)
        
        app.on(.POST, "hello", body: .stream) { req async throws -> Response in
            var bodyIterator = req.body.makeAsyncIterator()
            let firstChunk = try await bodyIterator.next()
            bytesTheServerRead.wrappingIncrement(by: firstChunk?.readableBytes ?? 0, ordering: .relaxed)
            throw Abort(.internalServerError)
        }
        
        app.environment.arguments = ["serve"]
        try await app.startup()
        
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let ip = localAddress.ipAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        var oneMBBB = ByteBuffer(repeating: 0x41, count: 1024 * 1024)
        let oneMB = try XCTUnwrap(oneMBBB.readData(length: oneMBBB.readableBytes))
        var request = HTTPClientRequest(url: "http://\(ip):\(port)/hello")
        request.method = .POST
        request.body = .stream(oneMB.async, length: .known(Int64(oneMB.count)))
        if let response = try? await app.http.client.shared.execute(request, timeout: .seconds(5)) {
            XCTAssertGreaterThan(bytesTheServerRead.load(ordering: .relaxed), 0)
            XCTAssertEqual(response.status, .internalServerError)
        }
    }
    
    // TODO: Re-enable once it reliably works and doesn't cause issues with trying to shut the application down
    // This may require some work in Vapor
    func _testRequestBodyBackpressureWorksWithAsyncStreaming() async throws {
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0
        
        let numberOfTimesTheServerGotOfferedBytes = ManagedAtomic<Int>(0)
        let bytesTheServerSaw = ManagedAtomic<Int>(0)
        let bytesTheClientSent = ManagedAtomic<Int>(0)
        let serverSawEnd = ManagedAtomic<Bool>(false)
        let serverSawRequest = ManagedAtomic<Bool>(false)
        
        let requestHandlerTask: NIOLockedValueBox<Task<Response, Error>?> = .init(nil)
        
        app.on(.POST, "hello", body: .stream) { req async throws -> Response in
            requestHandlerTask.withLockedValue {
                $0 = Task {
                    XCTAssertTrue(serverSawRequest.compareExchange(expected: false, desired: true, ordering: .relaxed).exchanged)
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
        
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let ip = localAddress.ipAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }
        
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
        XCTAssertThrowsError(try httpClient.execute(request: request,
                                                                delegate: delegate,
                                                                deadline: .now() + .milliseconds(500)).wait()) { error in
            if let error = error as? HTTPClientError {
                XCTAssert(error == .readTimeout || error == .deadlineExceeded)
            } else {
                XCTFail("unexpected error: \(error)")
            }
        }
        
        XCTAssertEqual(1, numberOfTimesTheServerGotOfferedBytes.load(ordering: .sequentiallyConsistent))
        XCTAssertGreaterThanOrEqual(tenMB.readableBytes, bytesTheServerSaw.load(ordering: .sequentiallyConsistent))
        XCTAssertGreaterThanOrEqual(tenMB.readableBytes, bytesTheClientSent.load(ordering: .sequentiallyConsistent))
        XCTAssertEqual(0, bytesTheClientSent.load(ordering: .sequentiallyConsistent)) // We'd only see this if we sent the full 10 MB.
        XCTAssertFalse(serverSawEnd.load(ordering: .sequentiallyConsistent))
        XCTAssertTrue(serverSawRequest.load(ordering: .sequentiallyConsistent))
        
        requestHandlerTask.withLockedValue { $0?.cancel() }
        try await httpClient.shutdown()
    }

    // https://github.com/vapor/vapor/issues/2985
    func testLargeBodyCollectionDoesntCrash() async throws {
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0

        app.on(.POST, "upload", body: .stream, use: { request async throws -> String  in
            let buffer = try await request.body.collect(upTo: Int.max)
            return "Received \(buffer.readableBytes) bytes"
        })

        app.environment.arguments = ["serve"]
        try await app.startup()

        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard 
            let localAddress = app.http.server.shared.localAddress,
            let ip = localAddress.ipAddress,
            let port = localAddress.port 
        else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        let fiftyMB = ByteBuffer(repeating: 0x41, count: 600 * 1024 * 1024)
        var request = HTTPClientRequest(url: "http://\(ip):\(port)/upload")
        request.method = .POST
        request.body = .bytes(fiftyMB)

        for _ in 0..<10 {
            let response: HTTPClientResponse = try await app.http.client.shared.execute(request, timeout: .seconds(5))
            XCTAssertEqual(response.status, .ok)
            let body = try await response.body.collect(upTo: 1024 * 1024)
            XCTAssertEqual(body.string, "Received \(fiftyMB.readableBytes) bytes")
        }
    }

    func testCustomHostAddress() throws {
        app.get("vapor", "is", "fun") {
            return $0.remoteAddress?.hostname ?? "n/a"
        }

        let ipV4Hostname = "127.0.0.1"
        try app.testable(method: .running(hostname: ipV4Hostname, port: 0)).test(.GET, "vapor/is/fun") { res in
            XCTAssertEqual(res.body.string, ipV4Hostname)
        }
    }

    func testRequestIdsAreUnique() throws {
        let request1 = Request(application: app, on: app.eventLoopGroup.next())
        let request2 = Request(application: app, on: app.eventLoopGroup.next())

        XCTAssertNotEqual(request1.id, request2.id)
    }

    func testRequestIdInLoggerMetadata() throws {
        let request = Request(application: app, on: app.eventLoopGroup.next())
        guard case .string(let string) = request.logger[metadataKey: "request-id"] else {
            XCTFail("Did not find request-id key in logger metadata.")
            return
        }
        XCTAssertEqual(string, request.id)
    }

    func testRequestPeerAddressForwarded() throws {
        app.get("remote") { req -> String in
            req.headers.add(name: .forwarded, value: "for=192.0.2.60; proto=http; by=203.0.113.43")
            guard let peerAddress = req.peerAddress else {
                return "n/a"
            }
            return peerAddress.description
        }

        try app.testable(method: .running(port: 0)).test(.GET, "remote") { res in
            XCTAssertEqual(res.body.string, "[IPv4]192.0.2.60:80")
        }
    }

    func testRequestPeerAddressXForwardedFor() throws {
        app.get("remote") { req -> String in
            req.headers.add(name: .xForwardedFor, value: "5.6.7.8")
            guard let peerAddress = req.peerAddress else {
                return "n/a"
            }
            return peerAddress.description
        }

        try app.testable(method: .running(port: 0)).test(.GET, "remote") { res in
            XCTAssertEqual(res.body.string, "[IPv4]5.6.7.8:80")
        }
    }

    func testRequestPeerAddressRemoteAddress() throws {
        app.get("remote") { req -> String in
            guard let peerAddress = req.peerAddress else {
                return "n/a"
            }
            return peerAddress.description
        }

        let ipV4Hostname = "127.0.0.1"
        try app.testable(method: .running(hostname: ipV4Hostname, port: 0)).test(.GET, "remote") { res in
            XCTAssertContains(res.body.string, "[IPv4]\(ipV4Hostname)")
        }
    }

    func testRequestPeerAddressMultipleHeadersOrder() throws {
        app.get("remote") { req -> String in
            req.headers.add(name: .xForwardedFor, value: "5.6.7.8")
            req.headers.add(name: .forwarded, value: "for=192.0.2.60; proto=http; by=203.0.113.43")
            guard let peerAddress = req.peerAddress else {
                return "n/a"
            }
            return peerAddress.description
        }

        let ipV4Hostname = "127.0.0.1"
        try app.testable(method: .running(hostname: ipV4Hostname, port: 0)).test(.GET, "remote") { res in
            XCTAssertEqual(res.body.string, "[IPv4]192.0.2.60:80")
        }
    }

    func testRequestIdForwarding() throws {
         app.get("remote") {
            if case .string(let string) = $0.logger[metadataKey: "request-id"], string == $0.id {
                return string
            } else {
                throw Abort(.notFound)
            }
        }

        try app.testable(method: .running(port: 0)).test(.GET, "remote", beforeRequest: { req in
            req.headers.add(name: .xRequestId, value: "test")
        }, afterResponse: { res in
            XCTAssertEqual(res.body.string, "test")
        })
    }

    func testRequestRemoteAddress() throws {
        app.get("remote") {
            $0.remoteAddress?.description ?? "n/a"
        }

        try app.testable(method: .running(port: 0)).test(.GET, "remote") { res in
            XCTAssertContains(res.body.string, "IP")
        }
    }

    func testRedirect() throws {
        app.http.client.configuration.redirectConfiguration = .disallow

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

        try app.server.start(address: .hostname("localhost", port: 0))
        defer { app.server.shutdown() }

        let port = try XCTUnwrap(app.http.server.shared.localAddress?.port, "Failed to get port")

        XCTAssertEqual(
            try app.client.get("http://localhost:\(port)/redirect_normal").wait().status,
            .seeOther
        )
        XCTAssertEqual(
            try app.client.get("http://localhost:\(port)/redirect_permanent").wait().status,
            .movedPermanently
        )
        XCTAssertEqual(
            try app.client.post("http://localhost:\(port)/redirect_temporary").wait().status,
            .temporaryRedirect
        )
        XCTAssertEqual(
            try app.client.post("http://localhost:\(port)/redirect_permanentPost").wait().status,
            .permanentRedirect
        )
    }
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
