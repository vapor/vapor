/**
    Serves the application.
*/
public struct Serve: Command {
    public let id: String
    public let app: Application
    public let options: [Option]
    public let help: [String]

    public init(app: Application) {
        id = "serve"
        self.app = app
        options = [
            Option("port"),
            Option("workdir")
        ]
        help = [
            "tells the application to begin serving"
        ]
    }

    public func run() {
        app.serve()
    }
}
