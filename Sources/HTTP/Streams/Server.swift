//import Async
//import Bits
//import TCP  
//
///// HTTP server wrapped around TCP server
//public final class HTTPServer<HTTPPeer>: Async.OutputStream where
//    HTTPPeer: Async.Stream,
//    HTTPPeer.Input == HTTPResponse,
//    HTTPPeer.Output == HTTPRequest,
//    HTTPPeer: HTTPUpgradable
//{
//    /// See OutputStream.Output
//    public typealias Output = HTTPPeer
//
//    /// The wrapped Client Stream
//    private let socket: ClosableStream
//
//    /// Internal output stream
//    private let outputStream: BasicStream<Output>
//
//    /// Creates a new HTTP Server from a Client stream
//    public init<HTTPPeerStream>(socket: HTTPPeerStream)
//        where HTTPPeerStream: OutputStream,
//        HTTPPeerStream.Output == HTTPPeer
//    {
//        self.socket = socket
//        self.outputStream = .init()
//        socket.stream(to: outputStream)
//    }
//
//    /// See OutputStream.onOutput
//    public func onOutput<I>(_ input: I) where I: InputStream, Output == I.Input {
//        outputStream.onOutput(input)
//    }
//
//    /// See ClosableStream.onClose
//    public func onClose(_ onClose: ClosableStream) {
//        outputStream.onClose(onClose)
//    }
//
//    /// Starts the server, draining the stream of peers
//    /// into the supplied responder stream.
//    /// Errors thrown by clients will be routed to the
//    /// server's error stream.
//    public func start<Responder>(using responder: @escaping () -> (Responder)) -> BasicStream<HTTPPeer>
//        where Responder: Async.Stream,
//        Responder.Input == HTTPRequest,
//        Responder.Output == HTTPResponse
//    {
//        // setup the server pipeline
//        return outputStream.drain { client in
//            let responderStream = responder()
//            client.stream(to: responderStream).drain { res in
//                client.onInput(res)
//                
//                if let onUpgrade = res.onUpgrade {
//                    onUpgrade.closure(client.byteStream)
//                }
//            }.catch { err in
//                self.outputStream.onError(err)
//                client.close()
//            }.finally {
//                // client closed
//            }
//        }
//    }
//
//    /// See ClosableStream.close
//    public func close() {
//        socket.close()
//        outputStream.close()
//    }
//}

