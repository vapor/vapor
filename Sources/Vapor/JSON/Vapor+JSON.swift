import Jay

/**
    Allows Json to be returned in any vapor Closure
*/  
extension Json: ResponseConvertible {
    public func response() -> Response {
        do {
            let data = try serialize()
            return Response(status: .OK, data: data, contentType: .Json)
        } catch {
            //return error!
            let errorString = "\(error)"
            //TODO: which response? 500? 400? should we be leaking the error?
            return Response(error: errorString)
        }
    }
}

// MARK: Request Json
extension Request {

    /**
        If the body can be serialized as Json, the value will be returned here
    */
    public var json: Json? {
        return try? Json.deserialize(body)
    }
}

/**
 *  An umbrella protocol used to define behavior to and from Json
 */
public protocol NodeInitializable {
    
    /**
        This function will be used to create an instance of the type from Json
         
         - parameter json: the json to use in initialization
         - throws: a potential error.  ie: invalid json type
         - returns: an initialized object
    */
    static func makeWith(node: Node) throws -> Self
}

// MARK: Json Convertible Initializers
extension Json {
    
    /**
         Create Json from any convertible type
         
         - parameter any: the convertible type
         - throws: a potential conversion error
         - returns: initialized Json
    */
    public init(_ any: Any) throws {
        let jsonBytes = try Jay().dataFromJson(any)
        self = try Json.deserialize(jsonBytes)
    }
}

extension Json: NodeInitializable {
    public static func makeWith(node: Node) -> Json {
        // TODO:
        return Json.Null
//        return node
    }
}

// MARK: String

extension String: NodeInitializable {
    public static func makeWith(node: Node) throws -> String {
        guard let string = node.string else {
            throw NodeError.UnableToConvert(node: node, toType: "\(self.dynamicType)")
        }
        
        return string
    }
}

// MARK: Boolean
extension Bool: NodeInitializable {
    public static func makeWith(node: Node) throws -> Bool {
        guard let bool = node.bool else {
            throw NodeError.UnableToConvert(node: node, toType: "\(self.dynamicType)")
        }
        
        return bool
    }
}


// MARK: UnsignedIntegerType
extension UInt: NodeInitializable {}
extension UInt8: NodeInitializable {}
extension UInt16: NodeInitializable {}
extension UInt32: NodeInitializable {}
extension UInt64: NodeInitializable {}

#if !swift(>=3.0)
    typealias UnsignedInteger = UnsignedIntegerType
#endif

extension UnsignedInteger {
    public static func makeWith(node: Node) throws -> Self {
        guard let int = node.uint else {
            throw NodeError.UnableToConvert(node: node, toType: "\(self.dynamicType)")
        }
        
        return self.init(int.toUIntMax())
    }
}

// MARK: SignedIntegerType
extension Int: NodeInitializable {}
extension Int8: NodeInitializable {}
extension Int16: NodeInitializable {}
extension Int32: NodeInitializable {}
extension Int64: NodeInitializable {}

#if !swift(>=3.0)
    typealias SignedInteger = SignedIntegerType
#endif

extension SignedInteger {
    public static func makeWith(node: Node) throws -> Self {
        guard let int = node.int else {
            throw NodeError.UnableToConvert(node: node, toType: "\(self.dynamicType)")
        }
        
        return self.init(int.toIntMax())
    }
}


// MARK: FloatingPointType
extension Float: NodeInitializable {
    public static func makeWith(node: Node) throws -> Float {
        guard let float = node.float else {
            throw NodeError.UnableToConvert(node: node, toType: "\(self.dynamicType)")
        }
        
        return self.init(float)
    }
}

extension Double: NodeInitializable {
    public static func makeWith(node: Node) throws -> Double {
        guard let double = node.double else {
            throw NodeError.UnableToConvert(node: node, toType: "\(self.dynamicType)")
        }
        
        return self.init(double)
    }
}

public protocol NodeConvertibleFloatingPointType : NodeInitializable {
    var doubleValue: Double { get }
    init(_ other: Double)
}
