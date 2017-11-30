extension String: Error { }

/// Types conforming to this protocol can be used by
/// the service container to disambiguate situations where
/// multiple services are available for a given `.make()` request.
public struct Config {
    fileprivate var preferences: [ServiceIdentifier: ServiceConfig]
    fileprivate var requirements: [ServiceIdentifier: ServiceConfig]

    public init() {
        self.preferences = [:]
        self.requirements = [:]
    }
    
    // config.prefer(BCryptConfig.self, tagged: "costly", in: .production)
    public mutating func prefer(
        _ type: Any.Type,
        tagged tag: String? = nil,
        for interface: Any.Type,
        neededBy client: Any.Type? = nil
    ) {
        let config = ServiceConfig(type: type, tag: tag)
        let id = ServiceIdentifier(interface: interface, client: client)
        preferences[id] = config
    }

    public mutating func require(
        _ type: Any.Type,
        tagged tag: String? = nil,
        for interface: Any.Type,
        neededBy client: Any.Type? = nil
    ) {
        let config = ServiceConfig(type: type, tag: tag)
        let id = ServiceIdentifier(interface: interface, client: client)
        requirements[id] = config
    }
    
    internal func choose(
        from available: [ServiceFactory],
        interface: Any.Type,
        for context: Context,
        neededBy client: Any.Type
    ) throws -> ServiceFactory {
        let specific = ServiceIdentifier(interface: interface, client: client)
        let all = ServiceIdentifier(interface: interface, client: nil)
        guard let preference = preferences[specific] ?? preferences[all] else {
            throw "Please choose which \(interface) you prefer, multiple are available: \(available.readable)"
        }

        let chosen = available.filter { factory in
            if let tag = preference.tag {
                guard factory.serviceTag == tag else {
                    return false
                }
            }

            return preference.type == factory.serviceType
        }

        guard chosen.count == 1 else {
            if chosen.count < 1 {
                throw "No service \(preference.type) (\(preference.tag ?? "*")) has been registered for \(interface)."
            } else {
                throw "Too many services were found"
            }

        }

        return chosen[0]
    }

    internal func approve(
        chosen: ServiceFactory,
        interface: Any.Type,
        for context: Context,
        neededBy client: Any.Type
    ) throws {
        let specific = ServiceIdentifier(interface: interface, client: client)
        let all = ServiceIdentifier(interface: interface, client: nil)
        guard let requirement = requirements[specific] ?? requirements[all] else {
            return
        }

        guard requirement.type == chosen.serviceType else {
            throw "\(interface) \(chosen.serviceType) is not required type \(requirement.type)."
        }

        if let tag = requirement.tag {
            guard chosen.serviceTag == tag else {
                throw "\(chosen.serviceType) tag \(chosen.serviceTag ?? "none") does not equal \(tag)"
            }
        }
    }
}

extension Array where Element == ServiceFactory {
    var readable: String {
        return map { factory in
            if let tag = factory.serviceTag {
                return "\(factory.serviceType) (\(tag))"
            } else {
                return "\(factory.serviceType)"
            }
        }.joined(separator: ", ")
    }
}

fileprivate struct ServiceIdentifier: Hashable {
    static func ==(lhs: ServiceIdentifier, rhs: ServiceIdentifier) -> Bool {
        return lhs.interface == rhs.interface && lhs.client == rhs.client
    }

    var hashValue: Int {
        if let client = client {
            return "\(interface)::\(client)".hashValue
        } else {
            return "\(interface)::*".hashValue
        }
    }

    var interface: Any.Type
    var client: Any.Type?
}

fileprivate struct ServiceConfig {
    var type: Any.Type
    var tag: String?
}
