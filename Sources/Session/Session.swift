/// Use the Session class to store sensitive
/// information for individual users of your droplet
/// such as API keys or login tokens.
///
/// Access the current Droplet's Sessions using
/// `drop.sessions`.
public final class Session {
    /// The unique identifier for this session.
    public let identifier: String

    /// If true, the session should be destroyed
    /// next time the SessionMiddleware runs.
    internal private(set) var shouldDestroy: Bool

    /// If true, the session should be created
    /// next time the SessionMiddleware runs.
    internal private(set) var shouldCreate: Bool

    /// This session's data.
    public var data: SessionData {
        didSet {
            shouldCreate = true
        }
    }

    /// Creates a new Session.
    public init(identifier: String, data: SessionData = .empty) {
        self.identifier = identifier
        self.data = data
        self.shouldCreate = false
        self.shouldDestroy = false
    }

    /// Marks this Session to be destroyed.
    public func destroy() {
        shouldDestroy = true
    }
}
