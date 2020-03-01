
//Keeps track if the string was percent encoded or not. Prevents double encoding/double decoding
enum URLQueryFragment: ExpressibleByStringLiteral, Equatable {
    init(stringLiteral: String) {
        self = .urlDecoded(stringLiteral)
    }
    
    case urlEncoded(String)
    case urlDecoded(String)
    
    ///Returns the URL Encoded version
    func asUrlEncoded() throws -> String {
        switch self {
        case .urlEncoded(let encoded):
            return encoded
        case .urlDecoded(let decoded):
            return try decoded.urlEncoded()
        }
    }
    
    ///Returns the URL Decoded version
    func asUrlDecoded() throws -> String {
        switch self {
        case .urlEncoded(let encoded):
            guard let decoded = encoded.removingPercentEncoding else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Unable to remove percent encoding for \(encoded)"))
            }
            return decoded
        case .urlDecoded(let decoded):
            return decoded
        }
    }
    
    ///Do comparison and hashing using the decoded version as there are multiple ways something can be encoded. Certain characters that are not typically encoded could have been encoded making string comparisons between two encodings not work
    static func == (lhs: URLQueryFragment, rhs: URLQueryFragment) -> Bool {
        do {
            return try lhs.asUrlDecoded() == rhs.asUrlDecoded()
        } catch {
            return false
        }
    }
    
    func hash(into: inout Hasher) {
        do {
            try asUrlDecoded().hash(into: &into)
        } catch {
            
        }
    }
}

/// Represents application/x-www-form-urlencoded encoded data.
internal struct URLEncodedFormData: ExpressibleByArrayLiteral, ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral, Equatable {
    
    var values: [URLQueryFragment]
    var children: [String: URLEncodedFormData]
    
    var hasOnlyValues: Bool {
        return children.count == 0
    }
    
    var allChildKeysAreSequentialIntegers: Bool {
        for i in 0...children.count-1 {
            if !children.keys.contains(String(i)) {
                return false
            }
        }
        return true
    }

    init(values: [URLQueryFragment] = [], children: [String: URLEncodedFormData] = [:]) {
        self.values = values
        self.children = children
    }
    
    init(stringLiteral: String) {
        self.values = [.urlDecoded(stringLiteral)]
        self.children = [:]
    }
    
    init(arrayLiteral: String...) {
        self.values = arrayLiteral.map({ (s: String) -> URLQueryFragment in
            return .urlDecoded(s)
        })
        self.children = [:]
    }
    
    init(dictionaryLiteral: (String, URLEncodedFormData)...) {
        self.values = []
        self.children = Dictionary(uniqueKeysWithValues: dictionaryLiteral)
    }
        
    mutating func set(value: URLQueryFragment, forPath path: [String]) {
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
