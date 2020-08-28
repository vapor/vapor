import XCTVapor

final class RequestTests: XCTestCase {
    
    func testCustomHostAdress() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }
        
        app.get("vapor", "is", "fun") {
            return $0.remoteAddress?.hostname ?? "n/a"
        }
        
        let ipV4Hostname = "127.0.0.1"
        try app.testable(method: .running(hostname: ipV4Hostname, port: 8080)).test(.GET, "vapor/is/fun") { res in
            XCTAssertEqual(res.body.string, ipV4Hostname)
        }
    }
    
    func testRequestRemoteAddress() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }
        
        app.get("remote") {
            $0.remoteAddress?.description ?? "n/a"
        }
        
        try app.testable(method: .running).test(.GET, "remote") { res in
            XCTAssertContains(res.body.string, "IP")
        }
    }

    func testURI() throws {
        do {
            var uri = URI(string: "http://vapor.codes/foo?bar=baz#qux")
            XCTAssertEqual(uri.scheme, "http")
            XCTAssertEqual(uri.host, "vapor.codes")
            XCTAssertEqual(uri.path, "/foo")
            XCTAssertEqual(uri.query, "bar=baz")
            XCTAssertEqual(uri.fragment, "qux")
            uri.query = "bar=baz&test=1"
            XCTAssertEqual(uri.string, "http://vapor.codes/foo?bar=baz&test=1#qux")
            uri.query = nil
            XCTAssertEqual(uri.string, "http://vapor.codes/foo#qux")
        }
        do {
            let uri = URI(string: "/foo/bar/baz")
            XCTAssertEqual(uri.path, "/foo/bar/baz")
        }
        do {
            let uri = URI(string: "ws://echo.websocket.org/")
            XCTAssertEqual(uri.scheme, "ws")
            XCTAssertEqual(uri.host, "echo.websocket.org")
            XCTAssertEqual(uri.path, "/")
        }
        do {
            let uri = URI(string: "http://foo")
            XCTAssertEqual(uri.scheme, "http")
            XCTAssertEqual(uri.host, "foo")
            XCTAssertEqual(uri.path, "")
        }
        do {
            let uri = URI(string: "foo")
            XCTAssertEqual(uri.scheme, "foo")
            XCTAssertEqual(uri.host, nil)
            XCTAssertEqual(uri.path, "")
        }
        do {
            let uri: URI = "/foo/bar/baz"
            XCTAssertEqual(uri.path, "/foo/bar/baz")
        }
        do {
            let foo = "foo"
            let uri: URI = "/\(foo)/bar/baz"
            XCTAssertEqual(uri.path, "/foo/bar/baz")
        }
        do {
            let uri = URI(scheme: "foo", host: "host", port: 1, path: "test", query: "query", fragment: "fragment")
            XCTAssertEqual(uri.string, "foo://host:1/test?query#fragment")
        }
        do {
            let bar = "bar"
            let uri = URI(scheme: "foo\(bar)", host: "host", port: 1, path: "test", query: "query", fragment: "fragment")
            XCTAssertEqual(uri.string, "foobar://host:1/test?query#fragment")
        }
        do {
            let uri = URI(scheme: "foo", host: "host", port: 1, path: "/test", query: "query", fragment: "fragment")
            XCTAssertEqual(uri.string, "foo://host:1/test?query#fragment")
        }
        do {
            let scheme = "foo"
            let uri = URI(scheme: scheme, host: "host", port: 1, path: "test", query: "query", fragment: "fragment")
            XCTAssertEqual(uri.string, "foo://host:1/test?query#fragment")
        }
        do {
            let scheme: String? = "foo"
            let uri = URI(scheme: scheme, host: "host", port: 1, path: "test", query: "query", fragment: "fragment")
            XCTAssertEqual(uri.string, "foo://host:1/test?query#fragment")
        }
        do {
            let uri = URI(scheme: .http, host: "host", port: 1, path: "test", query: "query", fragment: "fragment")
            XCTAssertEqual(uri.string, "http://host:1/test?query#fragment")
        }
        do {
            let uri = URI(scheme: nil, host: "host", port: 1, path: "test", query: "query", fragment: "fragment")
            XCTAssertEqual(uri.string, "host:1/test?query#fragment")
        }
        do {
            let uri = URI(scheme: URI.Scheme(), host: "host", port: 1, path: "test", query: "query", fragment: "fragment")
            XCTAssertEqual(uri.string, "host:1/test?query#fragment")
        }
        do {
            let uri = URI(host: "host", port: 1, path: "test", query: "query", fragment: "fragment")
            XCTAssertEqual(uri.string, "host:1/test?query#fragment")
        }
        do {
            let uri = URI(scheme: .httpUnixDomainSocket, host: "/path", path: "test", query: "query", fragment: "fragment")
            XCTAssertEqual(uri.string, "http+unix://%2Fpath/test?query#fragment")
        }
        do {
            let uri = URI(scheme: .httpUnixDomainSocket, host: "/path", path: "test", fragment: "fragment")
            XCTAssertEqual(uri.string, "http+unix://%2Fpath/test#fragment")
        }
        do {
            let uri = URI(scheme: .httpUnixDomainSocket, host: "/path", path: "test")
            XCTAssertEqual(uri.string, "http+unix://%2Fpath/test")
        }
        do {
            let uri = URI()
            XCTAssertEqual(uri.string, "/")
        }
    }
}
