/// Represents application/x-www-form-urlencoded encoded data.
internal struct URLEncodedFormData: ExpressibleByArrayLiteral, ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral, Equatable {
    
    var values: [String]
    // If you have an array
    var children: [String: URLEncodedFormData]
    
    var hasOnlyValues: Bool {
        return children.count == 0
    }

    init(values: [String] = [], children: [String: URLEncodedFormData] = [:]) {
        self.values = values
        self.children = children
    }
    
    init(stringLiteral: String) {
        self.values = [stringLiteral]
        self.children = [:]
    }
    
    init(arrayLiteral: String...) {
        self.values = arrayLiteral
        self.children = [:]
    }
    
    init(dictionaryLiteral: (String, URLEncodedFormData)...) {
        self.values = []
        self.children = Dictionary(uniqueKeysWithValues: dictionaryLiteral)
    }
        
    mutating func set(value: String, forPath path: [String]) {
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
