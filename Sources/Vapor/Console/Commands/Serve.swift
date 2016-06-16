/**
    Serves the application.
*/
public struct Serve: Command {
    public static let id: String = "serve"

    public static let signature: [Signature] = [
        Option("port"),
        Option("workdir")
    ]

    public static let help: [String] = [
        "tells the application to begin serving"
    ]

    public let app: Application
    public let prepare: Prepare

    public init(app: Application) {
        self.app = app
        self.prepare = Prepare(app: app)
    }

    public func run() throws {
        try prepare.run()

        app.serve()
    }
}
