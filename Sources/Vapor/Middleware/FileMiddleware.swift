import Foundation
import NIOCore

/// Serves static files from a public directory.
///
/// `FileMiddleware` will default to `DirectoryConfig`'s working directory with `"/Public"` appended.
public final class FileMiddleware: AsyncMiddleware {
    /// The public directory. Guaranteed to end with a slash.
    private let publicDirectory: String
    private let defaultFile: String?
    private let directoryAction: DirectoryAction
    
    public struct BundleSetupError: Equatable, Error {
        
        /// The description of this error.
        let description: String
        
        /// Cannot generate Bundle Resource URL
        public static let bundleResourceURLIsNil: Self = .init(description: "Cannot generate Bundle Resource URL: Bundle Resource URL is nil")
        
        /// Cannot find any actual folder for the given Public Directory
        public static let publicDirectoryIsNotAFolder: Self = .init(description: "Cannot find any actual folder for the given Public Directory")
    }

    /// Creates a new `FileMiddleware`.
    ///
    /// - parameters:
    ///     - publicDirectory: The public directory to serve files from.
    ///     - defaultFile: The name of the default file to look for and serve if a request hits any public directory. Starting with `/` implies
    ///     an absolute path from the public directory root. If `nil`, no default files are served.
    ///     - directoryAction: Determines the action to take when the request doesn't have a trailing slash but matches a directory.
    public init(publicDirectory: String, defaultFile: String? = nil, directoryAction: DirectoryAction = .none) {
        self.publicDirectory = publicDirectory.addTrailingSlash()
        self.defaultFile = defaultFile
        self.directoryAction = directoryAction
    }
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // make a copy of the percent-decoded path
        guard var path = request.url.path.removingPercentEncoding else {
            throw Abort(.badRequest)
        }

        // path must be relative.
        path = path.removeLeadingSlashes()

        // protect against relative paths
        guard !path.contains("../") else {
            throw Abort(.forbidden)
        }

        // create absolute path
        var absPath = self.publicDirectory + path

        // check if path exists and whether it is a directory
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: absPath, isDirectory: &isDir) else {
            return try await next.respond(to: request)
        }
        
        if isDir.boolValue {
            guard absPath.hasSuffix("/") else {
                switch directoryAction.kind {
                case .redirect:                    
                    var redirectUrl = request.url
                    redirectUrl.path += "/"
                    return request.redirect(to: redirectUrl.string, redirectType: .permanent)
                case .none:
                    return try await next.respond(to: request)
                }
            }
            
            // If a directory, check for the default file
            guard let defaultFile = defaultFile else {
                return try await next.respond(to: request)
            }
            
            if defaultFile.isAbsolute() {
                absPath = self.publicDirectory + defaultFile.removeLeadingSlashes()
            } else {
                absPath = absPath + defaultFile
            }
            
            // If the default file doesn't exist, pass on request
            guard FileManager.default.fileExists(atPath: absPath) else {
                return try await next.respond(to: request)
            }
        }
        
        // stream the file
        return request.fileio.streamFile(at: absPath)
    }

    /// Creates a new `FileMiddleware` for a server contained in an Xcode Project.
    ///
    /// - parameters:
    ///     - bundle: The Bundle which contains the files to serve.
    ///     - publicDirectory: The public directory to serve files from.
    ///     - defaultFile: The name of the default file to look for and serve if a request hits any public directory. Starting with `/` implies an absolute path from the public directory root. If `nil`, no default files are served.
    ///     - directoryAction: Determines the action to take when the request doesn't have a trailing slash but matches a directory.
    ///
    /// - important: Make sure the public directory you wish to serve files from is included in the `Copy Bundle Resources` build phase of your project
    /// - returns: A fully qualified FileMiddleware if the given `publicDirectory` can be served, throws a `BundleSetupError` otherwise
    public convenience init(
        bundle: Bundle,
        publicDirectory: String = "Public",
        defaultFile: String? = nil,
        directoryAction: DirectoryAction = .none
    ) throws {
        guard let bundleResourceURL = bundle.resourceURL else {
            throw BundleSetupError.bundleResourceURLIsNil
        }
        let publicDirectoryURL = bundleResourceURL.appendingPathComponent(publicDirectory.removeLeadingSlashes())
        guard (try? publicDirectoryURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
            throw BundleSetupError.publicDirectoryIsNotAFolder
        }
        
        self.init(publicDirectory: bundleResourceURL.path, defaultFile: defaultFile, directoryAction: directoryAction)
    }
    
    /// Possible actions to take when the request doesn't have a trailing slash but matches a directory
    public struct DirectoryAction: Sendable {
        let kind: Kind
        
        /// Indicates that the request should be passed through the middleware
        public static var none: DirectoryAction {
            return Self(kind: .none)
        }
        
        /// Indicates that a redirect to the same url with a trailing slash should be returned.
        public static var redirect: DirectoryAction {
            return Self(kind: .redirect)
        }
        
        enum Kind {
            case none
            case redirect
        }
    }
}

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
