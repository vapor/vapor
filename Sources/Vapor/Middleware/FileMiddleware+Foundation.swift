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
    /// - important: Make sure the root directory you wish to serve files from is included in the `Copy Bundle Resources` build phase of your project
    public convenience init?(bundle: Bundle = .main, publicDirectory: String = "Public", defaultFile: String? = nil) {
        let fullPublicDirectoryPath: String
        if #available(macOS 13.0, *) {
            guard let bundleResourceURL = bundle.resourceURL?.appending(path: publicDirectory) else { return nil }
            fullPublicDirectoryPath = bundleResourceURL.path()
        } else {
            guard let bundleResourceURL = bundle.resourceURL?.appendingPathComponent(publicDirectory) else { return nil }
            fullPublicDirectoryPath = bundleResourceURL.path
        }
        
        self.init(publicDirectory: fullPublicDirectoryPath, defaultFile: defaultFile)
    }
}
#endif
