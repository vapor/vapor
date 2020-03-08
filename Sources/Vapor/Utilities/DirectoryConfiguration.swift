import Foundation

/// `DirectoryConfiguration` represents a configured working directory.
/// It can also be used to derive a working directory automatically.
///
///     let dirConfig = DirectoryConfiguration.detect()
///     print(dirConfig.workingDirectory) // "/path/to/workdir"
///
public struct DirectoryConfiguration {
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
    
    /// Creates a `DirectoryConfig` by deriving a working directory using the `getcwd` method.
    ///
    /// - returns: The derived `DirectoryConfig` if it could be created, otherwise just "./".
    public static func detect() -> DirectoryConfiguration {
        let fileManager = FileManager.default
        
        // get actual working directory
        let workingDirectory = fileManager.currentDirectoryPath
        let workingDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)

        #if Xcode
        // Starting with no later than Xcode 11.4b1, and possibly earlier, the DerivedData directory for an
        // SPM package's workspace contains an `info.plist` which points directly at where `Package.swift`
        // lives. Very useful! We do some sanity checks that may seem a bit excessive, but are considered
        // reasonable for ensuring that we neither require the project build directory actually be under the
        // usual DerivedData location (as this can be changed), nor accidentally treat some other kind of
        // working directory as a project build area.
        struct BuildAreaInfo: Codable {
            let LastAccessedDate: Date
            let WorkspacePath: String
            var workspaceURL: URL { URL(fileURLWithPath: WorkspacePath, isDirectory: true) }
        }
        let possibleBuildAreaURL = workingDirectoryURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        if (try? possibleBuildAreaURL.checkSubpathExists(at: "Build", isDirectory: true)) ?? false,
           (try? possibleBuildAreaURL.checkSubpathExists(at: "Index", isDirectory: true)) ?? false,
           let infoPlistData = try? Data.init(contentsOf: possibleBuildAreaURL.appendingPathComponent("info.plist", isDirectory: false)),
           let workspaceInfo = try? PropertyListDecoder().decode(BuildAreaInfo.self, from: infoPlistData),
           (try? workspaceInfo.workspaceURL.checkSubpathExists(at: "Package.swift", isDirectory: false)) ?? false
        {
            // There are `Build` and `Index` directories, the `info.plist` file's structure matches the expected
            // format, the detected workspace has a `Package.swift` in it, and this is an Xcode build. That's
            // probably a pretty safe sanity check.
            return DirectoryConfiguration(workingDirectory: workspaceInfo.WorkspacePath)
        }
        
        // Okay, all that failed. Do our usual sodden `DerivedData` check.
        if workingDirectory.contains("DerivedData") {
            Logger(label: "codes.vapor.directory-config")
                .warning("No custom working directory set for this scheme, using \(workingDirectory)")
        }
        #endif
        
        return DirectoryConfiguration(workingDirectory: workingDirectory)
    }
}

public extension String {
    func finished(with string: String) -> String {
        if !self.hasSuffix(string) {
            return self + string
        } else {
            return self
        }
    }
}

public extension URL {
    
    /// Same as `URL.checkResourceIsReachable()`, but explicitly requires that
    /// the recevier be a file URL, and does _not_ throw if the file simply
    /// doesn't exist.
    ///
    /// - Warning: As with any filesystem API which is not specifically designed
    /// to handle race conditions, this method **MUST** be considered purely
    /// advisory; the actual state of the filesystem may change in ways which
    /// render the result inaccurate at any time and without warning.
    ///
    /// - Throws:
    ///   - Any error potentially thrown by `URL.checkResourceIsReachable()`
    ///   - `POSIXError.EINVAL` if the receiver is not a file URL.
    /// - Returns: `true` if, at the time of the call, the receiver refers to a
    /// filesystem path which appeared to exist when the check was made. `false`
    /// if the opposite is true and no other filesystem error occurred.
    func checkFileURLExists() throws -> Bool {
        do {
            guard self.isFileURL else {
                throw POSIXError(.EINVAL)
            }
            
            return try self.checkResourceIsReachable()
        } catch CocoaError.fileReadNoSuchFile {
            return false
        }
    }
    
    /// Same as `URL.checkFileURLExists()`, but performs the check operation on
    /// the result of appending the provided path component to the receiver.
    ///
    /// - Warning: As with any filesystem API which is not specifically designed
    /// to handle race conditions, this method **MUST** be considered purely
    /// advisory; the actual state of the filesystem may change in ways which
    /// render the result inaccurate at any time and without warning.
    ///
    /// - Parameters:
    ///   - subpath: A path component to be appended to the receiver, as by
    ///   `URL.appendingPathComponent(_:)` and checked for existence.
    ///   - isDirectory: If non-`nil`, indicates whether `subpath` represents a
    ///   directory. It is always prefrred to provide a value for this parameter
    ///   whenever possible.
    /// - Throws: See `URL.checkFileURLExists()`
    /// - Returns: `treu` if, at the time of the call, the result of appending
    /// the given `subpath` to the receiver refers to a filesystem path which
    /// appeared to exist when the check was made. `false` if the opposite was
    /// true and no other filesystem error occurred.
    func checkSubpathExists(at subpath: String, isDirectory: Bool? = nil) throws -> Bool {
        let checkURL: URL
        
        if let isDirectory = isDirectory {
            checkURL = self.appendingPathComponent(subpath, isDirectory: isDirectory)
        } else {
            checkURL = self.appendingPathComponent(subpath)
        }
        
        return try checkURL.checkFileURLExists()
    }

}

