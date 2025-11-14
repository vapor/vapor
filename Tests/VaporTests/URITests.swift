import Vapor
import NIOCore
import Algorithms
import Testing

@Suite("URI Test")
struct URITests {
    @Test("Test Basic Construction")
    func testBasicConstruction() {
        expectURIString(
            "https://user:pass@vapor.codes:1234/foo?bar=baz#qux",
            hasScheme: "https",
            hasUserinfo: "user:pass",
            hasHost: "vapor.codes",
            hasPort: 1234,
            hasPath: "/foo",
            hasQuery: "bar=baz",
            hasFragment: "qux"
        )
        expectURIComponents(
            scheme: "https",
            userinfo: "user:pass",
            host: "vapor.codes",
            port: 1234,
            path: "/foo",
            query: "bar=baz",
            fragment: "qux",
            generate: "https://user:pass@vapor.codes:1234/foo?bar=baz#qux"
        )

        expectURIString("wss://echo.websocket.org/", hasScheme: "wss", hasHost: "echo.websocket.org", hasPath: "/")
        expectURIComponents(scheme: "wss", host: "echo.websocket.org", path: "/", generate: "wss://echo.websocket.org/")
    }

    @Test("Test Semicolon Is Not Encoded In Path Component")
    func testSemicolonIsNotEncodedInPathComponent() {
        expectURIString(
            "https://user:pass@vapor.codes:1234/foo;?bar=abcd%3B%C3%A4%2B;efg#qux%3B",
            hasScheme: "https",
            hasUserinfo: "user:pass",
            hasHost: "vapor.codes",
            hasPort: 1234,
            hasPath: "/foo;",
            hasQuery: "bar=abcd%3B%C3%A4%2B;efg",
            hasFragment: "qux%3B"
        )
    }

    @Test("Test Mutation")
    func testMutation() {
        var uri = URI(string: "https://user:pass@vapor.codes:1234/foo?bar=baz#qux")
    
        // Mutate query
        uri.query = "bar=baz&test=1"
        #expect(uri.string == "https://user:pass@vapor.codes:1234/foo?bar=baz&test=1#qux")

        // Remove query
        uri.query = nil
        #expect(uri.string == "https://user:pass@vapor.codes:1234/foo#qux")
    }

    @Test("Test Path Strings")
    func testPathStrings() {
        // Absolute path string
        let uri = URI(string: "/foo/bar/baz")
        #expect(uri.path == "/foo/bar/baz")
    }

    @Test("Test Non Absolute Path")
    func testNonAbsolutePath() {
        let uri = URI(string: "foo")

        // N.B.: This test previously asserted that the _scheme_ of the resulting URI was `foo`. This was
        // a semantically incorrect parse (per RFC 3986) and should have been considered a bug; hence it
        // is not considered source-breaking to have fixed it.
        #expect(uri.scheme == nil)
        #expect(uri.host == nil)
        #expect(uri.path == "foo")
    }

    @Test("Test String Interpolation")
    func testStringInterpolation() {
        let foo = "foo"
        #expect(("/\(foo)/bar/baz" as URI).path == "/foo/bar/baz")

        let bar = "bar"
        let uri = URI(scheme: "foo\(bar)", host: "host", port: 1, path: "test", query: "query", fragment: "fragment")
        #expect(uri.string == "foobar://host:1/test?query#fragment")
    }

    @Test("Test Various Schemes and Weird Hosts")
    func testVariousSchemesAndWeirdHosts() {
        // N.B.: This test previously asserted that the resulting string did _not_ start with the `//` "authority"
        // prefix. Again, according to RFC 3986, this was always semantically incorrect.
        expectURIComponents(
            host: "host", port: 1, path: "/test", query: "query", fragment: "fragment",
            generate: "//host:1/test?query#fragment"
        )

        expectURIComponents(
            scheme: .httpUnixDomainSocket, host: "/path", path: "/test",
            generate: "http+unix://%2Fpath/test"
        )
        expectURIComponents(
            scheme: .httpUnixDomainSocket, host: "/path", path: "/test", fragment: "fragment",
            generate: "http+unix://%2Fpath/test#fragment"
        )
        expectURIComponents(
            scheme: .httpUnixDomainSocket, host: "/path", path: "/test", query: "query", fragment: "fragment",
            generate: "http+unix://%2Fpath/test?query#fragment"
        )
    }

