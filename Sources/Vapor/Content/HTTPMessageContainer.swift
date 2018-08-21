/// A `Container` that has a reference to a mutable `HTTPMessage`.
public protocol HTTPMessageContainer: Container {
    /// Associated `HTTPMessage` type.
    associatedtype HTTPMessageType: HTTPMessage

    /// This `Container`'s mutable `HTTPMessage`.
    var http: HTTPMessageType { get set }
}
