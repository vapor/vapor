public struct Limit {
    public var count: Int
    public var offset: Int

    public init(count: Int, offset: Int = 0) {
        self.count = count
        self.offset = offset
    }
}

extension QueryBuilder {
    public func limit(_ count: Int, offset: Int = 0) -> Self {
        let limit = Limit(count: count, offset: offset)
        query.limit = limit
        return self
    }
}
