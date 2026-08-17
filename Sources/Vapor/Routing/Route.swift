public import RoutingKit
public import HTTPTypes

public struct Route: CustomStringConvertible, Sendable {
    public var method: HTTPRequest.Method
    public var path: [PathComponent]
    public var responder: any Responder
    public var requestType: Any.Type
    public var responseType: Any.Type
    public var routeDescription: String?

    public var description: String {
        let path = path.map { "\($0)" }.joined(separator: "/")
        return "\(method.rawValue) /\(path)"
    }

    public init(
        method: HTTPRequest.Method,
        path: [PathComponent],
        responder: any Responder,
        requestType: Any.Type,
        responseType: Any.Type,
        routeDescription: String? = nil
    ) {
        self.method = method
        self.path = path
        self.responder = responder
        self.requestType = requestType
        self.responseType = responseType
        self.routeDescription = routeDescription
    }
}
