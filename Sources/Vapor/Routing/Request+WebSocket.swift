import NIOCore
import WebSocketKit
import HTTPTypes

extension Request {
     @preconcurrency public func webSocket(
         maxFrameSize: WebSocketMaxFrameSize = .`default`,
         shouldUpgrade: @escaping (@Sendable (Request) -> EventLoopFuture<HTTPFields?>) = {
             $0.eventLoop.makeSucceededFuture([:])
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
