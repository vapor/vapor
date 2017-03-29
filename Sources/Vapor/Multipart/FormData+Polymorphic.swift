import FormData

extension FormData.Field {
    public var isNull: Bool {
        return part.body.makeString().isNull
    }
    
    public var bool: Bool? {
        return part.body.makeString().bool
    }
    
    public var double: Double? {
        return part.body.makeString().double
    }
    
    public var int: Int? {
        return part.body.makeString().int
    }
    
    public var string: String? {
        return part.body.makeString()
    }
    
    public var float: Float? {
        return part.body.makeString().float
    }
    
    public var uint: UInt? {
        return part.body.makeString().uint
    }

    public var bytes: [UInt8]? {
        return part.body
    }
}

extension FormData.Field: NodeRepresentable {
    public func makeNode(in context: Context?) -> Node {
        return Node.bytes(part.body)
    }
}
