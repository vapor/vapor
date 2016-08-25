import Turnstile
import HTTP

public extension Request {
    internal(set) public var user: Subject? {
        get {
            return storage["user"] as? Subject
        }
        set {
            storage["user"] = newValue
        }
    }
}
