import XCTVapor
import XCTest
import Vapor
import NIOCore

final class RequestTests: XCTestCase {
    
    func testCustomHostAddress() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("vapor", "is", "fun") {
            return $0.remoteAddress?.hostname ?? "n/a"
        }
        
        let ipV4Hostname = "127.0.0.1"
        try app.testable(method: .running(hostname: ipV4Hostname, port: 0)).test(.GET, "vapor/is/fun") { res in
            XCTAssertEqual(res.body.string, ipV4Hostname)
        }
    }
    
    func testRequestIdsAreUnique() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let request1 = Request(application: app, on: app.eventLoopGroup.next())
        let request2 = Request(application: app, on: app.eventLoopGroup.next())
        
        XCTAssertNotEqual(request1.id, request2.id)
    }

    func testRequestIdInLoggerMetadata() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let request = Request(application: app, on: app.eventLoopGroup.next())
        guard case .string(let string) = request.logger[metadataKey: "request-id"] else {
            XCTFail("Did not find request-id key in logger metadata.")
            return
        }
        XCTAssertEqual(string, request.id)
    }

    func testRequestPeerAddressForwarded() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

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
        let app = Application(.testing)
        defer { app.shutdown() }

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

    func testRequestPeerAddressRemoteAddres() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

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
        let app = Application(.testing)
        defer { app.shutdown() }

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
        let app = Application(.testing)
        defer { app.shutdown() }

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
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("remote") {
            $0.remoteAddress?.description ?? "n/a"
        }
        
        try app.testable(method: .running(port: 0)).test(.GET, "remote") { res in
            XCTAssertContains(res.body.string, "IP")
        }
    }

    func testRedirect() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
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
        
        guard let port = app.http.server.shared.localAddress?.port else {
            XCTFail("Failed to get port for app")
            return
        }
        
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
    
    @available(*, deprecated, message: "Testing deprecated methods; this attribute silences the warnings")
    func testRedirect_old() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.http.client.configuration.redirectConfiguration = .disallow

        // DO NOT fix these warnings.
        // This is intentional to make sure the deprecated functions still work.
        app.get("redirect_normal") {
            $0.redirect(to: "foo", type: .normal)
        }
        app.get("redirect_permanent") {
            $0.redirect(to: "foo", type: .permanent)
        }
        app.post("redirect_temporary") {
            $0.redirect(to: "foo", type: .temporary)
        }
        
        try app.server.start(address: .hostname("localhost", port: 0))
        defer { app.server.shutdown() }
        
        guard let port = app.http.server.shared.localAddress?.port else {
            XCTFail("Failed to get port for app")
            return
        }
        
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
    }
    
    func testCollectedBodyDrain() throws {
        let app = Application()
        defer { app.shutdown() }

        let request = Request(
            application: app,
            collectedBody: .init(string: ""),
            on: app.eventLoopGroup.any()
        )
        
        let handleBufferExpectation = XCTestExpectation()
        let endDrainExpectation = XCTestExpectation()
        
        request.body.drain { part in
            switch part {
            case .buffer:
                return request.eventLoop.makeFutureWithTask {
                    handleBufferExpectation.fulfill()
                }
            case .error:
                XCTAssertTrue(false)
                return request.eventLoop.makeSucceededVoidFuture()
            case .end:
                endDrainExpectation.fulfill()
                return request.eventLoop.makeSucceededVoidFuture()
            }
        }
        
        self.wait(for: [handleBufferExpectation, endDrainExpectation], timeout: 1.0, enforceOrder: true)
    }
}
