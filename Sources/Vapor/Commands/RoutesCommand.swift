import Command
import Console
import Foundation

/// Displays all registered routes.
public struct RoutesCommand: Command {
    /// See Command.arguments
    public let arguments: [Argument] = []

    /// See Runnable.options
    public let options: [Option] = []

    /// See Runnable.help
    public let help: [String] = ["Displays all registered routes"]

    /// The server to boot.
    public let router: Router

    /// Create a new serve command.
    public init(router: Router) {
        self.router = router
    }

    /// See Runnable.run
    public func run(using console: Console, with input: Input) throws {
        var longestMethod = 0
        var longestPath = 0

        for route in router.routes {
            guard let first = route.path.first, case .constants(let method) = first else {
                continue
            }

            if method[0].count > longestMethod {
                longestMethod = method[0].count
            }

            var pathLength = 0

            for path in route.path[1...] {
                switch path {
                case .constants(let consts):
                    pathLength += consts.count
                    for const in consts {
                        pathLength += const.count + 1 // /const
                    }
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

            guard let first = route.path.first, case .constants(let method) = first else {
                continue
            }

            console.success(method[0].string, newLine: false)

            for _ in 0..<longestMethod - method[0].count {
                console.print(" ", newLine: false)
            }

            console.print(" | ", newLine: false)

            var pathLength = 0

            route.path[1...].forEach { comp in
                switch comp {
                case .constants(let consts):
                    for const in consts {
                        console.info("/", newLine: false)
                        console.print(const.string, newLine: false)
                        pathLength += const.count + 1
                    }
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
    }
}

extension Data {
    fileprivate var string: String {
        return String(data: self, encoding: .utf8)!
    }
}
