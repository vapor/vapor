extension ObjectIdentifier: @retroactive CustomStringConvertible {
    /// Create a unique description. ex. 7ffbd0704a60
    public var description: String {
        return String(format: "%x", unsafeBitCast(self, to: UInt.self))
    }
}

extension Application {
    public var id: ServiceID {
        .init(_application: self)
    }
    
    public struct ServiceID: Sendable {
        public let _application: Application
        
        private struct Key: StorageKey {
            typealias Value = Storage
        }
        
        public final actor Storage: Sendable {
            var id: ServiceIdentifier?
            
            init() {
                self.id = nil
            }
            
            func setID(_ newID: ServiceIdentifier?) {
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
        
        var description: ServiceIdentity? {
            get async { await ServiceIdentity(self.storage.id) }
        }
        
        public func register(_ newID: ServiceIdentifier?) async {
            await storage.setID(newID)
        }
    }
}

public final actor ServiceIdentifier: Sendable {
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

extension ServiceIdentifier: CustomStringConvertible {
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

struct ServiceIdentity: Codable {
    let id: String
    let label: String
    let version: Double
    
    init?(_ from: ServiceIdentifier?) async {
        guard let from = from else { return nil }
        
        let serviceidentifierString = await from.string
        self.init(stringLiteral: serviceidentifierString)
    }
}

extension ServiceIdentity: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    public init(stringLiteral value: String) {
        let componentID = value.split(separator: ":")
        let componentLabel = componentID[1].split(separator: "@")
        
        self.id = String(componentID[0])
        self.label = String(componentLabel[0])
        self.version = Double(componentLabel[1]) ?? 0.0
    }
}

extension ServiceIdentity: CustomStringConvertible {
    public var description: String {
        return "\(self.id):\(self.label)@\(self.version)"
    }
}
