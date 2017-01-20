import Polymorphic
import FormData

extension FormData.Field: Polymorphic {
    public var isNull: Bool {
        return part.body.string.isNull
    }
    
    public var bool: Bool? {
        return part.body.string.bool
    }
    
    public var double: Double? {
        return part.body.string.double
    }
    
    public var int: Int? {
        return part.body.string.int
    }
    
    public var string: String? {
        return part.body.string
    }
    
    public var array: [Polymorphic]? {
        return part.body.string.array
    }
    
    public var object: [String : Polymorphic]? {
        return part.body.string.object
    }
    
    public var float: Float? {
        return part.body.string.float
    }
    
    public var uint: UInt? {
        return part.body.string.uint
    }
}
