import NIOHTTP1

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
            forwarded += self.parseDirectives(name: .forwarded).compactMap {
                Forwarded(directives: $0)
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
            self.serializeDirectives(newValue.map { $0.directives() }, name: .forwarded)
            self.remove(name: .xForwardedFor)
            self.remove(name: .xForwardedHost)
            self.remove(name: .xForwardedProto)
        }
    }

    /// Parses the `Forwarded` header.
    public struct Forwarded: Sendable {
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

        init?(directives: [Directive]) {
            for directive in directives {
                guard let parameter = directive.parameter else {
                    return nil
                }
                switch directive.value.lowercased() {
                case "by":
                    self.by = .init(parameter)
                case "for":
                    self.for = .init(parameter)
                case "host":
                    self.host = .init(parameter)
                case "proto":
                    self.proto = .init(parameter)
                default:
                    return nil
                }
            }
        }

        func directives() -> [Directive] {
            var directives: [Directive] = []
            if let by = self.by {
                directives.append(.init(value: "by", parameter: by))
            }
            if let `for` = self.for {
                directives.append(.init(value: "for", parameter: `for`))
            }
            if let host = self.host {
                directives.append(.init(value: "host", parameter: host))
            }
            if let proto = self.proto {
                directives.append(.init(value: "proto", parameter: proto))
            }
            return directives
        }
    }
}
