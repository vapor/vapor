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
    static func make(with node: Node) throws -> Self
}



// MARK: String

extension String: NodeInitializable {
    public static func make(with node: Node) throws -> String {
        guard let string = node.string else {
            throw NodeError.UnableToConvert(node: node, toType: "\(self.dynamicType)")
        }

        return string
    }
}

// MARK: Boolean
extension Bool: NodeInitializable {
    public static func make(with node: Node) throws -> Bool {
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

extension UnsignedInteger {
    public static func make(with node: Node) throws -> Self {
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

extension SignedInteger {
    public static func make(with node: Node) throws -> Self {
        guard let int = node.int else {
            throw NodeError.UnableToConvert(node: node, toType: "\(self.dynamicType)")
        }

        return self.init(int.toIntMax())
    }
}


// MARK: FloatingPointType
extension Float: NodeInitializable {
    public static func make(with node: Node) throws -> Float {
        guard let float = node.float else {
            throw NodeError.UnableToConvert(node: node, toType: "\(self.dynamicType)")
        }

        return self.init(float)
    }
}

extension Double: NodeInitializable {
    public static func make(with node: Node) throws -> Double {
        guard let double = node.double else {
            throw NodeError.UnableToConvert(node: node, toType: "\(self.dynamicType)")
        }

        return self.init(double)
    }
}

public protocol NodeConvertibleFloatingPointType: NodeInitializable {
    var doubleValue: Double { get }
    init(_ other: Double)
}
