import Core

public struct Cookies {
    public var cookies: Set<Cookie>

    /**
        Create an empty Cookies.
    */
    public init() {
        cookies = []
    }

    /**
        Initialize a Cookies with
        a sequence of cookies.
    */
    public init<C: Sequence>(cookies: C) where C.Iterator.Element == Cookie {
        self.cookies = []

        for cookie in cookies {
            self.cookies.insert(cookie)
        }
    }

    /**
        Insert a Cookie into the Cookies.
    */
    public mutating func insert(_ cookie: Cookie) {
        cookies.insert(cookie)
    }

    /**
        Remove a Cookie from the Cookies.
    */
    public mutating func remove(_ cookie: Cookie) {
        cookies.remove(cookie)
    }

    /**
        Remove all of the Cookies.
    */
    public mutating func removeAll() {
        cookies.removeAll()
    }

    /**
        Check if the Cookies contains
        a given Cookie.
    */
    public func contains(_ cookie: Cookie) -> Bool {
        return cookies.contains(cookie)
    }

    /**
        Creates a new cookie with the

        - key -> name
        - value -> value
    
        and inserts it into the array of cookies.
        All other values are default.
    */
    public subscript(name: String) -> String? {
        get {
            guard let index = index(of: name) else {
                return nil
            }

            return cookies[index].value
        }

        set {
            guard let value = newValue else {
                if let index = index(of: name) {
                    cookies.remove(at: index)
                }

                return
            }

            cookies.insert(Cookie(name: name, value: value))
        }
    }

    /**
        Get the index of a Cookie with
        the name.
    */
    public func index(of name: String) -> SetIndex<Cookie>? {
        return cookies.index(where: { $0.name == name })
    }
}

