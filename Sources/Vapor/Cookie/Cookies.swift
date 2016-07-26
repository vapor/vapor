public struct Cookies {
    private var cookies = Set<Cookie>()

    public init() { }

    public init<Cookies: Sequence where Cookies.Iterator.Element == Cookie>(cookies: Cookies) {
        for cookie in cookies {
            self.cookies.insert(cookie)
        }
    }

    public mutating func insert(_ cookie: Cookie) {
        cookies.insert(cookie)
    }

    public mutating func remove(_ cookie: Cookie) {
        cookies.remove(cookie)
    }

    public mutating func removeAll() {
        cookies.removeAll()
    }

    public func contains(_ cookie: Cookie) -> Bool {
        return cookies.contains(cookie)
    }

    public subscript(name: String) -> String? {
        get {
            guard let index = index(ofCookieNamed: name) else {
                return nil
            }

            return cookies[index].value
        }

        set {
            guard let value = newValue else {
                if let index = index(ofCookieNamed: name) {
                    cookies.remove(at: index)
                }

                return
            }

            cookies.insert(Cookie(name: name, value: value))
        }
    }

    private func index(ofCookieNamed name: String) -> SetIndex<Cookie>? {
        return cookies.index(where: { $0.name == name })
    }
}

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

// MARK: Parsing

extension Cookies {
    init(_ cookieString: String) {
        var cookies: Cookies = []

        let tokens = cookieString.utf8.split(separator: .semicolon)

        for token in tokens {
            let cookieTokens = token.split(separator: .equals, maxSplits: 1)

            guard cookieTokens.count == 2 else {
                continue
            }

            let name = cookieTokens[0].string 
            let value = cookieTokens[1].string 

            cookies[name] = value
        }

        self = cookies
    }
}

// MARK: Serialization

extension Cookies {
    func serialize() -> String? {
        guard !self.cookies.isEmpty else { return nil }
        return self
            .map { cookie in
                return "\(cookie.name)=\(cookie.value)"
            }
            .joined(separator: ";")
    }
}
