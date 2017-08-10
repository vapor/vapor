import Configs

extension Config {
    // MARK: Directories
    
    /// The work directory of your droplet is
    /// the directory in which your Resources, Public, etc
    /// folders are stored. This is normally `./` if
    /// you are running Vapor using `.build/xxx/app`
    public var workDir: String {
        // compute and cache the workdir
        let workDir = self["droplet", "workDir"]?.string
            ?? Config.workingDirectory(for: arguments)
        return workDir.finished(with: "/")
    }
    
    /// Resources directory relative to workDir
    public var resourcesDir: String {
        let resourcesDir = self["droplet", "resourcesDir"]?.string
            ?? "Resources"
        return makeAbsolute(path: resourcesDir)
    }
    
    /// Views directory relative to the
    /// resources directory.
    public var viewsDir: String {
        let viewsDir = self["droplet", "viewsDir"]?.string
            ?? "Views"
        // special case for views since it is a subset
        // of the resources dir instead of workdir
        if viewsDir.hasPrefix("/") {
            return viewsDir.finished(with: "/")
        } else {
            return resourcesDir + viewsDir.finished(with: "/")
        }
    }
    
    /// Public directory relative to the
    /// working directory
    public var publicDir: String {
        let publicDir = self["droplet", "publicDir"]?.string
            ?? "Public"
        return makeAbsolute(path: publicDir)
    }
    
    private func makeAbsolute(path: String) -> String {
        if path.hasPrefix("/") {
            return path.finished(with: "/")
        } else {
            return workDir + path.finished(with: "/")
        }
    }
}
