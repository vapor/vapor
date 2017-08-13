//import Service
//
//extension Config {
//    public static func `default`(arguments: [String] = CommandLine.arguments) -> Config {
//        let config: Config = [
//            "droplet": [
//                "environment": "development",
//                "console": "terminal",
//                "log": "console",
//                "router": "branch",
//                "client": "engine",
//                "middleware": [
//                    "error",
//                    "file",
//                    "date"
//                ],
//                "commands": [
//                    "serve",
//                    "routes",
//                    "dump-config",
//                    "provider-install"
//                ],
//                "view": "static"
//            ]
//        ]
//
//        var sources = [Source]()
//        sources.append(.commandLine(arguments: arguments))
//        sources.append(.memory(config: config))
//        return Config.makeConfig(prioritized: sources)
//    }
//}

