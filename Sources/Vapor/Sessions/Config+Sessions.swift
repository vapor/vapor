import Sessions
import Cache

extension SessionsMiddleware: Service {
    public convenience init?(_ drop: Droplet) throws {
        let sessions = try drop.make(SessionsProtocol.self)
        self.init(sessions)
    }

    public static var name: String {
        return "sessions"
    }
}

extension MemorySessions: Service {
    public static var name: String {
        return "memory"
    }
    
    public convenience init?(_ drop: Droplet) throws {
        if drop.services.multiple(support: SessionsProtocol.self) {
            guard drop.config["droplet", "sessions"]?.string == "memory" else {
                return nil
            }
        }
        
        self.init()
    }
}

extension CacheSessions: Service {
    public static var name: String {
        return "cache"
    }
    
    public convenience init?(_ drop: Droplet) throws {
        if drop.services.multiple(support: SessionsProtocol.self) {
            guard drop.config["droplet", "sessions"]?.string == "cache" else {
                return nil
            }
        }
        
        let cache = try drop.make(CacheProtocol.self)
        self.init(cache)
    }
}
