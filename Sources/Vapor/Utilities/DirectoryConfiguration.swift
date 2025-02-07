import Logging

#if canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#else
    import Darwin.C
#endif

/// `DirectoryConfiguration` represents a configured working directory.
/// It can also be used to derive a working directory automatically.
///
///     let dirConfig = DirectoryConfiguration.detect()
///     print(dirConfig.workingDirectory) // "/path/to/workdir"
///
public struct DirectoryConfiguration: Sendable {
    /// Path to the current working directory.
    public var workingDirectory: String
    public var resourcesDirectory: String
    public var viewsDirectory: String
    public var publicDirectory: String

    /// Create a new `DirectoryConfig` with a custom working directory.
    ///
    /// - parameters:
    ///     - workingDirectory: Custom working directory path.
    public init(workingDirectory: String) {
        self.workingDirectory = workingDirectory.finished(with: "/")
        self.resourcesDirectory = self.workingDirectory + "Resources/"
        self.viewsDirectory = self.resourcesDirectory + "Views/"
        self.publicDirectory = self.workingDirectory + "Public/"
    }

    /// Creates a `DirectoryConfig` by deriving a working directory using the `#file` variable or `getcwd` method.
    ///
    /// - returns: The derived `DirectoryConfig` if it could be created, otherwise just "./".
    public static func detect() -> DirectoryConfiguration {
        // get actual working directory
        let cwd = getcwd(nil, Int(PATH_MAX))
        defer {
            if let cwd = cwd {
                free(cwd)
            }
        }

        let workingDirectory: String

        if let cwd = cwd, let string = String(validatingUTF8: cwd) {
            workingDirectory = string
        } else {
            workingDirectory = "./"
        }

        #if Xcode
            if workingDirectory.contains("DerivedData") {
                Logger(label: "codes.vapor.directory-config")
                    .warning("No custom working directory set for this scheme, using \(workingDirectory)")
            }
        #endif

        return DirectoryConfiguration(workingDirectory: workingDirectory)
    }
}

extension String {
    public func finished(with string: String) -> String {
        if !self.hasSuffix(string) {
            return self + string
        } else {
            return self
        }
    }
}
