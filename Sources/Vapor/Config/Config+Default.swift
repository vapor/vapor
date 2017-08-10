import Configs

extension Config {
    public static func `default`() -> Config {
        return .dictionary([
            "droplet": .dictionary([
                "console": .string("terminal"),
                "log": .string("console"),
                "router": .string("branch"),
                "client": .string("engine"),
                "middleware": .array([
                    .string("error"),
                    .string("file"),
                    .string("date")
                ]),
                "commands": [
                    "serve",
                    "routes",
                    "dump-config",
                    "provider-install"
                ],
                "view": .string("static")
            ])
        ])
    }
}
