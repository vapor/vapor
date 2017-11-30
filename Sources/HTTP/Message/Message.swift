import Async
import Dispatch
import Service

/// An HTTP message.
/// This is the basis of HTTP request and response,
/// and has the general structure of:
///
///     <status line> HTTP/1.1
///     Content-Lengt: 5
///     Foo: Bar
///
///     hello
///
/// Note: the status line contains information that
/// differentiates requests and responses.
///
/// If the status line contains an HTTP method and URI
/// it is a request.
///
/// If the status line contains an HTTP status code
/// it is a response.
///
/// This protocol is useful for adding methods to both
/// requests and responses, such as the ability to serialize
/// Content to both message types.
///
/// HTTP messages conform to Extendable which allows you
/// to add your own stored properties to requests and responses
/// that can be accessed simply by importing the module that
/// adds them. This is how much of Vapor's functionality is created.
public protocol Message: Codable, CustomDebugStringConvertible, EphemeralWorker {
    /// The HTTP version of this message.
    var version: Version { get set }
    /// The HTTP headers.
    var headers: Headers { get set }
    /// The message body.
    var body: Body { get set }
}

// MARK: Queue

extension Message {
    /// This message's event loop.
    ///
    /// All async tasks (such as completing or awaiting futures)
    /// must be performed on this queue.
    ///
    /// Make sure not to block this queue as it will
    /// block all other requests on the queue.
    public var eventLoop: EventLoop {
        get { return extend["http:eventLoop"] as? EventLoop ?? .default }
        set { return extend["http:eventLoop"] = newValue }
    }
}

// MARK: Debug string

extension Message {
    /// A debug description for this HTTP message.
    public var debugDescription: String {
        var desc: [String] = []

        desc.append("HTTP.\(Self.self)")
        for header in headers {
            desc.append("\(header.name): \(header.value)")
        }

        return desc.joined(separator: "\n")
    }
}
