/**
 Parses a URL Query `single=value&arr=1&arr=2&obj[key]=objValue` into
 */
internal struct URLEncodedFormParser {
    let splitVariablesOn: Character
    let splitKeyValueOn: Character
    
    /// Create a new form-urlencoded data parser.
    init(splitVariablesOn: Character = "&", splitKeyValueOn: Character = "=") {
        self.splitVariablesOn = splitVariablesOn
        self.splitKeyValueOn = splitKeyValueOn
    }
    
    func parse(_ query: String) throws -> URLEncodedFormData {
        let plusDecodedQuery = query.replacingOccurrences(of: "+", with: "%20")
        var result: URLEncodedFormData = []
        for pair in plusDecodedQuery.split(separator: splitVariablesOn) {
            let kv = pair.split(
                separator: splitKeyValueOn,
                maxSplits: 1, // max 1, `foo=a=b` should be `"foo": "a=b"`
                omittingEmptySubsequences: false
            )
            switch kv.count {
            case 1:
                let value = String(kv[0])
                result.set(value: .urlEncoded(value), forPath: [])
            case 2:
                let key = kv[0]
                let value = String(kv[1])
                result.set(value: .urlEncoded(value), forPath: try parseKey(key: Substring(key)))
            default:
                //Empty `&&`
                continue
            }
        }
        return result
    }
    
    func parseKey(key: Substring) throws -> [String] {
        var path = [String]()
        for var element in key.split(separator: "[") {
            if path.count > 0 { //First one is not wrapped with `[]`
                guard element.last == "]" else {
                    throw URLEncodedFormError(identifier: "malformedKey", reason: "Malformed form-urlencoded key encountered. Sub-indexes in keys must end with ']'. For example `obj[key]`")
                }
                element = element.prefix(element.count-1) //Remove the `]`
            }
            guard let percentDecodedElement = element.removingPercentEncoding else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Unable to remove percent encoding for \(element)"))
            }
            path.append(percentDecodedElement)
        }
        return path
    }
}

