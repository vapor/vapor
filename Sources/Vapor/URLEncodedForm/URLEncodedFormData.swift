/// Represents application/x-www-form-urlencoded encoded data.
internal struct URLEncodedFormData: Equatable {
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
    
    init(_ value: String) {
        self.values = [value]
        self.children = [:]
    }
    
    init(_ values: [String]) {
        self.values = values
        self.children = [:]
    }
    
    init(_ children: [String: URLEncodedFormData]) {
        self.values = []
        self.children = children
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
            child = URLEncodedFormData()
        }
        child.set(value: value, forPath: Array(path[1...]))
        children[firstElement] = child
    }
}
