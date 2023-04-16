/// Parses a URL Query `single=value&arr=1&arr=2&obj[key]=objValue` into
internal struct URLEncodedFormParser: Sendable {
    init() { }
    
    func parse(_ query: String) throws -> URLEncodedFormData {
        let plusDecodedQuery = query.replacingOccurrences(of: "+", with: "%20")
        var result: URLEncodedFormData = []
        for pair in plusDecodedQuery.split(separator: "&") {
            let kv = pair.split(
                separator: "=",
                maxSplits: 1, // max 1, `foo=a=b` should be `"foo": "a=b"`
                omittingEmptySubsequences: false
            )
            switch kv.count {
            case 1:
                let value = String(kv[0])
                try result.set(value: .urlEncoded(value), forPath: [], recursionDepth: 0)
            case 2:
                let key = kv[0]
                let value = String(kv[1])
                try result.set(value: .urlEncoded(value), forPath: try parseKey(key: Substring(key)), recursionDepth: 0)
            default:
                //Empty `&&`
                continue
            }
        }
        return result
    }

    func parseKey(key: Substring) throws -> [String] {
        guard let percentDecodedKey = key.removingPercentEncoding else {
            throw URLEncodedFormError.malformedKey(key: key)
        }
        return try percentDecodedKey.split(separator: "[").enumerated().map { (i, part) in 
            switch i {
            case 0:
                return String(part)
            default:
                guard part.last == "]" else {
                    throw URLEncodedFormError.malformedKey(key: key)
                }
                return String(part.dropLast())
            }
        }
    }
}
