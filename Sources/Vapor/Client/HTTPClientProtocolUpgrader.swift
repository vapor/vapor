import NIO
import NIOHTTP1

/// Can be used to upgrade `HTTPClient` requests using the static `HTTPClient.upgrade(...)` method.
protocol HTTPClientProtocolUpgrader {
    func buildUpgradeRequest() -> HTTPHeaders
    func upgrade(context: ChannelHandlerContext, upgradeResponse: HTTPResponseHead) -> EventLoopFuture<Void>
}
