/**
    Serves the application.
*/
public class Serve: Command {
    public static let id: String = "serve"

    public static let signature: [Signature] = [
        Option("port"),
        Option("workdir")
    ]

    public static let help: [String] = [
        "tells the application to begin serving"
    ]

    public let app: Application
    public required init(app: Application) {
        self.app = app
        self.onServe = {}
    }

    public typealias OnServe = () throws -> ()

    public var onServe: OnServe?

    public func run() throws {
        let prepare = Prepare(app: app)
        try prepare.run()

        let onServe = self.onServe ?? app.onServe

        do {
            try onServe()
        } catch ServerError.bind(let host, let port, _) {
            self.error("Could not bind to \(host):\(port), it may be in use or require sudo.")
        } catch {
            self.error("Serve error: \(error)")
        }
    }
}
