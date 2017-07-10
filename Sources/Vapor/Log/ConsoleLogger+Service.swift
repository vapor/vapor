import Console

extension ConsoleLogger: Service {
    /// See Service.name
    public static var name: String {
        return "console"
    }

    /// See Service.make
    public static func make(for drop: Droplet) throws -> ConsoleLogger? {
        return try .init(drop.make(ConsoleProtocol.self))
    }
}
