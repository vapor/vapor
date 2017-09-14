public struct Cookies: ExpressibleByArrayLiteral {
    public var cookies = [Cookie]()
    
    /// Creates an empty `Cookies`
    public init() { }
    
    public init(arrayLiteral elements: Cookie...) {
        self.cookies = elements
    }
    
    /// Creates a `Cookies` from the contents of a `Cookie` Sequence
    public init<C: Sequence>(cookies: C) where C.Iterator.Element == Cookie {
        self.cookies = Array(cookies)
    }
    
    /// Appends a `Cookie` to the `Cookies`
    public mutating func append(_ cookie: Cookie) {
        cookies.append(cookie)
    }
    
    /// Access a `Cookie` by name
    public subscript(name: String) -> Cookie.Value? {
        get {
            guard let index = cookies.index(where: { $0.name == name }) else {
                return nil
            }
            
            return cookies[index].value
        }
        set {
            guard let value = newValue else {
                if let index = cookies.index(where: { $0.name == name }) {
                    cookies.remove(at: index)
                }
                
                return
            }
            
            cookies.append(Cookie(named: name, value: value))
        }
    }
}

extension Cookies: Sequence {
    public func makeIterator() -> IndexingIterator<[Cookie]> {
        return cookies.makeIterator()
    }
}