    @Test("Test Default Initializer")
    func testDefaultInitializer() {
        let uri = URI.init()
        #expect(uri.string == "/")
    }

    @Test("Test Overlong URI Parsing")
    func testOverlongURIParsing() {
        let zeros = String(repeating: "0", count: 65_512)
        let untrustedInput = "[https://vapor.codes.somewhere-else.test:](https://vapor.codes.somewhere-else.test/\(zeros)443)[\(zeros)](https://vapor.codes.somewhere-else.test/\(zeros)443)[443](https://vapor.codes.somewhere-else.test/\(zeros)443)"
    
        let readableInAssertionOutput = untrustedInput
            .replacingOccurrences(of: zeros, with: "00...00")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let uri = URI(string: untrustedInput)

        #expect(uri.scheme == nil)
        #expect(uri.userinfo == nil)
        #expect(uri.host == nil)
        #expect(uri.port == nil)
        #expect(uri.query == nil)
        #expect(uri.fragment == nil)
        if #available(macOS 14, iOS 17, watchOS 10, tvOS 17, *) {
            // TODO: It is not clear why the "encode the first colon as %3A but none of the others" behavior appears, and why only on Darwin
            #expect(
                uri.path.replacingOccurrences(of: zeros, with: "00...00").replacing("%3A", with: ":", maxReplacements: 1) ==
                readableInAssertionOutput.replacing("%3A", with: ":", maxReplacements: 1)
            )
        } else {
            #expect(uri.path == "/")
        }
    }

    @Test("Test URL Parsing Vectors")
    func testUrlParsingVectors() {
        expectURIString("file:///usr/local/bin", hasScheme: "file", hasPath: "/usr/local/bin")
        expectURIString("file:/usr/local/bin", hasScheme: "file", hasHost: nil, hasPath: "/usr/local/bin")
        expectURIString("file://localhost/usr/local/bin", hasScheme: "file", hasHost: "localhost", hasPath: "/usr/local/bin")
        expectURIString("file://usr/local/bin", hasScheme: "file", hasHost: "usr", hasPath: "/local/bin")
        expectURIString("/usr/local/bin", hasHost: nil, hasPath: "/usr/local/bin")
        expectURIString("file://localhost/usr/local/bin/", hasScheme: "file", hasHost: "localhost", hasPath: "/usr/local/bin/")
        expectURIString("file://localhost/", hasScheme: "file", hasHost: "localhost", hasPath: "/")
        expectURIString("file:///", hasScheme: "file", hasPath: "/")
        expectURIString("file:/", hasScheme: "file", hasHost: nil, hasPath: "/")
        expectURIString("file:///Volumes", hasScheme: "file", hasPath: "/Volumes")
        expectURIString("file:///Users/darin", hasScheme: "file", hasPath: "/Users/darin")
        expectURIString("file:/", hasScheme: "file", hasHost: nil, hasPath: "/")
        expectURIString("file:///.", hasScheme: "file", hasPath: "/.")
        expectURIString("file:///./.", hasScheme: "file", hasPath: "/./.")
        expectURIString("file:///.///.", hasScheme: "file", hasPath: "/.///.")
        expectURIString("file:///a/..", hasScheme: "file", hasPath: "/a/..")
        expectURIString("file:///a/b/..", hasScheme: "file", hasPath: "/a/b/..")
        expectURIString("file:///a/b//..", hasScheme: "file", hasPath: "/a/b//..")
        expectURIString("file:///./a/b/..", hasScheme: "file", hasPath: "/./a/b/..")
        expectURIString("file:///a/./b/..", hasScheme: "file", hasPath: "/a/./b/..")
        expectURIString("file:///a/b/./..", hasScheme: "file", hasPath: "/a/b/./..")
        expectURIString("file:///a///b//..", hasScheme: "file", hasPath: "/a///b//..")
        expectURIString("file:///a/b/../..", hasScheme: "file", hasPath: "/a/b/../..")
        expectURIString("file:///a/b/c/../..", hasScheme: "file", hasPath: "/a/b/c/../..")
        expectURIString("file:///a/../b/..", hasScheme: "file", hasPath: "/a/../b/..")
        expectURIString("file:///a/../b/../c", hasScheme: "file", hasPath: "/a/../b/../c")
        expectURIString("file:///a/../b/../c", hasScheme: "file", hasPath: "/a/../b/../c")
        expectURIString("ftp://ftp.gnu.org/", hasScheme: "ftp", hasHost: "ftp.gnu.org", hasPath: "/")
        expectURIString("ftp://ftp.gnu.org/pub/gnu", hasScheme: "ftp", hasHost: "ftp.gnu.org", hasPath: "/pub/gnu")
        expectURIString("ftp://luser@ftp.gnu.org/pub/gnu",
            hasScheme: "ftp", hasUserinfo: "luser", hasHost: "ftp.gnu.org", hasPath: "/pub/gnu"
        )
        expectURIString("ftp://@ftp.gnu.org/pub/gnu", hasScheme: "ftp", hasUserinfo: "", hasHost: "ftp.gnu.org", hasPath: "/pub/gnu")
        expectURIString("ftp://luser:password@ftp.gnu.org/pub/gnu",
            hasScheme: "ftp", hasUserinfo: "luser:password", hasHost: "ftp.gnu.org", hasPath: "/pub/gnu"
        )
        expectURIString("ftp://:password@ftp.gnu.org/pub/gnu",
            hasScheme: "ftp", hasUserinfo: ":password", hasHost: "ftp.gnu.org", hasPath: "/pub/gnu"
        )
        expectURIString("ftp://ftp.gnu.org:72/pub/gnu", hasScheme: "ftp", hasHost: "ftp.gnu.org", hasPort: 72, hasPath: "/pub/gnu")
        expectURIString("ftp://:72/pub/gnu", hasScheme: "ftp", hasHost: "", hasPort: 72, hasPath: "/pub/gnu")
        expectURIString("http://localhost/usr/local/bin/", hasScheme: "http", hasHost: "localhost", hasPath: "/usr/local/bin/")
        expectURIString("http://localhost/", hasScheme: "http", hasHost: "localhost", hasPath: "/")
        expectURIString("http://www.apple.com/", hasScheme: "http", hasHost: "www.apple.com", hasPath: "/")
        expectURIString("http://www.apple.com/dir", hasScheme: "http", hasHost: "www.apple.com", hasPath: "/dir")
        expectURIString("http://www.apple.com/dir/", hasScheme: "http", hasHost: "www.apple.com", hasPath: "/dir/")
        expectURIString("http://darin:nothin@www.apple.com:42/dir/",
            hasScheme: "http", hasUserinfo: "darin:nothin", hasHost: "www.apple.com", hasPort: 42, hasPath: "/dir/"
        )
        expectURIString("http:/", hasScheme: "http", hasHost: nil, hasPath: "/")
        expectURIString("http://www.apple.com/query?email=darin@apple.com",
            hasScheme: "http", hasHost: "www.apple.com", hasPath: "/query", hasQuery: "email=darin@apple.com"
        )
        expectURIString("HTTP://WWW.ZOO.COM/", hasScheme: "HTTP", hasHost: "WWW.ZOO.COM", hasPath: "/")
        expectURIString("HTTP://WWW.ZOO.COM/ED", hasScheme: "HTTP", hasHost: "WWW.ZOO.COM", hasPath: "/ED")
        expectURIString("http://groups.google.com/groups?as_uauthors=joe@blow.com&as_scoring=d&hl=en",
            hasScheme: "http", hasHost: "groups.google.com", hasPath: "/groups", hasQuery: "as_uauthors=joe@blow.com&as_scoring=d&hl=en"
        )
        expectURIString("http://my.site.com/some/page.html#fragment",
            hasScheme: "http", hasHost: "my.site.com", hasPath: "/some/page.html", hasFragment: "fragment"
        )
        expectURIString("scheme://user:pass@host:1/path/path2/file.html;params?query#fragment",
            hasScheme: "scheme", hasUserinfo: "user:pass", hasHost: "host", hasPort: 1, hasPath: "/path/path2/file.html;params",
            hasQuery: "query", hasFragment: "fragment", hasEqualString: false
        )
        expectURIString("http://test.com/a%20space", hasScheme: "http", hasHost: "test.com", hasPath: "/a%20space")
        expectURIString("http://test.com/aBrace%7B", hasScheme: "http", hasHost: "test.com", hasPath: "/aBrace%7B")
        expectURIString("http://test.com/aJ%4a", hasScheme: "http", hasHost: "test.com", hasPath: "/aJ%4a")
        expectURIString("file:///%3F", hasScheme: "file", hasPath: "/%3F")
        expectURIString("file:///%78", hasScheme: "file", hasPath: "/%78")
        expectURIString("file:///?", hasScheme: "file", hasPath: "/", hasQuery: "")
        expectURIString("file:///&", hasScheme: "file", hasPath: "/&")
        expectURIString("file:///x", hasScheme: "file", hasPath: "/x")
        expectURIString("http:///%3F", hasScheme: "http", hasPath: "/%3F")
        expectURIString("http:///%78", hasScheme: "http", hasPath: "/%78")
        expectURIString("http:///?", hasScheme: "http", hasPath: "/", hasQuery: "")
        expectURIString("http:///&", hasScheme: "http", hasPath: "/&")
        expectURIString("http:///x", hasScheme: "http", hasPath: "/x")
        expectURIString("glorb:///%3F", hasScheme: "glorb", hasPath: "/%3F")
        expectURIString("glorb:///%78", hasScheme: "glorb", hasPath: "/%78")
        expectURIString("glorb:///?", hasScheme: "glorb", hasPath: "/", hasQuery: "")
        expectURIString("glorb:///&", hasScheme: "glorb", hasPath: "/&")
        expectURIString("glorb:///x", hasScheme: "glorb", hasPath: "/x")
        expectURIString("uahsfcncvuhrtgvnahr", hasHost: nil, hasPath: "uahsfcncvuhrtgvnahr")
        expectURIString("http://[fe80::20a:27ff:feae:8b9e]/", hasScheme: "http", hasHost: "[fe80::20a:27ff:feae:8b9e]", hasPath: "/")
        expectURIString("http://[fe80::20a:27ff:feae:8b9e%25en0]/", hasScheme: "http", hasHost: "[fe80::20a:27ff:feae:8b9e%25en0]", hasPath: "/")
        expectURIString("http://host.com/foo/bar/../index.html", hasScheme: "http", hasHost: "host.com", hasPath: "/foo/bar/../index.html")
        expectURIString("http://host.com/foo/bar/./index.html", hasScheme: "http", hasHost: "host.com", hasPath: "/foo/bar/./index.html")
        expectURIString("http:/cgi-bin/Count.cgi?ft=0", hasScheme: "http", hasHost: nil, hasPath: "/cgi-bin/Count.cgi", hasQuery: "ft=0")
        expectURIString("file://///", hasScheme: "file", hasPath: "///")
        expectURIString("file:/Volumes", hasScheme: "file", hasHost: nil, hasPath: "/Volumes")
        expectURIString("/Volumes", hasHost: nil, hasPath: "/Volumes")
        expectURIString(".", hasHost: nil, hasPath: ".")
        expectURIString("./a", hasHost: nil, hasPath: "./a")
        expectURIString("../a", hasHost: nil, hasPath: "../a")
        expectURIString("../../a", hasHost: nil, hasPath: "../../a")
        expectURIString("/", hasHost: nil, hasPath: "/")
        expectURIString("http://a/b/c/./g", hasScheme: "http", hasHost: "a", hasPath: "/b/c/./g")
        expectURIString("http://a/b/c/.", hasScheme: "http", hasHost: "a", hasPath: "/b/c/.")
        expectURIString("http://a/b/c/./", hasScheme: "http", hasHost: "a", hasPath: "/b/c/./")
        expectURIString("http://a/b/c/..", hasScheme: "http", hasHost: "a", hasPath: "/b/c/..")
        expectURIString("http://a/b/c/../", hasScheme: "http", hasHost: "a", hasPath: "/b/c/../")
        expectURIString("http://a/b/c/../g", hasScheme: "http", hasHost: "a", hasPath: "/b/c/../g")
        expectURIString("http://a/b/c/../..", hasScheme: "http", hasHost: "a", hasPath: "/b/c/../..")
        expectURIString("http://a/b/c/../../", hasScheme: "http", hasHost: "a", hasPath: "/b/c/../../")
        expectURIString("http://a/b/c/../../g", hasScheme: "http", hasHost: "a", hasPath: "/b/c/../../g")
        expectURIString("http://a/b/c/../../../g", hasScheme: "http", hasHost: "a", hasPath: "/b/c/../../../g")
        expectURIString("http://a/b/c/../../../../g", hasScheme: "http", hasHost: "a", hasPath: "/b/c/../../../../g")
        expectURIString("http://a/b/c/./g", hasScheme: "http", hasHost: "a", hasPath: "/b/c/./g")
        expectURIString("http://a/b/c/../g", hasScheme: "http", hasHost: "a", hasPath: "/b/c/../g")
        expectURIString("http://a/b/c/g.", hasScheme: "http", hasHost: "a", hasPath: "/b/c/g.")
        expectURIString("http://a/b/c/.g", hasScheme: "http", hasHost: "a", hasPath: "/b/c/.g")
        expectURIString("http://a/b/c/g..", hasScheme: "http", hasHost: "a", hasPath: "/b/c/g..")
        expectURIString("http://a/b/c/..g", hasScheme: "http", hasHost: "a", hasPath: "/b/c/..g")
        expectURIString("http://a/b/c/./../g", hasScheme: "http", hasHost: "a", hasPath: "/b/c/./../g")
        expectURIString("http://a/b/c/./g/.", hasScheme: "http", hasHost: "a", hasPath: "/b/c/./g/.")
        expectURIString("http://a/b/c/g/./h", hasScheme: "http", hasHost: "a", hasPath: "/b/c/g/./h")
        expectURIString("http://a/b/c/g/../h", hasScheme: "http", hasHost: "a", hasPath: "/b/c/g/../h")
        expectURIString("http://a/b/c/g;x=1/./y", hasScheme: "http", hasHost: "a", hasPath: "/b/c/g;x=1/./y", hasEqualString: false)
        expectURIString("http://a/b/c/g;x=1/../y", hasScheme: "http", hasHost: "a", hasPath: "/b/c/g;x=1/../y", hasEqualString: false)
        expectURIString("http://a/b/c/g?y/./x", hasScheme: "http", hasHost: "a", hasPath: "/b/c/g", hasQuery: "y/./x")
        expectURIString("http://a/b/c/g?y/../x", hasScheme: "http", hasHost: "a", hasPath: "/b/c/g", hasQuery: "y/../x")
        expectURIString("http://a/b/c/g#s/./x", hasScheme: "http", hasHost: "a", hasPath: "/b/c/g", hasFragment: "s/./x")
        expectURIString("http://a/b/c/g#s/../x", hasScheme: "http", hasHost: "a", hasPath: "/b/c/g", hasFragment: "s/../x")
        expectURIString("http://a/../../x", hasScheme: "http", hasHost: "a", hasPath: "/../../x")
        expectURIString("http://a/..///../x", hasScheme: "http", hasHost: "a", hasPath: "/..///../x")
    }
}

