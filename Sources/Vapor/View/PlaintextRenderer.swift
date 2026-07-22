import NIOCore
import NIOPosix
import Logging
import _NIOFileSystem

/// A ``ViewRenderer`` that serves views from files on disk, without any templating.
///
/// `PlaintextRenderer` reads the requested file from its configured views directory and returns
/// its raw contents as a ``View``. The `context` passed to ``render(_:_:)`` is ignored as no
/// template substitution is performed.
/// 
/// This renderer is mainly used for testing. Its use in production is
/// discouraged. Consider using [Leaf] if you need a real templating engine.
///
/// [Leaf]: https://docs.vapor.codes/leaf/getting-started/
public struct PlaintextRenderer: ViewRenderer, Sendable {
    /// The directory containing the view files, always terminated with a trailing slash.
    private let viewsDirectory: String

    /// The logger used when rendering views.
    private let logger: Logger

    /// Creates a new ``PlaintextRenderer``.
    ///
    /// - Parameters:
    ///   - viewsDirectory: The directory in which view files are located. Relative view names passed
    ///     to ``render(_:_:)`` are resolved against this directory. A trailing slash is added if absent.
    ///   - logger: The logger used when rendering views.
    public init(
        viewsDirectory: String,
        logger: Logger
    ) {
        self.viewsDirectory = viewsDirectory.finished(with: "/")
        self.logger = logger
    }

    /// Returns the renderer for the given request, with the logger set from the ``Request``.
    ///
    /// - Parameter request: The ``Request`` to scope the renderer to.
    /// - Returns: A new ``PlaintextRenderer`` configured with the request's logger.
    public func `for`(_ request: Request) -> any ViewRenderer {
        PlaintextRenderer(
            viewsDirectory: self.viewsDirectory,
            logger: request.logger
        )
    }

    /// Renders a view by returning the contents of the file.
    ///
    /// If `name` is an absolute path (begins with `/`), it is used as-is; otherwise it is resolved
    /// against the renderer's views directory. The `context` is ignored, as no templating is applied.
    /// 
    /// > Warning: The name of the template is not sanitized, so you should ensure that you trust any
    /// > input passed to it, or sanitize it to prevent directory traversal attacks
    ///
    /// - Parameters:
    ///   - name: The name of the view to render, either an absolute path or a path relative to the
    ///     views directory.
    ///   - context: The rendering context. Ignored by this renderer.
    /// - Returns: A ``View`` containing the raw file contents.
    /// - Throws: An error if the file cannot be read, or if its size exceeds 32 megabytes.
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
