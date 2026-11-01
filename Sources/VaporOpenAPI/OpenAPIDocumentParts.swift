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
    /// Throws when two different schemes share an ID, since one would silently replace the other.
    func securitySchemes() throws -> OpenAPI.ComponentReferenceDictionary<OpenAPI.SecurityScheme> {
        var schemes: [String: (auth: OpenAPIAuth, route: Route)] = [:]
        var order: [String] = []
        for route in self {
            for auth in route.openAPIRoute.auth {
                if let first = schemes[auth.id] {
                    guard first.auth.scheme == auth.scheme else {
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
            guard let key = OpenAPI.ComponentKey(rawValue: id), let auth = schemes[id]?.auth else { continue }
            dictionary[key] = .b(auth.scheme)
        }
        return dictionary
    }

    /// The tags the routes use, in the order they first appear, or `nil` if none do.
    var tags: [OpenAPI.Tag]? {
        var seen = Set<String>()
        let names = flatMap(\.openAPIRoute.tags).filter { seen.insert($0).inserted }
        return names.isEmpty ? nil : names.map { OpenAPI.Tag(name: $0) }
    }
}
#endif
