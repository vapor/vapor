#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

/// `DirectoryConfiguration` represents a configured working directory.
/// It can also be used to derive a working directory automatically.
///
///     let dirConfig = DirectoryConfiguration.detect()
///     print(dirConfig.workingDirectory) // "/path/to/workdir"
///
public struct DirectoryConfiguration {
    /// Path to the current working directory.
    public let workingDirectory: String

    public var resourcesDirectory: String {
        return self.workingDirectory + "Resources/"
    }

    public var viewsDirectory: String {
        return self.resourcesDirectory + "Views/"
    }

    public var publicDirectory: String {
        return self.workingDirectory + "Public/"
    }
    
    /// Create a new `DirectoryConfig` with a custom working directory.
    ///
    /// - parameters:
    ///     - workingDirectory: Custom working directory path.
    public init(workingDirectory: String) {
        self.workingDirectory = workingDirectory.finished(with: "/")
    }
    
    /// Creates a `DirectoryConfig` by deriving a working directory using the `#file` variable or `getcwd` method.
    ///
    /// - returns: The derived `DirectoryConfig` if it could be created, otherwise just "./".
    public static func detect() -> DirectoryConfiguration {
        let fileBasedWorkDir: String?
        
        #if Xcode
        // attempt to find working directory through #file
        let file = #file
        
        if file.contains(".build") {
            // most dependencies are in `./.build/`
            fileBasedWorkDir = file.components(separatedBy: "/.build").first
        } else if file.contains("Packages") {
            // when editing a dependency, it is in `./Packages/`
            fileBasedWorkDir = file.components(separatedBy: "/Packages").first
        } else {
            // when dealing with current repository, file is in `./Sources/`
            fileBasedWorkDir = file.components(separatedBy: "/Sources").first
        }
        #else
        fileBasedWorkDir = nil
        #endif
        
        let workDir: String
        if let fileBasedWorkDir = fileBasedWorkDir {
            workDir = fileBasedWorkDir
        } else {
            // get actual working directory
            let cwd = getcwd(nil, Int(PATH_MAX))
            defer {
                free(cwd)
            }
            
            if let cwd = cwd, let string = String(validatingUTF8: cwd) {
                workDir = string
            } else {
                workDir = "./"
            }
        }
        
        return DirectoryConfiguration(workingDirectory: workDir)
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
