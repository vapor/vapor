import NIOHTTP1

extension HTTPHeaders {
    /// Convenience for accessing the Content-Disposition header.
    ///
    /// See https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Disposition
    public var contentDisposition: ContentDisposition? {
        get {
            self.parseDirectives(name: .contentDisposition).first.flatMap {
                ContentDisposition(directives: $0)
            }
        }
        set {
            if let header = newValue {
                self.serializeDirectives([header.directives()], name: .contentDisposition)
            } else {
                self.remove(name: .contentDisposition)
            }
        }
    }

    public struct ContentDisposition: Sendable {
        public struct Value: Equatable, Sendable {
            public static let inline = Value(string: "inline")
            public static let attachment = Value(string: "attachment")
            public static let formData = Value(string: "form-data")

            let string: String
        }

        public var value: Value
        public var name: String?
        public var filename: String?

        public init(_ value: Value, name: String? = nil, filename: String? = nil) {
            self.value = value
            self.name = name
            self.filename = filename
        }

        init?(directives: [Directive]) {
            guard let first = directives.first else {
                return nil
            }
            guard first.parameter == nil else {
                return nil
            }
            self.value = .init(string: .init(first.value))
            for directive in directives[1...] {
                guard let parameter = directive.parameter else {
                    return nil
                }
                switch directive.value.lowercased() {
                case "name":
                    self.name = .init(parameter)
                case "filename":
                    self.filename = .init(parameter)
                case "filename*":
                    self.filename = .init(parameter)
                default:
                    return nil
                }
            }
        }

        func directives() -> [Directive] {
            var directives: [Directive] = [
                .init(value: self.value.string)
            ]
            if let name = self.name {
                directives.append(.init(value: "name", parameter: name))
            }
            if let filename = self.filename {
                directives.append(.init(value: "filename", parameter: filename))
            }
            return directives
        }
    }
}