func expectURIComponents(
       scheme: @autoclosure () throws -> URI.Scheme?,
     userinfo: @autoclosure () throws -> String? = nil,
         host: @autoclosure () throws -> String? = nil,
         port: @autoclosure () throws -> Int?    = nil,
         path: @autoclosure () throws -> String,
        query: @autoclosure () throws -> String? = nil,
     fragment: @autoclosure () throws -> String? = nil,
     generate expected: @autoclosure () throws -> String,
       _ message: @autoclosure () -> Testing.Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation
) {
    expectURIComponents(
        scheme: try scheme()?.value,
        userinfo: try userinfo(),
        host: try host(),
        port: try port(),
        path: try path(),
        query: try query(),
        fragment: try fragment(),
        generate: try expected(),
        message(),
        sourceLocation: sourceLocation
    )
}

func expectURIComponents(
       scheme: @autoclosure () throws -> String? = nil,
     userinfo: @autoclosure () throws -> String? = nil,
         host: @autoclosure () throws -> String? = nil,
         port: @autoclosure () throws -> Int?    = nil,
         path: @autoclosure () throws -> String,
        query: @autoclosure () throws -> String? = nil,
     fragment: @autoclosure () throws -> String? = nil,
     generate expected: @autoclosure () throws -> String,
    _ message: @autoclosure () -> Testing.Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation
) {
    do {
        let messageString = message().testDescription
        let scheme = try scheme(), rawuserinfo = try userinfo(), host = try host(), port = try port(),
            path = try path(), query = try query(), fragment = try fragment()
        let uri = URI(scheme: scheme, userinfo: rawuserinfo, host: host, port: port, path: path, query: query, fragment: fragment)

        let userinfo = rawuserinfo.map {
            !$0.contains(":") ? $0 :
                $0.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).enumerated()
                  .map { $1.addingPercentEncoding(withAllowedCharacters: $0 == 0 ? .urlUserAllowed : .urlPasswordAllowed)! }
                  .joined(separator: ":")
        }

        // All components should be identical to their input counterparts with percent encoding.
        #expect(uri.scheme ==   scheme,   "(scheme) \(messageString)", sourceLocation: sourceLocation)
        #expect(uri.userinfo == userinfo, "(userinfo) \(messageString)", sourceLocation: sourceLocation)
        #expect(uri.host ==     host?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),     "(host) \(messageString)", sourceLocation: sourceLocation)
        #expect(uri.port ==     port,     "(port) \(messageString)", sourceLocation: sourceLocation)
        #expect(uri.path ==     path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),     "(path) \(messageString)", sourceLocation: sourceLocation)
        #expect(uri.query ==    query?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),    "(query) \(messageString)", sourceLocation: sourceLocation)
        #expect(uri.fragment == fragment?.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed), "(fragment) \(messageString)", sourceLocation: sourceLocation)

        // The URI's generated string should match the expected input.
        #expect(try uri.string == expected(), "(string) \(messageString)", sourceLocation: sourceLocation)
    } catch {
        Issue.record(error, message(), sourceLocation: sourceLocation)
    }
}

