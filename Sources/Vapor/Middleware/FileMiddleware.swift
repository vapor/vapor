/// Serves static files from a public directory.
///
///     middlewareConfig = MiddlewareConfig()
///     middlewareConfig.use(FileMiddleware.self)
///     services.register(middlewareConfig)
///
/// `FileMiddleware` will default to `DirectoryConfig`'s working directory with `"/Public"` appended.
public final class FileMiddleware: Middleware, ServiceType {
    /// See `ServiceType`.
    public static func makeService(for container: Container) throws -> FileMiddleware {
        return try .init(publicDirectory: container.make(DirectoryConfig.self).workDir + "Public/")
    }

    /// The public directory.
    /// - note: Must end with a slash.
    private let publicDirectory: String

    /// Creates a new `FileMiddleware`.
    public init(publicDirectory: String) {
        self.publicDirectory = publicDirectory.hasSuffix("/") ? publicDirectory : publicDirectory + "/"
    }

    /// See `Middleware`.
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        // make a copy of the path
        var path = req.http.url.path

        // path must be relative.
        while path.hasPrefix("/") {
            path = String(path.dropFirst())
        }

        // protect against relative paths
        guard !path.contains("../") else {
            throw Abort(.forbidden)
        }

        // create absolute file path
        let filePath = publicDirectory + path

        // check if file exists and is not a directory
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir), !isDir.boolValue else {
            return try next.respond(to: req)
        }

        // stream the file
        return try req.streamFile(at: filePath)
    }
}
