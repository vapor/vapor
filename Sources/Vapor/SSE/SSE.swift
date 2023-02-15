enum SSEError: Error {
    case notAString, protocolViolation
}

public struct SSEValue: ExpressibleByStringLiteral {
    fileprivate var parts = [Substring]()
    
    public var string: String {
        get {
            parts.joined(separator: "\n")
        }
        set {
            assert({
                !newValue.contains("\n") && !newValue.contains("\r")
            }())
            
            parts = newValue.split(omittingEmptySubsequences: true) { character in
                character == "\r" || character == "\n"
            }
        }
    }
    
    public init(string: String) {
        parts = string.split(omittingEmptySubsequences: true) { character in
            character == "\r" || character == "\n"
        }
    }
    
    public init(stringLiteral value: String) {
        self.init(string: value)
    }
    
    internal init(unchecked parts: [String]) {
        self.parts = parts.map {
            Substring($0)
        }
    }
}

public struct SSEvent {
    // defaults to `message`
    public var type: String?
    public var comment: SSEValue?
    public var data: SSEValue
    public var id: String?
    
    public init(data: SSEValue) {
        self.data = data
    }
    
    internal func makeBuffer(allocator: ByteBufferAllocator) -> ByteBuffer {
        var string = ""
        
        if let type = type {
            string += "event: \(type)"
        }
        
        if let comment = comment {
            for part in comment.parts {
                string += ": \(part)\n"
            }
        }
        
        for part in data.parts {
            string += "data: \(part)\n"
        }
        
        if let id = id {
            string += "id: \(id)\n"
        }
        
        string.append("\n")
        
        return allocator.buffer(string: string)
    }
}
