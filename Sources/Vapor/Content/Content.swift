@_exported import PathIndexable

public protocol RequestContentSubscript {}

extension String: RequestContentSubscript { }
extension Int: RequestContentSubscript {}

/**
    The data received from the request in json body or url query
 
    Can be extended by third party droplets and middleware
*/
public final class Content {

    public typealias ContentLoader = ([PathIndex]) -> Polymorphic?

    // MARK: Initialization

    private var content: [ContentLoader] = []

    public init() {}

    // Some closure weirdness to allow more complex capturing or lazy loading internally

    public func append<E where E: PathIndexable, E: Polymorphic>(_ element: (Void) -> E?) {
        let finder: ContentLoader = { indexes in return element()?[indexes] }
        content.append(finder)
    }

    public func append(_ element: ContentLoader) {
        content.append(element)
    }

    public func append<E where E: PathIndexable, E: Polymorphic>(_ element: E?) {
        guard let element = element else { return }
        let finder: ContentLoader = { indexes in return element[indexes] }
        content.append(finder)
    }

    // MARK: Subscripting

    public subscript(index: Int) -> Polymorphic? {
        return self[[index]] ?? self [["\(index)"]]
    }

    public subscript(key: String) -> Polymorphic? {
        return self[[key]]
    }

    public subscript(indexes: PathIndex...) -> Polymorphic? {
        return self[indexes]
    }

    public subscript(indexes: [PathIndex]) -> Polymorphic? {
        return content.lazy.flatMap { finder in finder(indexes) } .first
    }
}
