import Logging
import NIOCore

/// Closes the channel on receipt of an `IdleStateHandler.IdleStateEvent`.
final class CloseOnIdleHandler: ChannelInboundHandler {
    typealias InboundIn = NIOAny
    typealias InboundOut = NIOAny

    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if event is IdleStateHandler.IdleStateEvent {
            self.logger.debug("Closing idle connection")
            // .all so an unresponsive peer doesn't strand the read side.
            context.close(mode: .all, promise: nil)
        } else {
            context.fireUserInboundEventTriggered(event)
        }
    }
}
