import Console

public final class ProviderInstall: Command {
    public let id = "provider-install"
    public let help = ["Installs Resources and Public files from providers"]
    public let console: ConsoleProtocol
    
    public let providers: [Provider]
    public let publicDir: String
    public let viewsDir: String
    
    public init(
        _ console: ConsoleProtocol,
        _ providers: [Provider],
        publicDir: String,
        viewsDir: String
        ) {
        self.console = console
        self.providers = providers
        self.publicDir = publicDir
        self.viewsDir = viewsDir
    }
    
    public func run(arguments: [String]) throws {
        console.print("This command copies resource files from your providers")
        console.print("into your root project directories.")
        console.warning("Any files with the same name will be replaced.")
        console.print("You have \(providers.count) providers that will be installed.")
        guard console.confirm("Would you like to continue?") else {
            console.warning("Install cancelled.")
            return
        }
        
        for (i, provider) in providers.enumerated() {
            let type = type(of: provider)
            console.info("[\(i + 1)/\(providers.count)]", newLine: false)
            console.print(" Installing \(type.repositoryName)")
            
            guard let root = type.providedDirectory else {
                console.error("Could not find directory for \(type)")
                continue
            }
            
            let publicDir = root + type.publicDir.finished(with: "/")
            let viewsDir = root + type.viewsDir.finished(with: "/")
            
            var dirty = false
            
            do {
                _ = try console.backgroundExecute(program: "/bin/sh", arguments: ["-c", "cp -rf \(publicDir)* \(self.publicDir)"])
                console.print("Copied public files")
                dirty = true
            } catch {
                //
            }
            
            do {
                _ = try console.backgroundExecute(program: "/bin/sh", arguments: ["-c", "cp -rf \(viewsDir)* \(self.viewsDir)"])
                console.print("Copied resource files")
                dirty = true
            } catch {
                //
            }
            
            if dirty {
                console.success("Installed \(type.repositoryName)")
            } else {
                console.print("Nothing to install")
            }
        }
    }
}
