#if WebSockets
import NIOCore
import WebSocketKit
import HTTPTypes
import NIOPosix

extension Request {
      public func webSocket(
         maxFrameSize: WebSocketMaxFrameSize = .`default`,
         shouldUpgrade: @escaping (@Sendable (Request) -> EventLoopFuture<HTTPFields?>) = { _ in
             MultiThreadedEventLoopGroup.singleton.any().makeSucceededFuture([:])
         },
         onUpgrade: @Sendable @escaping (Request, WebSocket) -> ()
     ) -> Response {
         let res = Response(status: .switchingProtocols)
         res.upgrader = WebSocketUpgrader(maxFrameSize: maxFrameSize, shouldUpgrade: {
             shouldUpgrade(self)
         }, onUpgrade: { ws in
             onUpgrade(self, ws)
         })
         return res
     }
 }
#endif
