extension HTTPHeaders {
    @available(*, deprecated, renamed: "first")
    public func firstValue(name: Name) -> String? {
        // fixme: optimize
        return self[name.lowercased].first
    }
}
