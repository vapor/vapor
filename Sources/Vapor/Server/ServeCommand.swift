//
//  ServeCommand.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/20/16.
//

public class ServeCommand: Command {

    public override var name: String {
        return "serve"
    }

    public override var help: String? {
        return "Serve the application"
    }

    public override var options: [InputOption] {
        return [
            InputOption("host", mode: .Optional, help: "The host address to serve the application on.", value: "0.0.0.0"),
            InputOption("port", mode: .Optional, help: "The port to serve the application on.", value: String(app.config.get("app.port", 8080)))
        ]
    }

    public override func handle() {
        let host = option("host")
        let port: Int

        if let value = option("port")?.int {
            port = value
        } else {
            port = 8080
        }

        comment("Visit http://\(host == "0.0.0.0" ? "localhost" : (host ?? "localhost")):\(port)")
        app.start(ip: host ?? "0.0.0.0", port: port)
    }

}
