/// Serves static files from a public directory.
///
/// `FileMiddleware` will default to `DirectoryConfig`'s working directory with `"/Public"` appended.
public final class FileMiddleware: Middleware {
    /// The public directory. Guaranteed to end with a slash.
    private let publicDirectory: String
    private let defaultFile: String?

    /// Creates a new `FileMiddleware`.
    ///
    /// - parameters:
    ///     - publicDirectory: The public directory to serve files from.
    ///     - defaultFile: The name of the default file to serve if a request hits a directory. If `nil` is provided, default file serving is disabled.
    public init(publicDirectory: String, defaultFile: String? = nil) {
        self.publicDirectory = publicDirectory.hasSuffix("/") ? publicDirectory : publicDirectory + "/"
        self.defaultFile = defaultFile
    }

    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // make a copy of the percent-decoded path
        guard var path = request.url.path.removingPercentEncoding else {
            return request.eventLoop.makeFailedFuture(Abort(.badRequest))
        }

        // path must be relative.
        while path.hasPrefix("/") {
            path = String(path.dropFirst())
        }

        // protect against relative paths
        guard !path.contains("../") else {
            return request.eventLoop.makeFailedFuture(Abort(.forbidden))
        }

        // create absolute file path
        let filePath = self.publicDirectory + path

        // check if input exists and whether it is a directory
        var isDir: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir)
        
        guard fileExists else {
            return next.respond(to: request)
        }
        
        if !isDir.boolValue {
            // stream the file
            let res = request.fileio.streamFile(at: filePath)
            return request.eventLoop.makeSucceededFuture(res)
        } else {
            // Check for the default file
            guard let defaultFileName = defaultFile else {
                return next.respond(to: request)
            }
            
            var defaultFilePath = filePath.hasSuffix("/") ? filePath : filePath + "/"
            defaultFilePath = defaultFilePath + defaultFileName
            
            guard FileManager.default.fileExists(atPath: defaultFilePath) else {
                return next.respond(to: request)
            }
            
            // stream the file
            let res = request.fileio.streamFile(at: defaultFilePath)
            return request.eventLoop.makeSucceededFuture(res)
        }
    }
}
