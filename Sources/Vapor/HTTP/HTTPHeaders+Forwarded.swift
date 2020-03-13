extension HTTPHeaders {
    /// Convenience for accessing the Forwarded header. This header is added by
    /// proxies to pass information about the original request.
    ///
    /// Parsing is supported for deprecated headers like Via and X-Forwarded-For.
    /// Values are always serialized to the recommended Forwarded header.
    ///
    /// See https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Forwarded
    /// See https://en.wikipedia.org/wiki/X-Forwarded-For
    public var forwarded: [Forwarded] {
        get {
            var forwarded: [Forwarded] = []

            // Add values from Forwarded header.
            forwarded += self[canonicalForm: .forwarded].compactMap {
                .parse($0)
            }

            // Add values from deprecated headers.
            let bys = self[canonicalForm: .via]
            let fors = self[canonicalForm: .xForwardedFor]
            let hosts = self[canonicalForm: .xForwardedHost]
            let protos = self[canonicalForm: .xForwardedProto]
            for i in 0..<[bys.count, fors.count, hosts.count, protos.count].max()! {
                forwarded.append(.init(
                    by: bys[safe: i].flatMap(String.init),
                    for: fors[safe: i].flatMap(String.init),
                    host: hosts[safe: i].flatMap(String.init),
                    proto: protos[safe: i].flatMap(String.init)
                ))
            }

            return forwarded
        }
        set {
            let value = newValue.map {
                $0.serialize()
            }.joined(separator: ", ")
            self.replaceOrAdd(name: "Forwarded", value: value)
            self.remove(name: "X-Forwarded-For")
            self.remove(name: "X-Forwarded-Host")
            self.remove(name: "X-Forwarded-Proto")
        }
    }

    /// Parses the `Forwarded` header.
    public struct Forwarded {
        /// "by" section of the header.
        public var by: String?

        /// "for" section of the header
        public var `for`: String?

        /// "host" section of the header
        public var host: String?

        /// "proto" section of the header.
        public var proto: String?

        public init(by: String? = nil, for: String? = nil, host: String? = nil, proto: String? = nil) {
            self.by = by
            self.for = `for`
            self.host = host
            self.proto = proto
        }

        static func parse<S>(_ data: S) -> Self?
            where S: StringProtocol
        {
            #warning("TODO: fixme")
            fatalError()
//            var parser = ValueParser(string: data)
//            var forwarded = Forwarded()
//            while let (key, value) = parser.nextParameter() {
//                let value = String(value)
//                switch key.lowercased() {
//                case "by":
//                    forwarded.by = value
//                case "for":
//                    forwarded.for = value
//                case "host":
//                    forwarded.host = value
//                case "proto":
//                    forwarded.proto = value
//                default:
//                    return nil
//                }
//            }
//            return forwarded
        }

        func serialize() -> String {
            var parameters: [(String, String)] = []
            if let by = self.by {
                parameters.append(("by", by))
            }
            if let `for` = self.for {
                parameters.append(("for", `for`))
            }
            if let host = self.host {
                parameters.append(("host", host))
            }
            if let proto = self.proto {
                parameters.append(("proto", proto))
            }
            let serializer = ValueSerializer(
                value: nil,
                parameters: parameters
            )
            return serializer.serialize()
        }
    }
}
