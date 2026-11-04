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
    /// A `*` becomes a parameter named `anything`, since it matches one segment of any value, or
    /// `anything2` and so on when the route already uses that name. A `**` can't be described:
    /// OpenAPI's path parameters never span segments. Nor can a constant with braces, which a
    /// template would read as a parameter.
    init(_ components: [PathComponent]) throws(Unsupported) {
        var segments: [String] = []
        var parameters: [String] = []
        // Names the route gives its parameters, which a `*` mustn't take.
        var taken = Set<String>()
        for component in components {
            switch component {
            case .parameter(let name): taken.insert(name)
            case .partialParameter(_, _, let names): taken.formUnion(names.map(String.init))
            default: break
            }
        }
        var anythings = 0
        for component in components {
            switch component {
            case .constant(let constant):
                // A template reads braces as a parameter, and has no way to escape them.
                guard !constant.contains("{"), !constant.contains("}") else {
                    throw Unsupported(
                        reason:
                            "the path segment \"\(constant)\" has braces, which OpenAPI reads as a parameter. Start it with \":\" to make one."
                    )
                }
                segments.append(constant)
            case .parameter(let name):
                guard !name.contains("{"), !name.contains("}") else {
                    throw Unsupported(reason: "the path parameter \"\(name)\" has braces, which a template can't hold.")
                }
                segments.append("{\(name)}")
                parameters.append(name)
            case .partialParameter(let template, _, let names):
                // `user-{id}-details` is already a template. RoutingKit's docs show a leading `:`,
                // but it isn't stored, so drop one only if it's there.
                segments.append(template.hasPrefix(":") ? String(template.dropFirst()) : template)
                parameters += names.map(String.init)
            case .anything:
                var name: String
                repeat {
                    anythings += 1
                    name = anythings == 1 ? "anything" : "anything\(anythings)"
                } while taken.contains(name)
                segments.append("{\(name)}")
                parameters.append(name)
            case .catchall:
                throw Unsupported(
                    reason: "a catch-all path (**) can't be described in OpenAPI. Hide the route with hiddenFromOpenAPI()."
                )
            }
        }
        self.path = OpenAPI.Path(segments)
        self.parameters = parameters
    }

    /// A path OpenAPI can't describe, and why.
    struct Unsupported: Error {
        var reason: String
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
