/**
    Serves the application.
*/
public class Serve: Command {

    public typealias ServeFunction = () throws -> ()

    public static let id: String = "serve"

    public static let signature: [Signature] = [
        Option("port"),
        Option("workdir")
    ]

    public static let help: [String] = [
        "tells the application to begin serving"
    ]

    public let app: Application
    public var serve: ServeFunction?

    public required init(app: Application) {
        self.app = app
    }

    public func run() throws {
        let prepare = Prepare(app: app)
        try prepare.run()

        let serve = self.serve ?? app.serve

        do {
            try serve()
        } catch ServerError.bind(let host, let port, _) {
            self.error("Could not bind to \(host):\(port), it may be in use or require sudo.")
        } catch {
            self.error("Serve error: \(error)")
        }
    }
}
