struct Body {
    var signature: Signature

    init(signature: Signature) {
        self.signature = signature
    }
}

extension Body: CustomStringConvertible {
    var description: String {
        return [
            "self.add(.\(signature.method), path: \"\(path)\") { request in ",
            innerBody.indented,
            "}"
        ].joined(separator: "\n")
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

    var innerBody: String {
        return [
            badRequestGuards,
            stringInitializeTrys,
            invalidParameterGuards,
            returns
        ].joined(separator: "\n")
    }

    var badRequestGuards: String {
        return signature.wildcards.map { wildcard in
            return [
                "guard let v\(wildcard.name) = request.parameters[\"\(wildcard.name)\"] else {",
                "    throw Abort.badRequest",
                "}"
            ].joined(separator: "\n")
        }.joined(separator: "\n")
    }

    var stringInitializeTrys: String {
        return signature.wildcards.map { wildcard in
            return "let e\(wildcard.name) = try \(wildcard.generic)(from: v\(wildcard.name))\n"
        }.joined(separator: "\n")
    }

    var invalidParameterGuards: String {
        return signature.wildcards.map { wildcard in
            return [
                "guard let c\(wildcard.name) = e\(wildcard.name) else {",
                "    throw Abort.invalidParameter(\"\(wildcard.name)\", \(wildcard.generic).self)",
                "}"
            ].joined(separator: "\n")
        }.joined(separator: "\n")
    }

    var returns: String {
        let additions: String
        if signature.wildcards.count > 0 {
            additions = "," + signature.wildcards.map { wildcard in
                return "c\(wildcard.name)"
            }.joined(separator: ", ")
        } else {
            additions = ""
        }

        switch signature.variant {
        case .socket:
            return "return try request.upgradeToWebSocket { try handler(request, $0\(additions)) }"
        case .base:
            return "return try handler(request\(additions))"
        }
    }
}
