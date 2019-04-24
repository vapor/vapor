import NIOHTTP1
import NIOWebSocket

internal extension Request {
    func makeWebSocketUpgradeResponse(onUpgrade: @escaping (WebSocket) -> ()) -> EventLoopFuture<Response> {
        let upgrader = WebSocketUpgrader(shouldUpgrade: { channel, _ in
            return channel.eventLoop.makeSucceededFuture([:])
        }, upgradePipelineHandler: { channel, req in
            let webSocket = WebSocket(channel: channel, mode: .server)
            onUpgrade(webSocket)
            return channel.pipeline.add(webSocket: webSocket)
        })
        
        var head = HTTPRequestHead(
            version: self.version,
            method: self.method,
            uri: self.urlString
        )
        head.headers = self.headers
        return upgrader.buildUpgradeResponse(
            channel: channel,
            upgradeRequest: head,
            initialResponseHeaders: headers
        ).map { headers in
            let res = Response(
                status: .switchingProtocols,
                headers: headers
            )
            res.upgrader = upgrader
            return res
        }
    }
}
