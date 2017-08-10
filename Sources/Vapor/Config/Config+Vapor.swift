import Mapper
import Configs

// MARK: Environment

extension Config {
    public var environment: Environment {
        get {
            if let value = self[Droplet.configKey, "environment"]?.string {
                return Environment(id: value)
            } else {
                return .production
            }
        }
        set {
            self[Droplet.configKey, "environment"] = .string(newValue.description)
        }
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
