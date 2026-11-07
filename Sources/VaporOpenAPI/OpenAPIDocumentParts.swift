#if OpenAPI
import HTTPTypes
import OpenAPIKit
import Vapor

extension OpenAPI.HttpMethod {
    /// The OpenAPI method for a route's method, including custom ones.
    init(_ method: HTTPRequest.Method) {
        self = OpenAPI.HttpMethod(rawValue: method.rawValue) ?? .other(method.rawValue)
    }
}

extension [Route] {
    /// The security schemes the routes' auth refers to, by ID, in the order they first appear.
    ///
    /// Throws when two different schemes share an ID, since one would silently replace the other,
    /// or when an ID can't be a component's key. Schemes that differ only in their descriptions
    /// are the same scheme, and keep the first one's.
    func securitySchemes() throws -> OpenAPI.ComponentReferenceDictionary<OpenAPI.SecurityScheme> {
        var schemes: OpenAPI.ComponentReferenceDictionary<OpenAPI.SecurityScheme> = [:]
        // The route each ID was first seen on, for the error when another uses it differently.
        var firstRoutes: [OpenAPI.ComponentKey: Route] = [:]
        for route in self {
            for auth in route.openAPIRoute.auth {
                guard let key = OpenAPI.ComponentKey(rawValue: auth.id) else {
                    throw OpenAPIDocumentError(
                        route: route.description,
                        reason:
                            "its auth id \"\(auth.id)\" isn't a valid component name. Use only letters, digits, \".\", \"-\" and \"_\"."
                    )
                }
                if let first = schemes[key]?.b, let firstRoute = firstRoutes[key] {
                    guard first.type == auth.scheme.type else {
                        throw OpenAPIDocumentError(
                            route: route.description,
                            reason:
                                "its auth \"\(auth.id)\" is a different scheme from \(firstRoute.description)'s. Give one of them its own id."
                        )
                    }
                } else {
                    schemes[key] = .b(auth.scheme)
                    firstRoutes[key] = route
                }
            }
        }
        return schemes
    }

    /// Throws when two routes share an operation ID, which client generators can't tell apart.
    ///
    /// Usually the ID was set on a group, which gives it to every route in the group.
    func requireUniqueOperationIDs() throws {
        var first: [String: Route] = [:]
        for route in self {
            guard let id = route.openAPIRoute.operationID else { continue }
            if let other = first[id] {
                throw OpenAPIDocumentError(
                    route: route.description,
                    reason: "its operation ID \"\(id)\" is also \(other.description)'s. Set operationID on a single route."
                )
            }
            first[id] = route
        }
    }

    /// The tags the routes use, in the order they first appear, or `nil` if none do.
    var tags: [OpenAPI.Tag]? {
        var seen = Set<String>()
        let names = flatMap(\.openAPIRoute.tags).filter { seen.insert($0).inserted }
        return names.isEmpty ? nil : names.map { OpenAPI.Tag(name: $0) }
    }
}
#endif
