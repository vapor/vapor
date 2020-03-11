extension HTTPHeaders {
    /// Represents the information we have about the remote peer of this message.
    ///
    /// The peer (remote/client) address is important for availability (block bad clients by their IP) or even security.
    /// We can always get the remote IP of the connection from the `Channel`. However, when clients go through
    /// a proxy or a load balancer, we'd like to get the original client's IP. Most proxy servers and load
    /// balancers communicate the information about the original client in certain headers.
    ///
    /// See https://en.wikipedia.org/wiki/X-Forwarded-For
    public var forwarded: Forwarded? {
        get {
            if let value = self.firstValue(name: .forwarded) {
                return .parse(value)
            } else {
                var forwarded = Forwarded()
                forwarded.by = self.values("Via") ?? []
                forwarded.for = self.values("X-Forwarded-For") ?? []
                forwarded.host = self.values("X-Forwarded-Host") ?? []
                forwarded.proto = self.values("X-Forwarded-Proto") ?? []
                // Only return value if we have at least one header.
                if !forwarded.by.isEmpty || !forwarded.for.isEmpty || !forwarded.host.isEmpty || !forwarded.proto.isEmpty {
                    return forwarded
                } else {
                    return nil
                }
            }
        }
        set {
            if let forwarded = newValue {
                var value = HTTPHeaderValue("")
//                value.parameters["by"] = forwarded.by
//                value.parameters["for"] = forwarded.for
//                value.parameters["host"] = forwarded.host
//                value.parameters["proto"] = forwarded.proto
                self.replaceOrAdd(name: .forwarded, value: value.serialize())
            } else {
                self.remove(name: .forwarded)
            }
        }
    }

    /// Parses the `Forwarded` header.
    public struct Forwarded {
        /// "by" section of the header.
        public var by: [String]

        /// "for" section of the header
        public var `for`: [String]

        /// "for" section of the header
        public var host: [String]

        /// "proto" section of the header.
        public var proto: [String]

        public init(by: [String] = [], for: [String] = [], host: [String] = [], proto: [String] = []) {
            self.by = by
            self.for = `for`
            self.host = host
            self.proto = proto
        }

        /// Creates a new `Forwaded` header object from the header value.
        static func parse(_ data: String) -> Forwarded? {
            var parser = HTTPHeaderValueParser(string: data)

            var forwarded = Forwarded()

            while let (key, value) = parser.nextParameter() {
                switch key.lowercased() {
                case "by":
                    forwarded.by.append(value)
                case "for":
                    forwarded.for.append(value)
                case "host":
                    forwarded.host.append(value)
                case "proto":
                    forwarded.proto.append(value)
                default:
                    return nil
                }
            }

            return forwarded
        }
    }
}

private extension HTTPHeaders {
    func values(_ name: String) -> [String]? {
        guard let value = self.firstValue(name: .init(name)) else {
            return nil
        }
        var parser = HTTPHeaderValueParser(string: value)
        var values: [String] = []
        while let value = parser.nextValue() {
            values.append(value)
        }
        return values
    }
}
