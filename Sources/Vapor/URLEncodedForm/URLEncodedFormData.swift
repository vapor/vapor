
//Keeps track if the string was percent encoded or not. Prevents double encoding/double decoding
enum URLEncodedFormPercentEncodedFragment: ExpressibleByStringLiteral, Equatable {
    init(stringLiteral: String) {
        self = .decoded(stringLiteral)
    }
    
    case encoded(String)
    case decoded(String)
    
    func encoded() throws -> String {
        switch self {
        case .encoded(let encoded):
            return encoded
        case .decoded(let decoded):
            return try decoded.urlEncoded()
        }
    }
    
    func decoded() throws -> String {
        switch self {
        case .encoded(let encoded):
            guard let decoded = encoded.removingPercentEncoding else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Unable to remove percent encoding for \(encoded)"))
            }
            return decoded
        case .decoded(let decoded):
            return decoded
        }
    }
    
    //Do comparison and hashing using the decoded version as there are multiple ways something can be encoded. Certain characters that are not typically encoded could have been encoded making string comparisons between two encodings not work
    static func == (lhs: URLEncodedFormPercentEncodedFragment, rhs: URLEncodedFormPercentEncodedFragment) -> Bool {
        do {
            return try lhs.decoded() == rhs.decoded()
        } catch {
            return false
        }
    }
    
    func hash(into: inout Hasher) {
        do {
            try decoded().hash(into: &into)
        } catch {
            
        }
    }
    
    var hashValue: Int {
        do {
            return try decoded().hashValue
        } catch {
            return 0
        }
    }
    
}

/// Represents application/x-www-form-urlencoded encoded data.
internal struct URLEncodedFormData: ExpressibleByArrayLiteral, ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral, Equatable {
    
    var values: [URLEncodedFormPercentEncodedFragment]
    var children: [String: URLEncodedFormData]
    
    var hasOnlyValues: Bool {
        return children.count == 0
    }
    
    var allChildKeysAreNumbers: Bool {
        for i in 0...children.count-1 {
            if !children.keys.contains(String(i)) {
                return false
            }
        }
        return true
    }

    init(values: [URLEncodedFormPercentEncodedFragment] = [], children: [String: URLEncodedFormData] = [:]) {
        self.values = values
        self.children = children
    }
    
    init(stringLiteral: String) {
        self.values = [.decoded(stringLiteral)]
        self.children = [:]
    }
    
    init(arrayLiteral: String...) {
        self.values = arrayLiteral.map({ (s: String) -> URLEncodedFormPercentEncodedFragment in
            return .decoded(s)
        })
        self.children = [:]
    }
    
    init(dictionaryLiteral: (String, URLEncodedFormData)...) {
        self.values = []
        self.children = Dictionary(uniqueKeysWithValues: dictionaryLiteral)
    }
        
    mutating func set(value: URLEncodedFormPercentEncodedFragment, forPath path: [String]) {
        guard let firstElement = path.first else {
            values.append(value)
            return
        }
        var child: URLEncodedFormData
        if let existingChild = children[firstElement] {
            child = existingChild
        } else {
            child = []
        }
        child.set(value: value, forPath: Array(path[1...]))
        children[firstElement] = child
    }
}
