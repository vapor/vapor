import Mapper
import Configs

// MARK: Environment

extension Config {
    public var environment: Environment {
        get {
            return (try? self[Droplet.configKey, "environment"].converted(to: Environment.self)) ?? .production
        }
        set {
            self[Droplet.configKey, "environment"] = (try? newValue.converted(to: Config.self)) ?? .null
        }
    }
}

extension Environment: MapConvertible {
    public init(map: Map) throws {
        guard let string = map.string else {
            throw "could not convert map \(map) to Environment"
        }

        self.init(id: string)
    }

    public func makeMap() throws -> Map {
        return .string(description)
    }
}

// MARK: Arguments

extension Config {
    public var arguments: [String] {
        get {
            return (try? self[Droplet.configKey, "arguments"].converted(to: [String].self)) ?? []
        }
        set {
            self[Droplet.configKey, "arguments"] = (try? newValue.converted(to: Config.self)) ?? .null
        }
    }
}
