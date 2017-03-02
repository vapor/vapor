@_exported import PathIndexable

public protocol RequestContentSubscript {}

extension String: RequestContentSubscript { }
extension Int: RequestContentSubscript {}

/**
    The data received from the request in json body or url query
 
    Can be extended by third party droplets and middleware
*/
public final class Content {

    public typealias ContentLoader = ([PathIndexer]) -> Polymorphic?

    // MARK: Initialization

    private var content: [ContentLoader] = []

    public init() {}

    // Some closure weirdness to allow more complex capturing or lazy loading internally

    public func append<E>(_ element: @escaping (Void) -> E?) where E: PathIndexable, E: Polymorphic {
        let finder: ContentLoader = { indexes in return element()?[indexes] }
        content.append(finder)
    }

    public func append(_ element: @escaping ContentLoader) {
        content.append(element)
    }

    public func append<E>(_ element: E?) where E: PathIndexable, E: Polymorphic {
        guard let element = element else { return }
        let finder: ContentLoader = { indexes in return element[indexes] }
        content.append(finder)
    }

    // MARK: Subscripting

    public subscript(indexes: PathIndexer...) -> Polymorphic? {
        return self[indexes]
    }

    public subscript(indexes: [PathIndexer]) -> Polymorphic? {
        return content.lazy.flatMap { loader in loader(indexes) } .first
    }
}