func expectURIString(
     _ string: @autoclosure () throws -> String,
     hasScheme scheme:     @autoclosure () throws -> String? = nil,
     hasUserinfo userinfo: @autoclosure () throws -> String? = nil,
     hasHost host:         @autoclosure () throws -> String? = "",
     hasPort port:         @autoclosure () throws -> Int?    = nil,
     hasPath path:         @autoclosure () throws -> String,
     hasQuery query:       @autoclosure () throws -> String? = nil,
     hasFragment fragment: @autoclosure () throws -> String? = nil,
     hasEqualString exact: @autoclosure () throws -> Bool = true,
     _ message: @autoclosure () -> Testing.Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation
) {
    do {
        let string = try string()
        let uri = URI(string: string)
        let messageString = message().testDescription

        // Each component should match its expected value.
        #expect(try uri.scheme ==   scheme(),   "(scheme) \(messageString)", sourceLocation: sourceLocation)
        #expect(try uri.userinfo == userinfo(), "(userinfo) \(messageString)", sourceLocation: sourceLocation)
        #expect(try uri.host ==     host(),     "(host) \(messageString)", sourceLocation: sourceLocation)
        #expect(try uri.port ==     port(),     "(port) \(messageString)", sourceLocation: sourceLocation)
        #expect(try uri.path ==     path(),     "(path) \(messageString)", sourceLocation: sourceLocation)
        #expect(try uri.query ==    query(),    "(query) \(messageString)", sourceLocation: sourceLocation)
        #expect(try uri.fragment == fragment(), "(fragment) \(messageString)", sourceLocation: sourceLocation)

        // The URI's generated string should come out identical to the input string, unless explicitly stated otherwise.
        if try exact() {
            #expect(uri.string ==   string,     "(string) \(messageString)", sourceLocation: sourceLocation)
        }
    } catch {
        Issue.record(error, message(), sourceLocation: sourceLocation)
    }
}
