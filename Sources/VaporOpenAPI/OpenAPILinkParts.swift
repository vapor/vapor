#if OpenAPI
import OpenAPIKit
import Vapor

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One end of a link, on the operation a route became.
struct LinkEnd {
    var end: OpenAPILink
    var key: LinkKeyID
    var path: OpenAPI.Path
    var method: OpenAPI.HttpMethod
    var operationID: String?
    /// The route, such as `GET /users/:id`, for errors.
    var route: String

    /// Whether the value is found in a response, so the link starts here.
    var isSource: Bool {
        if case .response = end.location { true } else { false }
    }

    /// The ends of `route`'s links, sorted so they come out the same on every run.
    static func ends(of route: Route, path: OpenAPI.Path) -> [LinkEnd] {
        // `links` is a dictionary, whose order changes from run to run.
        route.openAPIRoute.links.sorted { "\($0.key.location)|\($0.key.name)" < "\($1.key.location)|\($1.key.name)" }
            .map { end, key in
                LinkEnd(
                    end: end,
                    key: key.linkKeyID,
                    path: path,
                    method: OpenAPI.HttpMethod(route.method),
                    operationID: route.openAPIRoute.operationID,
                    route: route.description
                )
            }
    }
}

extension OpenAPI.Link {
    /// A link that takes `source`'s value into `target`'s request.
    ///
    /// Refers to the target by its operation ID, or by a JSON pointer to it when it has none.
    /// Throws for a field of the target's body: a link can only set the whole body.
    init(from source: LinkEnd, to target: LinkEnd) throws {
        // A source is always in a response, where every location has an expression.
        guard let value = source.end.expression else {
            preconditionFailure("\(source.end.location) can't be a link's source")
        }
        let operation: Either<URL, String> = target.operationID.map { .b($0) } ?? .a(Self.reference(to: target))
        let description = target.key.type.description
        switch target.end.location {
        case .request(.body):
            guard target.end.name.isEmpty else {
                throw OpenAPIDocumentError(
                    route: target.route,
                    reason: "a link can only set a whole request body, not \"\(target.end.name)\" in it. Use an empty name."
                )
            }
            self.init(operation: operation, requestBody: .a(value), description: description)
        case .request(let location):
            // Qualified, such as `path.id`, in case the name is used in two locations.
            self.init(
                operation: operation,
                parameters: ["\(location.rawValue).\(target.end.name)": .a(value)],
                description: description
            )
        case .response:
            preconditionFailure("A link's target is always in a request")
        }
    }

    /// The key a link is stored under, such as `ResponseBodyIdGetUserRequestPathId`.
    static func name(from source: LinkEnd, to target: LinkEnd) -> String {
        let operation = target.operationID ?? operationName(target)
        return (source.end.identifier + operation.componentKeySafe.upFirst + target.end.identifier).componentKeySafe
    }

    /// A name for an operation with no ID, from its method and path, such as `GetPetsById`.
    private static func operationName(_ end: LinkEnd) -> String {
        let segments = end.path.components.map { segment in
            segment.hasPrefix("{") && segment.hasSuffix("}")
                ? "By" + String(segment.dropFirst().dropLast()).upFirst
                : segment.upFirst
        }
        return end.method.rawValue.lowercased().upFirst + segments.joined()
    }

    /// A JSON pointer to `end`'s operation, such as `#/paths/~1users~1%7Bid%7D/get`, or for a
    /// method OpenAPI doesn't name, `#/paths/~1files/additionalOperations/COPY`.
    private static func reference(to end: LinkEnd) -> URL {
        let path = end.path.rawValue.replacing("~", with: "~0").replacing("/", with: "~1")
        let operation =
            switch end.method {
            case .other(let method): "additionalOperations/\(method.replacing("~", with: "~0").replacing("/", with: "~1"))"
            case let method: method.rawValue.lowercased()
            }
        let pointer = "/paths/\(path)/\(operation)"
        // Only the fragment is encoded, so the `#` that starts it stays as it is.
        let encoded = pointer.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? pointer
        guard let url = URL(string: "#" + encoded) else {
            preconditionFailure("#\(encoded) isn't a valid URL")
        }
        return url
    }
}

extension OpenAPI.PathItem.Map {
    /// Refers the success response of the operation at `path` and `method` to link `name`.
    mutating func addLink(named name: String, to path: OpenAPI.Path, method: OpenAPI.HttpMethod) {
        guard var item = self[path]?.pathItemValue,
            var operation = item[method],
            let status = operation.responses.keys.first,
            var response = operation.responses[status]?.responseValue
        else { return }
        response.links[name] = .reference(.component(named: name))
        operation.responses[status] = .b(response)
        item.set(operation: operation, for: method)
        self[path] = .b(item)
    }
}
#endif
