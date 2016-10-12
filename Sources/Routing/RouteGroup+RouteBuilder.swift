extension RouteGroup: RouteBuilder {
    /**
        The Value type allowed in RouteBuilder
        extensions should be the same as the RouteGroup's
        wrapped type.
    */
    public typealias Value = Wrapped

    /**
        Adds a Value to the RouteGroup by combining
        the prefix, path, and incoming path.
    */
    public func add(path incomingPath: [String], value: Value) {
        // will hold the beginning of the path
        var start: [String] = []

        // iterate through the RouteGroup's prefix
        // any nil values encountered should be pulled
        // from the incoming path
        for (i, p) in self.prefix.enumerated() {
            start.append(p ?? incomingPath[i])
        }

        // create the resulting path by combining the
        // start, hard coded path, and incoming path with the start removed
        let result = start + path + Array(incomingPath.dropFirst(prefix.count))

        // if there is a filter, then map the value
        var value = value
        if let map = map {
            value = map(value)
        }

        builder.add(path: result, value: value)
    }
}
