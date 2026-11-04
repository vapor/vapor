#if OpenAPI
import Vapor

/// Adds OpenAPI details to every route registered through it, then passes the route on.
///
/// The same pattern as Vapor's `grouped(_:)` builders.
struct OpenAPIRoutesGroup: RoutesBuilder {
    let root: any RoutesBuilder
    let map: (inout OpenAPIRoute) -> Void

    func add(_ route: Route) {
        var route = route
        map(&route.openAPIRoute)
        root.add(route)
    }
}

extension OpenAPIRoute {
    /// Adds `outer`'s details, from a builder further out, without overriding this route's own.
    ///
    /// Builders closest to the route run first, so by the time a group's details arrive, the
    /// route's own are already set.
    mutating func merge(_ outer: OpenAPIRoute) {
        summary = summary ?? outer.summary
        description = description ?? outer.description
        operationID = operationID ?? outer.operationID
        body = body ?? outer.body
        response = response ?? outer.response
        responseDescription = responseDescription ?? outer.responseDescription
        statusCode = statusCode ?? outer.statusCode

        tags = Self.appending(outer.tags, tags, by: \.self)
        // A route's scopes for a scheme replace its group's, rather than its group's winning.
        auth = outer.auth.filter { scheme in !auth.contains { $0.id == scheme.id } } + auth
        // By description rather than \.self: `HTTPMediaType.==` treats `*/*` as equal to any type.
        contentTypes = Self.appending(outer.contentTypes, contentTypes, by: \.description)
        responseContentTypes = Self.appending(outer.responseContentTypes, responseContentTypes, by: \.description)

        query = Self.combined(outer.query, query)
        headers = Self.combined(outer.headers, headers)
        path = Self.combined(outer.path, path)
        cookies = Self.combined(outer.cookies, cookies)
        responseHeaders = Self.combined(outer.responseHeaders, responseHeaders)

        links.merge(outer.links) { ours, _ in ours }
        deprecated = deprecated ?? outer.deprecated
        isHidden = isHidden || outer.isHidden
    }

    /// `outer`'s elements, then `ours`, keeping the first of any with the same key.
    private static func appending<T, Key: Hashable>(
        _ outer: [T],
        _ ours: [T],
        by key: (T) -> Key
    ) -> [T] {
        var seen = Set<Key>()
        return (outer + ours).filter { seen.insert(key($0)).inserted }
    }

    /// Both sets of parameters, `outer`'s first, or whichever one is set.
    private static func combined(
        _ outer: OpenAPIParameters?,
        _ ours: OpenAPIParameters?
    ) -> OpenAPIParameters? {
        switch (outer, ours) {
        case (nil, nil):
            nil
        case (let one?, nil), (nil, let one?):
            one
        case (let outer?, let ours?):
            .all(of: [outer, ours])
        }
    }
}
#endif
