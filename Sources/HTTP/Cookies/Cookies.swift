/// A `Cookie` Array
///
/// http://localhost:8000/http/cookies/#multiple-cookies
public struct Cookies: ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    /// All `Cookie`s contained
    public var cookies = [Cookie]()
    
    /// Creates an empty `Cookies`
    public init() { }
    
    /// Creates a `Cookies` from an array of cookies
    public init(arrayLiteral elements: Cookie...) {
        self.cookies = elements
    }
    
    /// Creates a `Cookies` from an array of names and cookie values
    public init(dictionaryLiteral elements: (String, Cookie.Value)...) {
        self.cookies = elements.map { name, value in
            return Cookie(named: name, value: value)
        }
    }
    
    /// Creates a `Cookies` from the contents of a `Cookie` Sequence
    public init<C: Sequence>(cookies: C) where C.Iterator.Element == Cookie {
        self.cookies = Array(cookies)
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
            guard let index = cookies.index(where: { $0.name == name }) else {
                if let newValue = newValue {
                    cookies.append(Cookie(named: name, value: newValue))
                }
                
                return
            }
            
            if let newValue = newValue {
                cookies[index].value = newValue
            } else {
                cookies.remove(at: index)
            }
        }
    }
}

extension Cookies: Sequence {
    /// Iterates over all `Cookie`s
    public func makeIterator() -> IndexingIterator<[Cookie]> {
        return cookies.makeIterator()
    }
}
