public enum AdministrationQuery {
    // TODO: Collation, character set
    public static func createDatabase(named name: String, ifNotExists: Bool = true) -> Query {
        let ifNotExists = ifNotExists ? "IF NOT EXISTS" : ""

        return "CREATE DATABASE \(ifNotExists) \(name)"
    }
}


