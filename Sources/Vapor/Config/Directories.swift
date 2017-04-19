extension Config {
    // MARK: Directories
    
    /// The work directory of your droplet is
    /// the directory in which your Resources, Public, etc
    /// folders are stored. This is normally `./` if
    /// you are running Vapor using `.build/xxx/app`
    public var workDir: String {
        let workDir = self["droplet", "workDir"]?.string
            ?? Config.workingDirectory(from: arguments)
        return workDir.finished(with: "/")
    }
    
    /// Resources directory relative to workDir
    public var resourcesDir: String {
        let resourcesDir = self["droplet", "resourcesDir"]?.string
            ?? workDir + "Resources"
        return resourcesDir.finished(with: "/")
    }
    
    /// Views directory relative to the
    /// resources directory.
    public var viewsDir: String {
        let viewsDir = self["droplet", "viewsDir"]?.string
            ?? workDir + "Views"
        return viewsDir.finished(with: "/")
    }
    
    /// Localization directory relative to the
    /// working directory
    public var localizationDir: String {
        let localizationDir = self["droplet", "localizationDir"]?.string
            ?? workDir + "Localization"
        return localizationDir.finished(with: "/")
    }
    
    /// Public directory relative to the
    /// working directory
    public var publicDir: String {
        let publicDir = self["droplet", "publicDir"]?.string
            ?? workDir + "Public"
        return publicDir.finished(with: "/")
    }
}
