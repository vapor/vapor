/**
    Runs the application's `Preparation`s.
*/
public struct Prepare: Command {
    public static let id: String = "prepare"

    public static let signature: [Signature] = [
        Option("revert"),
    ]

    public static let help: [String] = [
        "runs the application's preparations"
    ]

    public let app: Application
    public init(app: Application) {
        self.app = app
    }

    public func run() throws {
        guard app.preparations.count > 0 else {
            return
        }

        guard let database = app.database else {
            throw CommandError.custom("Can not run preparations, application has no database")
        }

        if option("revert").bool == true {
            throw CommandError.custom("Revert is not yet supported")
        } else {
            for preparation in app.preparations {
                let name = preparation.name

                let hasPrepared: Bool

                do {
                    try hasPrepared = database.hasPrepared(preparation)
                } catch {
                    self.error("Failed to start preparation")
                    throw CommandError.custom("\(error)")
                }

                if !hasPrepared {
                    print("Preparing '\(name)'")
                    do {
                        try database.prepare(preparation)
                        success("Prepared '\(name)'")
                    } catch PreparationError.automationFailed(let string) {
                        self.error("Automatic preparation for '\(name)' failed.")
                        throw CommandError.custom("\(string)")
                    } catch {
                        self.error("Failed to prepare '\(name)'")
                        throw CommandError.custom("\(error)")
                    }
                }
            }

            info("Database prepared")
        }
    }
}