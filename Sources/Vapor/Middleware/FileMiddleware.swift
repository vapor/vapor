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
    ///     - defaultFile: The name of the default file to look for and serve if a request hits any public directory. Starting with `/` implies
    ///     an absolute path from the public directory root. If `nil`, no default files are served.
    public init(publicDirectory: String, defaultFile: String? = nil) {
        self.publicDirectory = publicDirectory.addTrailingSlash()
        self.defaultFile = defaultFile
    }

    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // make a copy of the percent-decoded path
        guard var path = request.url.path.removingPercentEncoding else {
            return request.eventLoop.makeFailedFuture(Abort(.badRequest))
        }

        // path must be relative.
        path = path.removeLeadingSlashes()

        // protect against relative paths
        guard !path.contains("../") else {
            return request.eventLoop.makeFailedFuture(Abort(.forbidden))
        }

        // create absolute path
        var absPath = self.publicDirectory + path

        // check if path exists and whether it is a directory
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: absPath, isDirectory: &isDir) else {
            return next.respond(to: request)
        }
        
        if isDir.boolValue {
            // If a directory, check for the default file
            guard let defaultFile = defaultFile else {
                return next.respond(to: request)
            }
            
            if defaultFile.isAbsolute() {
                absPath = self.publicDirectory + defaultFile.removeLeadingSlashes()
            } else {
                absPath = absPath.addTrailingSlash() + defaultFile
            }
            
            // If the default file doesn't exist, pass on request
            guard FileManager.default.fileExists(atPath: absPath) else {
                return next.respond(to: request)
            }
        }
        
        // stream the file
        let res = request.fileio.streamFile(at: absPath)
        return request.eventLoop.makeSucceededFuture(res)
    }
}

#if canImport(Foundation)
extension FileMiddleware {
    /// Creates a new `FileMiddleware` for a server contained in an Xcode Project.
    ///
    /// - parameters:
    ///     - bundle: The Bundle which contains the files to serve.
    ///     - publicDirectory: The public directory to serve files from.
    ///     - defaultFile: The name of the default file to look for and serve if a request hits any public directory. Starting with `/` implies
    ///     an absolute path from the public directory root. If `nil`, no default files are served.
    ///
    /// - important: Make sure the public directory you wish to serve files from is included in the `Copy Bundle Resources` build phase of your project
    /// - returns: A fully qualified FileMiddleware if the given `publicDirectory` can be served, `nil` otherwise
    public convenience init?(bundle: Bundle, publicDirectory: String = "Public", defaultFile: String? = nil) {
        guard let bundleResourceURL = bundle.resourceURL?.appendingPathComponent(publicDirectory.removeLeadingSlashes()),
              (try? bundleResourceURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
            return nil
        }
        
        self.init(publicDirectory: bundleResourceURL.path, defaultFile: defaultFile)
    }
}
#endif

fileprivate extension String {
    /// Determines if input path is absolute based on a leading slash
    func isAbsolute() -> Bool {
        return self.hasPrefix("/")
    }

    /// Makes a path relative by removing all leading slashes
    func removeLeadingSlashes() -> String {
        var newPath = self
        while newPath.hasPrefix("/") {
            newPath.removeFirst()
        }
        return newPath
    }

    /// Adds a trailing slash to the path if one is not already present
    func addTrailingSlash() -> String {
        var newPath = self
        if !newPath.hasSuffix("/") {
            newPath += "/"
        }
        return newPath
    }
}
