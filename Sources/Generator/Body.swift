struct Body {
    var signature: Signature

    init(signature: Signature) {
        self.signature = signature
    }
}

extension Body: CustomStringConvertible {
    var description: String {
        var b = ""
        b << "self.add(.\(signature.method), path: \"\(path)\") { request in "
        b <<< "}"
        return b
    }

    var path: String {
        return signature.parameters.map { parameter in
            switch parameter {
            case .path(let path):
                return "\\(\(path.name))"
            case .wildcard(let wildcard):
                return ":\(wildcard.name)"
            }
        }.joined(separator: "/")
    }
}
