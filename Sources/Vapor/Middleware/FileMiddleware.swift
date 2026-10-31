public import HTTPTypes
import NIOCore
import _NIOFileSystem

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

extension Application {
    /// Creates file middleware that shares the application's ETag hash cache with ``fileio``.
    ///
    ///     app.middleware.use(app.makeFileMiddleware())
    ///
    /// The cache capacity is configured by `ServerConfiguration.eTagHashCacheCapacity` when the application is created.
    ///
    /// - Parameters:
    ///   - publicDirectory: The directory to serve files from. Defaults to `directoryConfiguration.publicDirectory`.
    ///   - defaultFile: The default file to serve for directory requests. A leading `/` makes it relative to the public directory root.
    ///   - directoryAction: The action to take when a request matches a directory without a trailing slash.
    ///   - advancedETagComparison: Whether to generate and cache content hashes instead of using the file's modification date and size.
    ///   - cachePolicy: The browser cache policy to apply to served files.
    public func makeFileMiddleware(
        publicDirectory: String? = nil,
        defaultFile: String? = nil,
        directoryAction: FileMiddleware.DirectoryAction = .none,
        advancedETagComparison: Bool = false,
        cachePolicy: FileMiddleware.CachePolicy = .browserDefault
    ) -> FileMiddleware {
        FileMiddleware(
            publicDirectory: publicDirectory ?? self.directoryConfiguration.publicDirectory,
            defaultFile: defaultFile,
            directoryAction: directoryAction,
            advancedETagComparison: advancedETagComparison,
            cachePolicy: cachePolicy,
            fileIO: self.fileio
        )
    }

    #if !canImport(FoundationEssentials)
    /// Creates file middleware for bundle resources, sharing the application's ETag hash cache with ``fileio``.
    ///
    /// - Parameters:
    ///   - bundle: The bundle containing the files to serve.
    ///   - publicDirectory: The directory within the bundle to serve files from. Defaults to `Public`.
    ///   - defaultFile: The default file to serve for directory requests. A leading `/` makes it relative to the public directory root.
    ///   - directoryAction: The action to take when a request matches a directory without a trailing slash.
    ///   - advancedETagComparison: Whether to generate and cache content hashes instead of using the file's modification date and size.
    ///   - cachePolicy: The browser cache policy to apply to served files.
    /// - Important: Include the public directory in the `Copy Bundle Resources` build phase of your Xcode project.
    /// - Throws: A ``FileMiddleware/BundleSetupError`` if the bundle's public directory cannot be served.
    public func makeFileMiddleware(
        bundle: Bundle,
        publicDirectory: String = "Public",
        defaultFile: String? = nil,
        directoryAction: FileMiddleware.DirectoryAction = .none,
        advancedETagComparison: Bool = false,
        cachePolicy: FileMiddleware.CachePolicy = .browserDefault
    ) throws -> FileMiddleware {
        guard let bundleResourceURL = bundle.resourceURL else {
            throw FileMiddleware.BundleSetupError.bundleResourceURLIsNil
        }
        let publicDirectoryURL = bundleResourceURL.appendingPathComponent(publicDirectory.removeLeadingSlashes())
        guard (try? publicDirectoryURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
            throw FileMiddleware.BundleSetupError.publicDirectoryIsNotAFolder
        }

        return self.makeFileMiddleware(
            publicDirectory: publicDirectoryURL.path,
            defaultFile: defaultFile,
            directoryAction: directoryAction,
            advancedETagComparison: advancedETagComparison,
            cachePolicy: cachePolicy
        )
    }
    #endif
}

/// Serves static files from a public directory.
///
/// Use `app.makeFileMiddleware()` to serve the application's `Public` directory and share its ETag hash cache.
public final class FileMiddleware: Middleware {
    /// The public directory. Guaranteed to end with a slash.
    private let publicDirectory: String
    private let defaultFile: String?
    private let directoryAction: DirectoryAction
    private let advancedETagComparison: Bool
    private let cachePolicy: CachePolicy
    private let fileIO: FileIO

    public struct BundleSetupError: Equatable, Error {

        /// The description of this error.
        let description: String

        /// Cannot generate Bundle Resource URL
        public static let bundleResourceURLIsNil: Self = .init(
            description: "Cannot generate Bundle Resource URL: Bundle Resource URL is nil")

        /// Cannot find any actual folder for the given Public Directory
        public static let publicDirectoryIsNotAFolder: Self = .init(
            description: "Cannot find any actual folder for the given Public Directory")
    }

