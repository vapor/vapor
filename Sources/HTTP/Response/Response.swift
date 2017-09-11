import Foundation
import Core

/// An HTTP response.
///
/// Used to respond to a request from an HTTP client.
///
///     200 OK HTTP/1.1
///     Content-Length: 5
///
///     hello
///
/// The HTTP server will stream incoming requests from clients.
/// You must handle these requests and generate responses.
///
/// When you want to request data from another server, such as
/// calling another API from your application, you will create
/// a request and use the HTTP client to prompt a response
/// from the remote server.
///
///     let res = Response(status: .ok, body: "hello")
///
/// See Message
public final class Response: Message {
    /// See Message.version
    public var version: Version

    /// HTTP response status code.
    public var status: Status

    /// See Message.headers
    public var headers: Headers

    /// See Message.body
    public var body: Body {
        didSet { updateContentLength() }
    }

    /// See Extendable.extend
    public var extend: Extend

    /// Create a new HTTP response.
    public init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: Headers = Headers(),
        body: Body = Body()
    ) {
        self.version = version
        self.status = status
        self.headers = headers
        self.body = body
        self.extend = Extend()
        updateContentLength()
    }
}

extension Response {
    /// Create a new HTTP response using something BodyRepresentable.
    public convenience init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: Headers = Headers(),
        body: BodyRepresentable
    ) throws {
        try self.init(version: version, status: status, headers: headers, body: body.makeBody())
    }
}

/// Can be converted from a response.
public protocol ResponseInitializable {
    init(response: Response) throws
}

/// Can be converted to a response
public protocol ResponseRepresentable {
    func makeResponse() throws -> Response
}

/// Can be converted from and to a response
public typealias ResponseConvertible = ResponseInitializable & ResponseRepresentable

// MARK: Response Conformance

extension Response: ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return self
    }
}
