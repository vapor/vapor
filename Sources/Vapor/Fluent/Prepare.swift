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
            throw CommandError.custom("Cannot run preparations, application has no database.")
        }

        if option("revert").bool == true {
            throw CommandError.custom("Revert is not yet supported.")
        } else {
            for preparation in app.preparations {
                let name = preparation.name

                print("Preparing '\(name)'")
                do {
                    try database.prepare(preparation)
                    success("Prepared '\(name)'")
                } catch PreparationError.alreadyPrepared {
                    print("... already prepared")
                } catch {
                    self.error("Failed to prepare '\(name)'")
                    print("\(error)")
                    return
                }
            }

            info("Database prepared.")
        }
    }
}