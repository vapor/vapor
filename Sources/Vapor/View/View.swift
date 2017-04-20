import Core
import HTTP

/// Represents a rendered view.
public final class View {
    public let data: Bytes

    public init(data: Bytes) {
        self.data = data
    }
}

/// Allow views to easily convert to
/// and from bytes for interfacing
/// with other byte based processes.
extension View: BytesConvertible {
    public func makeBytes() -> Bytes {
        return data
    }

    public convenience init(bytes: Bytes) {
        self.init(data: bytes)
    }
}

///Allows Views to be returned in Vapor closures
extension View: ResponseRepresentable {
    public func makeResponse() -> Response {
        return Response(status: .ok, headers: [
            "Content-Type": "text/html; charset=utf-8"
        ], body: .data(data))
    }
}
