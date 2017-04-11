import Node

/// Use the Session class to store sensitive
/// information for individual users of your droplet
/// such as API keys or login tokens.
///
/// Access the current Droplet's Sessions using
/// `drop.sessions`.
public final class Session {
    public let identifier: String
    
    public var data: Node {
        didSet {
            shouldCreate = true
        }
    }
    
    internal private(set) var shouldDestroy = false
    internal private(set) var shouldCreate = false
    
    public init(identifier: String, data: Node = [:]) {
        self.identifier = identifier
        self.data = data
    }
    
    public func destroy() {
        shouldDestroy = true
    }
}
