#if OpenAPI
import OpenAPIKit
public import Vapor

extension Routes {
    /// An OpenAPI document describing these routes, except those hidden from it.
    ///
    /// ```swift
    /// let document = try app.routes.openAPI(info: OpenAPIInfo(title: "Pets", version: "1.0.0"))
    /// ```
    ///
    /// Throws when a route can't be described, naming the route and why.
    public func openAPI(info: OpenAPIInfo) throws -> OpenAPIDocument {
        let routes = all.filter { !$0.openAPIRoute.isHidden }
        var components = SchemaComponents()
        var paths: OpenAPI.PathItem.Map = [:]
        var ends = [LinkEnd]()

        for route in routes {
            let (path, operation) = try route.operation(into: &components)
            var item = paths[path]?.pathItemValue ?? OpenAPI.PathItem()
            item.set(operation: operation, for: OpenAPI.HttpMethod(route.method))
            paths[path] = .b(item)
            ends += LinkEnd.ends(of: route, path: path)
        }

        let links = try Self.links(from: ends, into: &paths)
        let securitySchemes = try routes.securitySchemes()
        let openAPIComponents = OpenAPI.Components(
            schemas: components.schemas,
            securitySchemes: securitySchemes,
            links: links
        )
        let document = OpenAPI.Document(
            info: info.info,
            servers: [],
            paths: paths,
            components: openAPIComponents,
            tags: routes.tags
        )
        return OpenAPIDocument(document: document)
    }

    /// Links from every response value to every request value with the same key.
    ///
    /// Throws when a link targets a parameter its operation doesn't have, so the document never
    /// refers to one that isn't there.
    private static func links(
        from ends: [LinkEnd],
        into paths: inout OpenAPI.PathItem.Map
    ) throws -> OpenAPI.ComponentReferenceDictionary<OpenAPI.Link> {
        // Grouped in the order keys first appear, so the document is the same on every run.
        var groups: OrderedDictionary<LinkKeyID, [LinkEnd]> = [:]
        for end in ends {
            groups[end.key, default: []].append(end)
        }
        var links: OpenAPI.ComponentReferenceDictionary<OpenAPI.Link> = [:]

        for (_, group) in groups {
            let sources = group.filter(\.isSource)
            let targets = group.filter { !$0.isSource }
            for target in targets where !sources.isEmpty {
                try Self.requireParameter(of: target, in: paths)
            }
            for source in sources {
                for target in targets {
                    let link = try OpenAPI.Link(from: source, to: target)
                    let key = try Self.uniqueKey(OpenAPI.Link.name(from: source, to: target), for: link, in: links)
                    links[key] = .b(link)
                    paths.addLink(named: key.rawValue, to: source.path, method: source.method)
                }
            }
        }

        return links
    }

    /// `name` as a component key, with a number added if a different link already has it.
    private static func uniqueKey(
        _ name: String,
        for link: OpenAPI.Link,
        in links: OpenAPI.ComponentReferenceDictionary<OpenAPI.Link>
    ) throws -> OpenAPI.ComponentKey {
        var candidate = name
        var suffix = 2
        while let existing = links[try componentKey(candidate)], existing.b != link {
            candidate = name + "\(suffix)"
            suffix += 1
        }
        return try componentKey(candidate)
    }

    private static func componentKey(_ name: String) throws -> OpenAPI.ComponentKey {
        guard let key = OpenAPI.ComponentKey(rawValue: name) else {
            throw OpenAPIDocumentError(route: name, reason: "isn't a valid name for a link")
        }
        return key
    }

    /// Throws unless `target`'s operation has the parameter the link sets.
    private static func requireParameter(of target: LinkEnd, in paths: OpenAPI.PathItem.Map) throws {
        guard case .request(let location) = target.end.location, location != .body else { return }
        let parameters = paths[target.path]?.pathItemValue?[target.method]?.parameters.compactMap(\.b) ?? []
        guard parameters.contains(where: { $0.name == target.end.name && $0.location.rawValue == location.rawValue })
        else {
            throw OpenAPIDocumentError(
                route: target.route,
                reason: "a link sets its \(location.rawValue) parameter \"\(target.end.name)\", which it doesn't have"
            )
        }
    }
}

#endif
