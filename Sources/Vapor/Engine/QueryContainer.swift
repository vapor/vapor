import Foundation

/// Helper for decoding HTTP URI query
public struct QueryContainer {
    var query: String
    let container: SubContainer
}

extension QueryContainer {
    /// Parses the supplied content from the mesage.
    public func decode<D: Decodable>(_ decodable: D.Type) throws -> D {
        return try requireDecoder().decode(D.self, from: HTTPBody(string: query)).assertCompleted()
    }

    /// Gets the query decoder or throws an error
    fileprivate func requireDecoder() throws -> BodyDecoder {
        let coders = try container.superContainer.make(ContentCoders.self, for: QueryContainer.self)
        return try coders.requireDecoder(for: .urlEncodedForm)
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
        return try requireDecoder().get(at: keyPath.makeBasicKeys(), from: HTTPBody(string: query)).assertCompleted()
    }
}
