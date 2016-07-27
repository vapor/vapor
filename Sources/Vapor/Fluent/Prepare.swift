import Console

/**
    Runs the droplet's `Preparation`s.
*/
public struct Prepare: Command {
    public let id: String = "prepare"

    public let signature: [Argument] = [
        Option(name: "revert"),
    ]

    public let help: [String] = [
        "runs the droplet's preparations"
    ]

    public let console: ConsoleProtocol
    public let preparations: [Preparation.Type]
    public let database: Database?

    public init(
        console: ConsoleProtocol,
        preparations: [Preparation.Type],
        database: Database?
    ) {
        self.console = console
        self.preparations = preparations
        self.database = database
    }

    public func run(arguments: [String]) throws {
        guard preparations.count > 0 else {
            return
        }

        guard let database = database else {
            throw CommandError.general("Can not run preparations, droplet has no database")
        }

        if arguments.option("revert").bool == true {
            guard console.confirm("Are you sure you want to revert the database?", style: .warning) else {
                console.error("Reversion cancelled")
                return
            }

            for preparation in preparations {
                let name = preparation.name
                let hasPrepared: Bool

                do {
                    hasPrepared = try database.hasPrepared(preparation)
                } catch {
                    console.error("Failed to start preparation")
                    throw CommandError.general("\(error)")
                }

                if hasPrepared {
                    print("Reverting \(name)")
                    try preparation.revert(database)
                    console.success("Reverted \(name)")
                }
            }

            console.print("Removing metadata")
            let schema = Schema.delete(entity: "fluent")
            try database.driver.schema(schema)
            console.success("Reversion complete")
        } else {
            for preparation in preparations {
                let name = preparation.name

                let hasPrepared: Bool

                do {
                    hasPrepared = try database.hasPrepared(preparation)
                } catch {
                    console.error("Failed to start preparation")
                    throw CommandError.general("\(error)")
                }

                if !hasPrepared {
                    print("Preparing \(name)")
                    do {
                        try database.prepare(preparation)
                        console.success("Prepared '\(name)'")
                    } catch PreparationError.automationFailed(let string) {
                        console.error("Automatic preparation for \(name) failed.")
                        throw CommandError.general("\(string)")
                    } catch {
                        console.error("Failed to prepare \(name)")
                        throw CommandError.general("\(error)")
                    }
                }
            }

            console.info("Database prepared")
        }
    }
}
