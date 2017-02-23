import HTTP
import URI

extension Request {
    public static func makeTest(
        // request
        method: HTTP.Method,
        version: Version = Version(major: 1, minor: 1),
        headers: [HeaderKey: String] = [:],
        body: Body = .data([]),
        peerAddress: PeerAddress? = nil,
        // uri
        scheme: String = "",
        userInfo: URI.UserInfo? = nil,
        host: String = "0.0.0.0",
        port: Int? = nil,
        path: String = "",
        query: String? = nil,
        rawQuery: String? = nil,
        fragment: String? = nil,
        // onfail
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> Request {
        let uri = URI(
            scheme: scheme,
            userInfo: userInfo,
            host: host,
            port: port,
            path: path,
            query: query,
            rawQuery: rawQuery,
            fragment: fragment
        )
        do {
            return try Request(
                method: method,
                uri: uri,
                version: version,
                headers: headers,
                body: body,
                peerAddress: peerAddress
            )
        } catch {
            onFail("Failed to initialize request", file, line)
            throw TestingError.initRequestFailed
        }
    }
}
