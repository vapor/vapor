import NIOCore
import NIOPosix
import Logging
import _NIOFileSystem

public struct PlaintextRenderer: ViewRenderer, Sendable {
    public let eventLoopGroup: EventLoopGroup
    private let viewsDirectory: String
    private let logger: Logger

    public init(
        viewsDirectory: String,
        logger: Logger,
        eventLoopGroup: EventLoopGroup = MultiThreadedEventLoopGroup.singleton
    ) {
        self.viewsDirectory = viewsDirectory.finished(with: "/")
        self.logger = logger
        self.eventLoopGroup = eventLoopGroup
    }
    
    public func `for`(_ request: Request) -> ViewRenderer {
        PlaintextRenderer(
            viewsDirectory: self.viewsDirectory,
            logger: request.logger,
            eventLoopGroup: request.eventLoop
        )
    }

    public func render<E>(_ name: String, _ context: E) async throws -> View
        where E: Encodable
    {
        self.logger.trace("Rendering plaintext view \(name) with \(context)")
        let eventLoop = self.eventLoopGroup.next()
        let path = name.hasPrefix("/")
            ? name
            : self.viewsDirectory + name
        return try await FileSystem.shared.withFileHandle(forReadingAt: FilePath(path)) { handle in
            guard let fileSize = try await FileSystem.shared.info(forFileAt: .init(path))?.size else {
                self.logger.debug("Unable to get file size of file", metadata: ["filePath": "\(path)"])
                throw Abort(.internalServerError)
            }
            let chunks = handle.readChunks()
            let buffer = try await chunks.collect(upTo: Int(fileSize))
            return View(data: buffer)
        }
    }
}
