//import Bits
//import FormData
//
//extension FormData.Field {
//    public var isNull: Bool {
//        return part.body.makeString() == "null"
//    }
//    
//    public var bool: Bool? {
//        return Bool(part.body.makeString())
//    }
//    
//    public var double: Double? {
//        return Double(part.body.makeString())
//    }
//    
//    public var int: Int? {
//        return Int(part.body.makeString())
//    }
//    
//    public var string: String? {
//        return part.body.makeString()
//    }
//    
//    public var float: Float? {
//        return part.body.makeString().float
//    }
//    
//    public var uint: UInt? {
//        return part.body.makeString().uint
//    }
//
//    public var dictionary: [String : Field]? {
//        return nil
//    }
//
//    public var array: [Field]? {
//        return nil
//    }
//
//    public var bytes: Bytes? {
//        return part.body
//    }
//}
//
//extension FormData.Field: NodeRepresentable {
//    public func makeNode(in context: Context?) -> Node {
//        return Node.bytes(part.body)
//    }
//}

