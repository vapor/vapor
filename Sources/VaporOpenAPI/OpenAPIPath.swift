#if OpenAPI
import OpenAPIKit
import RoutingKit
import Vapor

/// A route's path as an OpenAPI template, such as `/users/{id}`, and the parameters it names.
struct OpenAPIPath {
    var path: OpenAPI.Path
    /// The names of the path parameters, in order. Each is a required string unless typed.
    var parameters: [String]

    /// The template for `components`.
    ///
    /// A `*` becomes a parameter named `anything`, since it matches one segment of any value. A
    /// `**` can't be described: OpenAPI's path parameters never span segments.
    init(_ components: [PathComponent]) throws(Unsupported) {
        var segments: [String] = []
        var parameters: [String] = []
        var anythings = 0
        for component in components {
            switch component {
            case .constant(let constant):
                segments.append(constant)
            case .parameter(let name):
                segments.append("{\(name)}")
                parameters.append(name)
            case .partialParameter(let template, _, let names):
                // `user-{id}-details` is already a template. RoutingKit's docs show a leading `:`,
                // but it isn't stored, so drop one only if it's there.
                segments.append(template.hasPrefix(":") ? String(template.dropFirst()) : template)
                parameters += names.map(String.init)
            case .anything:
                anythings += 1
                let name = anythings == 1 ? "anything" : "anything\(anythings)"
                segments.append("{\(name)}")
                parameters.append(name)
            case .catchall:
                throw Unsupported()
            }
        }
        self.path = OpenAPI.Path(segments)
        self.parameters = parameters
    }

    struct Unsupported: Error {
        var reason: String {
            "a catch-all path (**) can't be described in OpenAPI. Hide the route with hiddenFromOpenAPI()."
        }
    }
}

extension OpenAPI.ContentType {
    /// The content types for `mediaTypes`, or JSON when there are none.
    ///
    /// Parameters such as `charset=utf-8` are left out: Vapor's `.json` carries one, and tools
    /// expect content keyed by the bare type.
    static func types(for mediaTypes: [HTTPMediaType]) -> [OpenAPI.ContentType] {
        guard !mediaTypes.isEmpty else { return [.json] }
        var seen = Set<String>()
        return mediaTypes.compactMap { mediaType in
            let bare = "\(mediaType.type)/\(mediaType.subType)"
            guard seen.insert(bare).inserted else { return nil }
            return OpenAPI.ContentType(rawValue: bare)
        }
    }
}
#endif
