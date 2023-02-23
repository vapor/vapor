import NIOCore
import WebSocketKit

extension Request {
     public func webSocket(
         maxFrameSize: WebSocketMaxFrameSize = .`default`,
         shouldUpgrade: @escaping ((Request) -> EventLoopFuture<HTTPHeaders?>) = {
             $0.eventLoop.makeSucceededFuture([:])
         },
         onUpgrade: @escaping (Request, WebSocket) -> ()
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
