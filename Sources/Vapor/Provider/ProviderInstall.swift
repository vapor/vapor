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
        for provider in providers {
            let type = type(of: provider)
            console.info("Installing \(type)")
            
            guard let root = type.providedDirectory else {
                console.error("Could not find directory for \(type)")
                continue
            }
            
            let publicDir = root + type.publicDir.finished(with: "/")
            let viewsDir = root + type.viewsDir.finished(with: "/")
            
            console.info("Copying public files...")
            _ = try console.backgroundExecute(program: "/bin/sh", arguments: ["-c", "cp -rf \(publicDir)* \(publicDir)"])
            
            console.info("Copying resource files...")
            _ = try console.backgroundExecute(program: "/bin/sh", arguments: ["-c", "cp -rf \(viewsDir)* \(viewsDir)"])
            
            console.success("Installed \(type)")
        }
    }
}
