extension HTTPHeaders {
    /// Convenience for accessing the Content-Disposition header.
    ///
    /// See https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Disposition
    public var contentDisposition: ContentDisposition? {
        get {
            self.first(name: .contentDisposition).flatMap {
                .parse($0)
            }
        }
        set {
            if let header = newValue {
                self.replaceOrAdd(name: .contentDisposition, value: header.serialize())
            } else {
                self.remove(name: .contentDisposition)
            }
        }
    }

    public struct ContentDisposition {
        public struct Value: Equatable {
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

        static func parse<S>(_ data: S) -> Self?
            where S: StringProtocol
        {
            var parser = ValueParser(string: data)
            guard let directives = parser.nextValue() else {
                return nil
            }
            guard let first = directives.first else {
                return nil
            }
            guard first.parameter == nil else {
                return nil
            }
            var header = ContentDisposition(.init(string: .init(first.value)))
            for directive in directives[1...] {
                guard let parameter = directive.parameter else {
                    return nil
                }
                switch directive.value.lowercased() {
                case "name":
                    header.name = .init(parameter)
                case "filename":
                    header.filename = .init(parameter)
                default:
                    return nil
                }
            }
            return header
        }

        func serialize() -> String {
            var parameters: [(String, String)] = []
            if let name = self.name {
                parameters.append(("name", name))
            }
            if let filename = self.filename {
                parameters.append(("filename", filename))
            }
            let serializer = ValueSerializer(
                value: self.value.string,
                parameters: parameters
            )
            return serializer.serialize()
        }
    }
}
