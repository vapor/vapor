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
        var schemes: [String: (auth: OpenAPIAuth, route: Route)] = [:]
        var order: [String] = []
        for route in self {
            for auth in route.openAPIRoute.auth {
                guard OpenAPI.ComponentKey(rawValue: auth.id) != nil else {
                    throw OpenAPIDocumentError(
                        route: route.description,
                        reason:
                            "its auth id \"\(auth.id)\" isn't a valid component name. Use only letters, digits, \".\", \"-\" and \"_\"."
                    )
                }
                if let first = schemes[auth.id] {
                    guard first.auth.scheme.type == auth.scheme.type else {
                        throw OpenAPIDocumentError(
                            route: route.description,
                            reason:
                                "its auth \"\(auth.id)\" is a different scheme from \(first.route.description)'s. Give one of them its own id."
                        )
                    }
                } else {
                    schemes[auth.id] = (auth, route)
                    order.append(auth.id)
                }
            }
        }
        var dictionary: OpenAPI.ComponentReferenceDictionary<OpenAPI.SecurityScheme> = [:]
        for id in order {
            // Every ID was checked above.
            guard let key = OpenAPI.ComponentKey(rawValue: id), let auth = schemes[id]?.auth else { continue }
            dictionary[key] = .b(auth.scheme)
        }
        return dictionary
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
