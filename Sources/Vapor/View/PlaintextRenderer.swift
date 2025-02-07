import Logging
import NIOCore
import NIOPosix

public struct PlaintextRenderer: ViewRenderer, Sendable {
    public let eventLoopGroup: EventLoopGroup
    private let fileio: NonBlockingFileIO
    private let viewsDirectory: String
    private let logger: Logger

    public init(
        fileio: NonBlockingFileIO,
        viewsDirectory: String,
        logger: Logger,
        eventLoopGroup: EventLoopGroup = MultiThreadedEventLoopGroup.singleton
    ) {
        self.fileio = fileio
        self.viewsDirectory = viewsDirectory.finished(with: "/")
        self.logger = logger
        self.eventLoopGroup = eventLoopGroup
    }

    public func `for`(_ request: Request) -> ViewRenderer {
        PlaintextRenderer(
            fileio: request.application.fileio,
            viewsDirectory: self.viewsDirectory,
            logger: request.logger,
            eventLoopGroup: request.eventLoop
        )
    }

    public func render<E>(_ name: String, _ context: E) -> EventLoopFuture<View>
    where E: Encodable {
        self.logger.trace("Rendering plaintext view \(name) with \(context)")
        let eventLoop = self.eventLoopGroup.next()
        let path =
            name.hasPrefix("/")
            ? name
            : self.viewsDirectory + name
        return self.fileio.openFile(path: path, eventLoop: eventLoop).flatMap { (handle, region) in
            let fileHandleWrapper = NIOLoopBound(handle, eventLoop: eventLoop)
            return self.fileio.read(fileRegion: region, allocator: .init(), eventLoop: eventLoop).flatMapThrowing { buffer in
                try fileHandleWrapper.value.close()
                return buffer
            }
        }.map { data in
            return View(data: data)
        }
    }
}
