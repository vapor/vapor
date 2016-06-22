/**
    Serves the application.
*/
public struct Serve: Command {
    public static let id: String = "serve"

    public static let signature: [Signature] = [
        Option("port"),
        Option("workdir"),
        Option("scheme")
    ]

    public static let help: [String] = [
        "tells the application to begin serving"
    ]

    public let app: Application
    public init(app: Application) {
        self.app = app
    }

    public func run() {
        let scheme = option("scheme").string ?? "http" // servers generally use http behind proxy, default that
        app.serve(securityLayer: scheme.securityLayer) // TODO: fix scheme
    }
}
