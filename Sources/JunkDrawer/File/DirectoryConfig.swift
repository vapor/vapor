import COperatingSystem

/// Contains a configured working directory.
public struct DirectoryConfig {
    /// The working directory
    public let workDir: String

    /// Create a new directory config.
    public init(workDir: String) {
        self.workDir = workDir
    }

    /// Creates a directory config with default working directory.
    public static func `default`() -> DirectoryConfig {
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

        return DirectoryConfig(
            workDir: workDir.finished(with: "/")
        )
    }
}
