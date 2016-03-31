//
//  ServeCommand.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/20/16.
//

/** Command to start the server */
public class ServeCommand: Command {

    public override var name: String {
        return "serve"
    }

    public override var help: String? {
        return "Serve the application"
    }

    public override var options: [InputOption] {
        return [
            InputOption("ip",
                mode: .Optional,
                help: "The ip to serve the application on.",
                value: "0.0.0.0"
            ),

            InputOption("port",
                mode: .Optional,
                help: "The port to serve the application on.",
                value: String(app.config.get("app.port", 8080))
            )
        ]
    }

    public override func handle() {
        let ip = option("ip")
        let port: Int

        if let value = option("port")?.int {
            port = value
        } else {
            port = 8080
        }

        do {
            comment("Visit http://\(ip == "0.0.0.0" ? "localhost" : (ip ?? "localhost")):\(port)")
            try app.serve(ip: ip ?? "0.0.0.0", port: port)
        } catch {
            Log.error("Server start error: \(error)")
        }
    }

}
