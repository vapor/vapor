import Async
import HTTP
import Leaf

extension View: Content {
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .html
    }
}
