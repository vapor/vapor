import Async
import Dispatch

/// Capable of responding to a request.
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/responder/)
public protocol Responder {
    func respond(to req: Request) throws -> Future<Response>
}

extension Responder {
    /// Creates a stream from this responder capable of being
    /// added to a server or client stream.
    public func makeStream() -> ResponderStream {
        return ResponderStream(responder: self)
    }
}

/// A stream containing an HTTP responder.
public final class ResponderStream: Async.Stream {
    /// See InputStream.Input
    public typealias Input = Request

    /// See OutputStream.Output
    public typealias Output = Response

    /// See BaseStream.errorStream
    public var errorStream: ErrorHandler?

    // See BaseStream.outputStream
    public var outputStream: OutputHandler?

    /// The responder
    let responder: Responder

    /// Create a new response stream.
    /// The responses will be awaited on the supplied queue.
    public init(responder: Responder) {
        self.responder = responder
    }

    /// Handle incoming requests.
    public func inputStream(_ input: Request) {
        do {
            // dispatches the incoming request to the responder.
            // the response is awaited on the responder stream's queue.
            try responder.respond(to: input).do { res in
                self.output(res)
            }.catch { error in
                self.errorStream?(error)
            }
        } catch {
            self.errorStream?(error)
        }
    }
}


/// A basic, closure-based responder.
public struct BasicResponder: Responder {
    /// Responder closure
    public typealias Closure = (Request) throws -> Future<Response>

    /// The stored responder closure.
    public let closure: Closure

    /// Create a new basic responder.
    public init(closure: @escaping Closure) {
        self.closure = closure
    }

    /// See: HTTP.Responder.respond
    public func respond(to req: Request) throws -> Future<Response> {
        return try closure(req)
    }
}


