/// A `Command` that prints a table listing all of this application's registered routes.
///
///     $ swift run Run routes
///
///     +--------+---------------+
///     | GET    | /hello        |
///     +--------+---------------+
///
public struct RoutesCommand: Command, Service {
    /// See `Command`.
    public var arguments: [CommandArgument] {
        return []
    }

    /// See `Command`.
    public var options: [CommandOption] {
        return []
    }

    /// See `Command`.
    public var help: [String] {
        return ["Displays all registered routes"]
    }

    /// See `Command`.
    public let router: Router

    /// Create a new serve command.
    public init(router: Router) {
        self.router = router
    }

    /// See `CommandGroup`.
    public func run(using context: CommandContext) throws -> Future<Void> {
        let console = context.console
        
        var longestMethod = 0
        var longestPath = 0

        for route in router.routes {
            guard let first = route.path.first, case .constant(let method) = first else {
                continue
            }

            if method.count > longestMethod {
                longestMethod = method.count
            }

            var pathLength = 0

            for path in route.path[1...] {
                switch path {
                case .constant(let const):
                    pathLength += const.count + 1 // /const
                case .parameter(let param):
                    pathLength += param.count + 2 // /:param
                case .anything:
                    pathLength += 2 // /*
                }
            }

            if pathLength > longestPath {
                longestPath = pathLength
            }
        }

        func hr() {
            console.print("+-", newLine: false)
            for _ in 0..<longestMethod {
                console.print("-", newLine: false)
            }
            console.print("-+-", newLine: false)
            for _ in 0..<longestPath {
                console.print("-", newLine: false)
            }
            console.print("-+")
        }

        hr()

        for route in router.routes {
            console.print("| ", newLine: false)

            guard let first = route.path.first, case .constant(let method) = first else {
                continue
            }
            console.success(method.string, newLine: false)

            for _ in 0..<longestMethod - method.count {
                console.print(" ", newLine: false)
            }

            console.print(" | ", newLine: false)

            var pathLength = 0

            route.path[1...].forEach { comp in
                switch comp {
                case .constant(let const):
                    console.info("/", newLine: false)
                    console.print(const.string, newLine: false)
                    pathLength += const.count + 1
                case .parameter(let param):
                    console.info("/", newLine: false)
                    console.print(":", newLine: false)
                    console.info(param.string, newLine: false)
                    pathLength += param.count + 2
                case .anything:
                    console.info("/*", newLine: false)
                    pathLength += 2
                }
            }

            for _ in 0..<longestPath - pathLength {
                console.print(" ", newLine: false)
            }

            console.print(" |")
            hr()
        }

        return .done(on: context.container)
    }
}

extension Data {
    fileprivate var string: String {
        return String(data: self, encoding: .utf8)!
    }
}
