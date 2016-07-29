extension RouteGroup: RouteBuilder {
    public typealias Value = Wrapped

    public func add(path: [String], value: Value) {
        var prefix: [String] = []
        for (i, p) in self.prefix.enumerated() {
            if let p = p {
                prefix.append(p)
            } else {
                prefix.append(path[i])
            }
        }
        let path = prefix + self.path + Array(path.dropFirst(prefix.count))

        var value = value
        if let filter = filter {
            value = filter(value)
        }
        builder.add(path: path, value: value)
    }
}
