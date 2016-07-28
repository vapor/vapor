import Routing
import Engine

extension RouteBuilder where Value == HTTPResponder {
    public func add(
        _ method: HTTPMethod,
        path string: String,
        closure: (HTTPRequest) throws -> (HTTPResponseRepresentable)
    ) {
        let basic = HTTPRequest.Handler { request in
            return try closure(request).makeResponse(for: request)
        }
        var path: [String] = ["*", method.description]
        path += string.components
        add(path: path, handler: .static(basic))
    }
}

extension String {
    private var components: [String] {
        return characters
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0) }
    }
}
