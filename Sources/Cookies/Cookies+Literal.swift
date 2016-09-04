extension Cookies: ExpressibleByArrayLiteral {
    public init(arrayLiteral cookies: Cookie...) {
        self.init(cookies: cookies)
    }
}

extension Cookies: Sequence {
    public typealias Iterator = SetIterator<Cookie>

    public func makeIterator() -> Iterator {
        return cookies.makeIterator()
    }
}
