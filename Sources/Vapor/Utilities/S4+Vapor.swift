import S4

extension S4.Headers {
    var vaporHeaders: [(String, String)] {
        var vaporHeaders: [(String, String)] = []
        
        headers.forEach { (key, values) in
            for value in values {
                vaporHeaders.append((key.string, value))
            }
        }
        
        return vaporHeaders
    }
}

extension S4.Body {
    var data: Data {
        switch self {
        case .buffer(let data):
            return data
        case .stream(let stream):
            let data = S4.Drain(stream).data
            return data
        }
    }
}

extension URI {
    var vaporPath: String {
        return path ?? ""
    }
}


