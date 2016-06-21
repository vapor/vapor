import Strand

/**
    Serves the application.
*/
public struct Serve: Command {
    public enum Mode: String {
        case plaintext, secure, dual
    }

    public static let id: String = "serve"

    public static let signature: [Signature] = [
        Option("port"),
        Option("workdir"),
        Option("mode")
    ]

    public static let help: [String] = [
        "tells the application to begin serving"
    ]

    public let app: Application
    public init(app: Application) {
        self.app = app
    }

    public func run() {
        let mode = option("mode").string.flatMap(Mode.init) ?? .plaintext
        switch mode {
        case .plaintext:
            app.serve(secure: false)
        case .secure:
            app.serve(secure: true)
        case .dual:
            _ = try? Strand {
                self.app.serve(secure: false)
            }
            app.serve(secure: true)
        }
    }
}
