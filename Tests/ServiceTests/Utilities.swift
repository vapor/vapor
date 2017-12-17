import Async
import JunkDrawer
import Service

// MARK: Log

protocol Log {
    func log(_ string: String)
}

class PrintLog: Log {
    func log(_ string: String) {
        print("[Print Log] \(string)")
    }
}

extension PrintLog: ServiceType {
    static let serviceName = "print"
    static let serviceSupports: [Any.Type] = [Log.self]
    static func makeService(for container: Container) throws -> Self {
        return .init()
    }
}


class AllCapsLog: Log {
    func log(_ string: String) {
        print(string.uppercased())
    }
}

extension AllCapsLog: ServiceType {
    static let serviceName = "all-caps"
    static let serviceSupports: [Any.Type] = [Log.self]
    static func makeService(for container: Container) throws -> Self {
        return .init()
    }
}


class ConfigurableLog: Log {
    let myConfig: String
    
    init(config: String) { self.myConfig = config }
    func log(_ string: String) {
        print("[Config \(myConfig) Log] - \(string)")
    }
}

class AllCapsProvider: Provider {
    static let repositoryName = "all-caps-provider"

    func register(_ services: inout Services) throws {
        services.register(AllCapsLog.self)
    }

    func boot(_ container: Container) throws { }
}

// MARK: BCrypt

protocol Hasher {
    func hash(_ string: String) -> String
}

class BCryptHasher: Hasher {
    let cost: Int

    init(cost: Int) {
        self.cost = cost
    }

    func hash(_ string: String) -> String {
        return "$2y:\(cost):\(string)"
    }
}


extension BCryptHasher: ServiceType {
    static var serviceName: String {
        return "bcrypt"
    }

    static var serviceSupports: [Any.Type] {
        return [Hasher.self]
    }

    static func makeService(for container: Container) throws -> Self {
        let config = try container.make(BCryptConfig.self, for: BCryptHasher.self)
        return .init(cost: config.cost)
    }
}



struct BCryptConfig {
    let cost: Int
    init(cost: Int) {
        self.cost = cost
    }
}

extension BCryptConfig: ServiceType {
    static var serviceName: String {
        return "bcrypt"
    }

    static var serviceSupports: [Any.Type] {
        return []
    }

    static func makeService(for container: Container) throws -> BCryptConfig {
        let cost: Int

        switch container.environment {
        case .production:
            cost = 12
        default:
            cost = 4
        }

        return BCryptConfig(cost: cost)
    }
}
