extension ObjectIdentifier: @retroactive CustomStringConvertible {
    /// Create a unique description. ex. 7ffbd0704a60
    public var description: String {
        return String(format: "%x", unsafeBitCast(self, to: UInt.self))
    }
}

extension Application {
    public var id: ServiceIdentity {
        .init(_application: self)
    }
    
    public struct ServiceIdentity: Sendable {
        public let _application: Application
        
        private struct Key: StorageKey {
            typealias Value = Storage
        }
        
        public final actor Storage: Sendable {
            var id: ServiceIdentifiable?
            
            init() {
                self.id = nil
            }
            
            func setID(_ newID: ServiceIdentifiable?) {
                self.id = newID
            }
        }
        
        init(_application: Application) {
            self._application = _application
        }
        
        private var storage: Storage {
            if let existing = self._application.storage[Key.self] {
                return existing
            } else {
                let new = Storage()
                self._application.storage[Key.self] = new
                return new
            }
        }
        
        var description: ServiceIdentifier? {
            get async { await ServiceIdentifier(self.storage.id) }
        }
        
        public func register(_ newID: ServiceIdentifiable?) async {
            await storage.setID(newID)
        }
    }
}

public final actor ServiceIdentifiable: Sendable {
    private var id = Set<ObjectIdentifier>()
    private let label: String
    private var version: Double
    
    init<App: Application>(_ type: App.Type, label: String, version: Double = 0.0) async {
        let id = ObjectIdentifier(type)
        let (inserted, _) = self.id.insert(id)
        guard inserted else { fatalError("App already running.") }
        
        self.label = label
        self.version = version
    }
}

extension ServiceIdentifiable: CustomStringConvertible {
    public nonisolated var description: String {
        return "[invalid]:\(label)@[invalid]"
    }
    
    public var string: String {
        get async {
            guard let id = self.id.first else { fatalError("App is running without a valid identifier.") }
            return "\(id.description):\(label)@\(version))"
        }
    }
}

struct ServiceIdentifier: Codable {
    let id: String
    let label: String
    let version: Double
    
    init?(_ from: ServiceIdentifiable?) async {
        guard let from = from else { return nil }
        
        let serviceidentityString = await from.string
        self.init(stringLiteral: serviceidentityString)
    }
}

extension ServiceIdentifier: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    public init(stringLiteral value: String) {
        let componentID = value.split(separator: ":")
        let componentLabel = componentID[1].split(separator: "@")
        
        self.id = String(componentID[0])
        self.label = String(componentLabel[0])
        self.version = Double(componentLabel[1]) ?? 0.0
    }
}

extension ServiceIdentifier: CustomStringConvertible {
    public var description: String {
        return "\(self.id):\(self.label)@\(self.version)"
    }
}
