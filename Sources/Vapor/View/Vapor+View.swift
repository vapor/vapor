import Async
import HTTP

extension View: Content {
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .html
    }
}
