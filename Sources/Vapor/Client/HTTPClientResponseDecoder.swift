import NIO
import NIOHTTP1

/// Private `ChannelInboundHandler` that parses `HTTPClientResponsePart` to `HTTPResponse`.
internal final class HTTPClientResponseDecoder: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPClient.Response
    
    /// Tracks `HTTPClientHandler`'s state.
    enum ResponseState {
        /// Waiting to parse the next response.
        case ready
        /// Currently parsing the response's body.
        case parsingBody(HTTPResponseHead, ByteBuffer?)
    }
    
    var state: ResponseState
    
    init() {
        self.state = .ready
    }
    
    /// See `ChannelInboundHandler`.
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let res = self.unwrapInboundIn(data)
        switch res {
        case .head(let head):
            switch self.state {
            case .ready: self.state = .parsingBody(head, nil)
            case .parsingBody: assert(false, "Unexpected HTTPClientResponsePart.head when body was being parsed.")
            }
        case .body(var body):
            switch self.state {
            case .ready: assert(false, "Unexpected HTTPClientResponsePart.body when awaiting request head.")
            case .parsingBody(let head, let existingData):
                let buffer: ByteBuffer
                if var existing = existingData {
                    existing.writeBuffer(&body)
                    buffer = existing
                } else {
                    buffer = body
                }
                self.state = .parsingBody(head, buffer)
            }
        case .end(let tailHeaders):
            assert(tailHeaders == nil, "Unexpected tail headers")
            switch self.state {
            case .ready: assert(false, "Unexpected HTTPClientResponsePart.end when awaiting request head.")
            case .parsingBody(let head, let body):
                let res = HTTPClient.Response(
                    status: head.status,
                    headers: head.headers,
                    body: body
                )
                self.state = .ready
                context.fireChannelRead(wrapOutboundOut(res))
            }
        }
    }
}
