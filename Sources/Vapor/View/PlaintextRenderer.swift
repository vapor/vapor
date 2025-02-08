import NIOCore
import NIOPosix
import Logging
import _NIOFileSystem

public struct PlaintextRenderer: ViewRenderer, Sendable {
    private let fileio: NonBlockingFileIO
    private let viewsDirectory: String
    private let logger: Logger

    public init(
        fileio: NonBlockingFileIO,
        viewsDirectory: String,
        logger: Logger
    ) {
        self.fileio = fileio
        self.viewsDirectory = viewsDirectory.finished(with: "/")
        self.logger = logger
    }
    
    public func `for`(_ request: Request) -> ViewRenderer {
        PlaintextRenderer(
            fileio: request.application.fileio,
            viewsDirectory: self.viewsDirectory,
            logger: request.logger
        )
    }

    public func render<E>(_ name: String, _ context: E) async throws -> View where E : Encodable {
        self.logger.trace("Rendering plaintext view \(name) with \(context)")
        let path = name.hasPrefix("/")
            ? name
            : self.viewsDirectory + name
        return try await FileSystem.shared.withFileHandle(forReadingAt: .init(path)) { handle in
            let buffer = try await handle.readToEnd(maximumSizeAllowed: .megabytes(32))
            return View(data: buffer)
        }
    }
}
