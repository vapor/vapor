@_exported import PathIndexable

public protocol RequestContentSubscript {}

extension String: RequestContentSubscript { }
extension Int: RequestContentSubscript {}

/**
    The data received from the request in json body or url query
 
    Can be extended by third party droplets and middleware
*/
public final class Content {

    public typealias ContentLoader = ([PathIndexer]) -> Node?

    // MARK: Initialization

    private var content: [ContentLoader] = []

    public init() {}

    // Some closure weirdness to allow more complex capturing or lazy loading internally

    public func append<W: StructuredDataWrapper>(_ element: @escaping (Void) -> W?) {
        let finder: ContentLoader = { indexes in
            guard let w = element()?[indexes] else { return nil }
            return Node(w)
        }
        content.append(finder)
    }

    public func append(_ element: @escaping ContentLoader) {
        content.append(element)
    }

    public func append<W: StructuredDataWrapper>(_ element: W?) {
        guard let element = element else { return }
        let finder: ContentLoader = { indexes in
            guard let w = element[indexes] else { return nil }
            return Node(w)
        }
        content.append(finder)
    }

    // MARK: Subscripting

    public subscript(indexes: PathIndexer...) -> Node? {
        return self[indexes]
    }

    public subscript(indexes: [PathIndexer]) -> Node? {
        return content.lazy.flatMap { loader in loader(indexes) } .first
    }
}

extension Content {
    public func get<T : NodeInitializable>(
        _ indexers: PathIndexer...)
        throws -> T {
            return try get(indexers)
    }

    public func get<T : NodeInitializable>(
        _ indexers: [PathIndexer])
        throws -> T {
            let value = self[indexers] ?? .null
            return try T(node: value)
    }
}
