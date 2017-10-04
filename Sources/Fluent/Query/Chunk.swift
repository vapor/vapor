extension QueryRepresentable  where Self: ExecutorRepresentable {
    public func chunk(_ size: Int, _ closure: ([E]) throws -> ()) throws {
        let query = try makeQuery()
        let count = try query.count()
        for i in 0..<(count/size) + 1 {
            try query.limit(size, offset: i * size)
            let results = try query.all()
            try closure(results)
        }
    }
}