    fileprivate init(
        publicDirectory: String,
        defaultFile: String?,
        directoryAction: DirectoryAction,
        advancedETagComparison: Bool,
        cachePolicy: CachePolicy,
        fileIO: FileIO
    ) {
        self.publicDirectory = publicDirectory.addTrailingSlash()
        self.defaultFile = defaultFile
        self.directoryAction = directoryAction
        self.advancedETagComparison = advancedETagComparison
        self.cachePolicy = cachePolicy
        self.fileIO = fileIO
    }

    public func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        // Only GET and HEAD retrieve a representation of a file. Anything else — writes, OPTIONS,
        // and so on — isn't ours to answer just because the path happens to match a file on disk,
        // so hand it down the chain where a route (or the 404) can deal with it.
        guard request.method == .get || request.method == .head else {
            return try await next.respond(to: request)
        }

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

        if let fileInfo = try await FileSystem.shared.info(forFileAt: .init(absPath)) {
            // path exists, check for directory or file
            if fileInfo.type == .directory {
                // directory exists, see if we can return a file
                if absPath.hasSuffix("/") {
                    // If a directory, check for the default file
                    if let defaultFile = defaultFile {
                        if defaultFile.isAbsolute() {
                            absPath = self.publicDirectory + defaultFile.removeLeadingSlashes()
                        } else {
                            absPath = absPath + defaultFile
                        }

                        if try await FileSystem.shared.info(forFileAt: .init(absPath)) != nil {
                            // If the default file exists, stream it
                            return
                                try await fileIO
                                .streamFile(at: absPath, for: request, advancedETagComparison: advancedETagComparison)
                                .applyingCachePolicy(cachePolicy)
                        }
                    }
                } else {
                    if directoryAction.kind == .redirect {
                        var redirectUrl = request.url
                        redirectUrl.path += "/"
                        return request.redirect(to: redirectUrl.string, redirectType: .permanent)
                    }
                }
            } else {
                // file exists, stream it
                return
                    try await fileIO
                    .streamFile(at: absPath, for: request, advancedETagComparison: advancedETagComparison)
                    .applyingCachePolicy(cachePolicy)
            }
        }

        return try await next.respond(to: request)
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

extension String {
    /// Determines if input path is absolute based on a leading slash
    fileprivate func isAbsolute() -> Bool {
        return self.hasPrefix("/")
    }

    /// Makes a path relative by removing all leading slashes
    fileprivate func removeLeadingSlashes() -> String {
        var newPath = self
        while newPath.hasPrefix("/") {
            newPath.removeFirst()
        }
        return newPath
    }

    /// Adds a trailing slash to the path if one is not already present
    fileprivate func addTrailingSlash() -> String {
        var newPath = self
        if !newPath.hasSuffix("/") {
            newPath += "/"
        }
        return newPath
    }
}

extension FileMiddleware {
    /// The browser cache policy files should be served with.
    public struct CachePolicy: Sendable {
        var cacheControlHeader: HTTPFields.CacheControl?
        var ageHeader: Int?

        /// The browser's default caching policy should be used.
        ///
        /// In practice, this means the resource will be cached, but its completely out of your control as to when the browser will refresh it.
        public static let browserDefault = CachePolicy()

        /// The browser will always ask before requesting the full file.
        ///
        /// This can be used if the files served change very often, or in development so any change to a file is immediately reflected.
        public static let noCache = CachePolicy(cacheControlHeader: .init(noCache: true))

        /// The browser will cache the file for the specified duration.
        ///
        /// A typical cache duration may be 5 minutes, for instance: `.cache(upTo: .seconds(300))`
        public static func cache(upTo duration: Duration) -> CachePolicy {
            CachePolicy(cacheControlHeader: .init(maxAge: Int(duration.components.seconds)), ageHeader: 0)
        }

        /// A custom cache control policy that should be used for all files.
        /// - Parameters:
        ///   - cacheControlHeader: The `Cache-Control` header to use. If none is specified, any previous cache control header will be cleared.
        ///   - ageHeader: The `Age` header to use, in seconds. If none is specified, any previous age header will be cleared.
        /// - Returns: A cache policy with the specified headers.
        public static func custom(cacheControlHeader: HTTPFields.CacheControl?, ageHeader: Int? = nil) -> CachePolicy {
            CachePolicy(cacheControlHeader: cacheControlHeader, ageHeader: ageHeader)
        }
    }
}

extension Response {
    /// Returns a copy of the response carrying the given cache policy.
    /// - Parameter policy: The cache policy to use.
    /// - Returns: A copy of the receiver with the policy's `Cache-Control` and `Age` headers set.
    ///            A policy that doesn't specify a header clears any header already there.
    func applyingCachePolicy(_ policy: FileMiddleware.CachePolicy) -> Response {
        var response = self
        response.headers.cacheControl = policy.cacheControlHeader
        response.headers[.age] = policy.ageHeader.map { "\($0)" }
        return response
    }
}
