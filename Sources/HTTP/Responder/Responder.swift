//import Async
//import Dispatch
//
///// Capable of responding to a request.
/////
///// [Learn More →](https://docs.vapor.codes/3.0/http/responder/)
//public protocol HTTPResponder {
//    func respond(to req: HTTPRequest) throws -> Future<HTTPResponse>
//}
//
//extension HTTPResponder {
//    /// Creates a stream from this responder capable of being
//    /// added to a server or client stream.
//    public func makeStream() -> HTTPResponderStream {
//        return HTTPResponderStream(responder: self)
//    }
//}
//
///// A stream containing an HTTP responder.
//public final class HTTPResponderStream: Async.Stream {
//    /// See InputStream.Input
//    public typealias Input = HTTPRequest
//
//    /// See OutputStream.Output
//    public typealias Output = HTTPResponse
//
//    /// The base responder
//    private let responder: HTTPResponder
//
//    /// Use a basic stream to easily implement our output stream.
//    private var outputStream: BasicStream<Output>
//
//    /// Create a new response stream.
//    /// The responses will be awaited on the supplied queue.
//    public init(responder: HTTPResponder) {
//        self.responder = responder
//        self.outputStream = .init()
//    }
//
//    /// See InputStream.onInput
//    public func onInput(_ input: HTTPRequest) {
//        do {
//            // dispatches the incoming request to the responder.
//            // the response is awaited on the responder stream's queue.
//            try responder.respond(to: input)
//                .stream(to: outputStream)
//        } catch {
//            self.onError(error)
//        }
//    }
//
//    /// See InputStream.onError
//    public func onError(_ error: Error) {
//        outputStream.onError(error)
//    }
//
//    /// See OutputStream.onOutput
//    public func onOutput<I>(_ input: I) where I: Async.InputStream, Output == I.Input {
//        outputStream.onOutput(input)
//    }
//
//    /// See CloseableStream.close
//    public func close() {
//        outputStream.close()
//    }
//
//    /// See CloseableStream.onClose
//    public func onClose(_ onClose: ClosableStream) {
//        outputStream.onClose(onClose)
//    }
//}
//
//
///// A basic, closure-based responder.
//public struct BasicResponder: HTTPResponder {
//    /// Responder closure
//    public typealias Closure = (HTTPRequest) throws -> Future<HTTPResponse>
//
//    /// The stored responder closure.
//    public let closure: Closure
//
//    /// Create a new basic responder.
//    public init(closure: @escaping Closure) {
//        self.closure = closure
//    }
//
//    /// See: HTTP.Responder.respond
//    public func respond(to req: HTTPRequest) throws -> Future<HTTPResponse> {
//        return try closure(req)
//    }
//}
//
//
