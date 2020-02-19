/**
 Parses a URL Query `single=value&arr=1&arr=2&obj[key]=objValue` into
 */
internal struct URLEncodedFormParser2 {
    let splitVariablesOn: Character
    let splitKeyValueOn: Character
    
    /// Create a new form-urlencoded data parser.
    init(splitVariablesOn: Character = "&", splitKeyValueOn: Character = "=") {
        self.splitVariablesOn = splitVariablesOn
        self.splitKeyValueOn = splitKeyValueOn
    }
    
    func parse(_ query: String) throws -> URLEncodedFormData2 {
        let plusDecodedQuery = query.replacingOccurrences(of: "+", with: " ")
        var result = URLEncodedFormData2()
        for pair in plusDecodedQuery.split(separator: splitVariablesOn) {
            let kv = pair.split(
                separator: splitKeyValueOn,
                maxSplits: 1, // max 1, `foo=a=b` should be `"foo": "a=b"`
                omittingEmptySubsequences: false
            )
            switch kv.count {
            case 1:
                let value = kv[0].removingPercentEncoding!
                result.set(value: value, forPath: [])
            case 2:
                let key = kv[0]
                let value = kv[1].removingPercentEncoding!
                result.set(value: value, forPath: try parseKey(key: key))
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
            path.append(element.removingPercentEncoding!)
        }
        return path
    }
}

internal struct URLEncodedFormData2: Equatable {
    var values: [String]
    // If you have an array
    var children: [String: URLEncodedFormData2]
    
    init(values: [String] = [], children: [String: URLEncodedFormData2] = [:]) {
        self.values = values
        self.children = children
    }
    
    init(_ value: String) {
        self.values = [value]
        self.children = [:]
    }

    init(_ values: [String]) {
        self.values = values
        self.children = [:]
    }

    init(_ children: [String: URLEncodedFormData2]) {
        self.values = []
        self.children = children
    }
    
    mutating func set(value: String, forPath path: [String]) {
        guard let firstElement = path.first else {
            values.append(value)
            return
        }
        var child: URLEncodedFormData2
        if let existingChild = children[firstElement] {
            child = existingChild
        } else {
            child = URLEncodedFormData2()
        }
        child.set(value: value, forPath: Array(path[1...]))
        children[firstElement] = child
    }
}
