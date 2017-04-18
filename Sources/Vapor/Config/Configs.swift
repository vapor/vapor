@_exported import Configs

// MARK: Lazy

extension Config {
    internal typealias Lazy<E> = (Config) throws -> (E)
}

extension ConfigInitializable {
    internal static func lazy() -> Config.Lazy<Self> {
        return { c in try Self.init(config: c) }
    }
}
