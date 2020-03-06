/// Serves static files from a public directory.
///
///     middlewareConfig = MiddlewareConfig()
///     middlewareConfig.use(FileMiddleware.self)
///     services.register(middlewareConfig)
///
/// `FileMiddleware` will default to `DirectoryConfig`'s working directory with `"/Public"` appended.
public final class FileMiddleware: Middleware {
    /// The public directory.
    /// - note: Must end with a slash.
    private let publicDirectory: String

    /// Creates a new `FileMiddleware`.
    public init(publicDirectory: String) {
        self.publicDirectory = publicDirectory.hasSuffix("/") ? publicDirectory : publicDirectory + "/"
    }

    /// See `Middleware`.
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // make a copy of the path
        var path = request.url.path

        // path must be relative.
        while path.hasPrefix("/") {
            path = String(path.dropFirst())
        }

        // protect against relative paths
        guard !path.contains("../") else {
            return request.eventLoop.makeFailedFuture(Abort(.forbidden))
        }

        // create absolute file path
        let filePath = publicDirectory + (path.removingPercentEncoding ?? path)
        print(filePath)

        // check if file exists and is not a directory
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir), !isDir.boolValue else {
            return next.respond(to: request)
        }

        // stream the file
        let res = request.fileio.streamFile(at: filePath)
        return request.eventLoop.makeSucceededFuture(res)
    }
}
