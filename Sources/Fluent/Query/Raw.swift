public enum RawOr<Wrapped> {
    case raw(String, [Node])
    case some(Wrapped)
}

extension RawOr {
    public var wrapped: Wrapped? {
        switch self {
        case .some(let wrapped):
            return wrapped
        case .raw:
            return nil
        }
    }
}

extension RawOr: Hashable {
    public var hashValue: Int {
        switch self {
        case .raw(let string, _):
            return string.hashValue
        case .some(let wrapped):
            return "\(wrapped)".hashValue
        }
    }
    
    public static func ==(lhs: RawOr, rhs: RawOr) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

extension Node {
    internal var rawOrObject: [RawOr<String>: RawOr<Node>]? {
        guard let object = self.object else {
            return nil
        }
        
        var rawOrObject: [RawOr<String>: RawOr<Node>] = [:]
        
        for (key, value) in object {
            let rawOrKey = RawOr<String>.some(key)
            let rawOrValue = RawOr<Node>.some(value)
            rawOrObject[rawOrKey] = rawOrValue
        }
        
        return rawOrObject
    }
}

// MARK: Filter

extension QueryRepresentable where Self: ExecutorRepresentable {
    @discardableResult
    public func filter(
        raw string: String,
        _ values: [Node] = []
    ) throws -> Query<E> {
        let query = try makeQuery()
        query.filters.append(.raw(string, values))
        return query
    }

    @discardableResult
    public func filter(
        raw string: String,
        _ values: [NodeRepresentable]
    ) throws -> Query<E> {
        let query = try makeQuery()
        let values = try values.map { try $0.makeNode(in: query.context) }
        query.filters.append(.raw(string, values))
        return query
    }
}

extension Array where Element == RawOr<Filter> {
    public mutating func append(_ filter: Filter) {
        append(.some(filter))
    }
}

// MARK: Join

extension QueryRepresentable where Self: ExecutorRepresentable {
    @discardableResult
    public func join(
        raw string: String
    ) throws -> Query<E> {
        let query = try makeQuery()
        query.joins.append(.raw(string, []))
        return query
    }
}

extension Array where Element == RawOr<Join> {
    public mutating func append(_ join: Join) {
        append(.some(join))
    }
}

extension RawOr: CustomStringConvertible {
    public var description: String {
        switch self {
        case .raw(let string, let values):
            return "[raw] \(string) \(values)"
        case .some(let wrapped):
            return "\(wrapped)"
        }
    }
}

// MARK: Key

extension QueryRepresentable where Self: ExecutorRepresentable {
    @discardableResult
    public func set(raw rawKey: String, equals rawValue: String) throws -> Query<E> {
        let query = try makeQuery()
        query.data[.raw(rawKey, [])] = .raw(rawValue, [])
        return query
    }
}

// MARK: Sort

extension QueryRepresentable where Self: ExecutorRepresentable {
    @discardableResult
    public func sort(raw: String) throws -> Query<E> {
        let query = try makeQuery()
        query.sorts.append(.raw(raw, []))
        return query
    }
}

// MARK: Limit

extension QueryRepresentable where Self: ExecutorRepresentable {
    @discardableResult
    public func limit(raw: String) throws -> Query<E> {
        let query = try makeQuery()
        query.limits.append(.raw(raw, []))
        return query
    }
}

public final class Raw: Entity {
    public let storage = Storage()
    public init(row: Row) throws {}
    public func makeRow() throws -> Row { return Row() }
}
