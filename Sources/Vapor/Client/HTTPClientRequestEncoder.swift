import NIO
import NIOHTTP1

/// Private `ChannelOutboundHandler` that serializes `HTTPRequest` to `HTTPClientRequestPart`.
internal final class HTTPClientRequestEncoder: ChannelOutboundHandler, RemovableChannelHandler {
    typealias OutboundIn = HTTPClient.Request
    typealias OutboundOut = HTTPClientRequestPart

    let hostname: String
    
    /// Creates a new `HTTPClientRequestSerializer`.
    init(hostname: String) {
        self.hostname = hostname
    }
    
    /// See `ChannelOutboundHandler`.
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let req = unwrapOutboundIn(data)
        
        // mutate headers
        var headers = req.headers
        headers.add(name: .host, value: self.hostname)
        headers.replaceOrAdd(name: .userAgent, value: "Vapor/4.0 (Swift)")
        if let buffer = req.body {
            headers.replaceOrAdd(name: .contentLength, value: buffer.readableBytes.description)
        }
        
        // use just path + query string
        let path: String
        if let query = req.url.query {
            path = req.url.path + "?" + query
        } else {
            path = req.url.path
        }
        
        var httpHead = HTTPRequestHead(
            version: .init(major: 1, minor: 1),
            method: req.method,
            uri: path.hasPrefix("/") ? path : "/" + path
        )
        httpHead.headers = headers
        context.write(wrapOutboundOut(.head(httpHead)), promise: nil)
        if let buffer = req.body {
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        context.write(self.wrapOutboundOut(.end(nil)), promise: promise)
    }
}
