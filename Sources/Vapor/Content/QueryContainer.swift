import Foundation

/// Helper for decoding HTTP URI query
public struct QueryContainer {
    internal var query: String
    internal var container: SubContainer
}

extension QueryContainer {
    /// Parses the supplied content from the mesage.
    public func decode<D: Decodable>(_ decodable: D.Type) throws -> D {
        return try requireDecoder().decode(D.self, from: query)
    }

    /// Gets the query decoder or throws an error
    fileprivate func requireDecoder() throws -> FormURLDecoder {
        return try container.make()
    }
}

// MARK: Single value

extension QueryContainer {
    /// Convenience for accessing a single value from the content
    public subscript<D>(_ keyPath: BasicKeyRepresentable...) -> D?
        where D: Decodable
    {
        return self[D.self, at: keyPath]
    }

    /// Convenience for accessing a single value from the content
    public subscript<D>(_ type: D.Type, at keyPath: BasicKeyRepresentable...) -> D?
        where D: Decodable
    {
        return self[D.self, at: keyPath]
    }

    /// Convenience for accessing a single value from the content
    public subscript<D>(_ type: D.Type, at keyPath: [BasicKeyRepresentable]) -> D?
        where D: Decodable
    {
        return try? get(at: keyPath)
    }

    /// Convenience for accessing a single value from the content
    public func get<D>(_ type: D.Type = D.self, at keyPath: BasicKeyRepresentable...) throws -> D
        where D: Decodable
    {
        return try get(at: keyPath)
    }

    /// Convenience for accessing a single value from the content
    public func get<D>(_ type: D.Type = D.self, at keyPath: [BasicKeyRepresentable]) throws -> D
        where D: Decodable
    {
        return try requireDecoder().get(at: keyPath.makeBasicKeys(), from: Data(query.utf8))
    }
}
