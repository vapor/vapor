public struct Serve: Command {
    public static let id = "serve"
    public static let help = [
        "tells the application to begin serving"
    ]
    public static func run(on app: Application, with subcommands: [String]) {
        app.serve()
    }
}
