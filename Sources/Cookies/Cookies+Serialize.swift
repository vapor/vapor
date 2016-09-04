import Core

extension Cookies {
    public enum SerializationMethod {
        case request, response
    }

    public func serialize(for method: SerializationMethod) -> String {
        guard !cookies.isEmpty else {
            return ""
        }

        switch method {
        case .request:
            return map { cookie in
                return "\(cookie.name)=\(cookie.value)"
            }.joined(separator: "; ")
        case .response:
            return map { cookie in
                return cookie.makeBytes().string
            }.joined(separator: "\r\nSet-Cookie: ")
        }
    }
}

