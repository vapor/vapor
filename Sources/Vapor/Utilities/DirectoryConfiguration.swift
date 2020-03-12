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
        do {
            let possibleBuildAreaURL = workingDirectoryURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            if try possibleBuildAreaURL.checkSubpathExists(at: "Build", isDirectory: true),
               try possibleBuildAreaURL.checkSubpathExists(at: "Index", isDirectory: true),
               let infoPlistData = try Data(contentsOfExisting: possibleBuildAreaURL.appendingPathComponent("info.plist", isDirectory: false)),
               let workspaceInfo = try PropertyListDecoder().decode(BuildAreaInfo?.self, from: infoPlistData),
               try workspaceInfo.workspaceURL.checkSubpathExists(at: "Package.swift", isDirectory: false)
            {
                // There are `Build` and `Index` directories, the `info.plist` file's structure matches the expected
                // format, the detected workspace has a `Package.swift` in it, and this is an Xcode build. That's
                // probably a pretty safe sanity check.
                return DirectoryConfiguration(workingDirectory: workspaceInfo.WorkspacePath)
            }
        } catch {
            Logger(label: "codes.vapor.directory-config")
                .notice("Failed to automatically detect Xcode working directory: \(error)")
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

extension Data {
    /// Same as `init(contentsOf:options:)`, but returns `nil` instead of
    /// throwing if the file doesn't exist on disk.
    init?(contentsOfExisting url: URL, options: Data.ReadingOptions = []) throws {
        do {
            try self.init(contentsOf: url, options: options)
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
    }
}
