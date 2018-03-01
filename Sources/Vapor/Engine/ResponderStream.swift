import Async
import Dispatch

///// A stream containing an  responder.
//public final class ResponderStream: TranscribingStream {
//    /// See InputStream.Input
//    public typealias Input = HTTPRequest
//
//    /// See OutputStream.Output
//    public typealias Output = HTTPResponse
//
//    /// The base responder
//    private let responder: Responder
//
//    /// Worker to pass onto incoming requests
//    public let container: Container
//
//    /// Create a new response stream.
//    /// The responses will be awaited on the supplied queue.
//    public init(responder: Responder, using container: Container) {
//        self.responder = responder
//        self.container = container
//    }
//
//    /// See TransformingStream.transform
//    public func transcribe(_ httpRequest: HTTPRequest) -> Future<HTTPResponse> {
//        return Future.flatMap {
//            let req = Request(http: httpRequest, using: self.container)
//            return try self.responder.respond(to: req)
//                .map(to: HTTPResponse.self) { $0.http }
//        }
//    }
//}

