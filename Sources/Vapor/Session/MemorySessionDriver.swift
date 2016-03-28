import libc

/**
    The `MemorySessionDriver` stores session data
    in a Swift `Dictionary`. This means all session
    data will be purged if the server is restarted.
*/
public class MemorySessionDriver: SessionDriver {
    var sessions = [String: [String: String]]()
    private var sessionsLock = Lock()
    
    public var app: Application
    
    public init(application: Application) {
        app = application
    }
    
    public func valueFor(key key: String, identifier: String) -> String? {
        var value: String?
        sessionsLock.locked {
            value = sessions[identifier]?[key]
        }
        
        return value
    }
    
    public func set(value: String?, forKey key: String, identifier: String) {
        sessionsLock.locked {
            if sessions[identifier] == nil {
                sessions[identifier] = [String: String]()
            }
            
            sessions[identifier]?[key] = value
        }
    }
    
    public func makeSessionIdentifier() -> String {
        var identifier = String(time(nil))
        identifier += "v@p0r"
        identifier += String(Int.random(min: 0, max: 9999))
        identifier += "s3sS10n"
        identifier += String(Int.random(min: 0, max: 9999))
        identifier += "k3y"
        identifier += String(Int.random(min: 0, max: 9999))
        return app.hash.make(identifier)
    }
    
    public func destroy(identifier: String) {
        sessionsLock.locked {
            sessions[identifier] = nil
        }
    }
}
