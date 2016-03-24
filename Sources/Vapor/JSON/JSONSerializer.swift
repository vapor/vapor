import Jay

private typealias JayType = JsonValue

/**
    Handles the conversion from JayType
    Json values to Vapor Json values.
*/
public enum Json: Equatable {
    
    case NullValue
    case BooleanValue(Bool)
    case NumberValue(Double)
    case StringValue(String)
    case ArrayValue([Json])
    case ObjectValue([String:Json])
    
    // MARK: Initialization
    
    public init(_ value: Bool) {
        self = .BooleanValue(value)
    }
    
    public init(_ value: Double) {
        self = .NumberValue(value)
    }
    
    public init(_ value: Int) {
        let double = Double(value)
        self.init(double)
    }
    
    public init(_ value: String) {
        self = .StringValue(value)
    }
    
    public init(_ value: [Json]) {
        self = .ArrayValue(value)
    }
    
    public init(_ value: [String : Json]) {
        self = .ObjectValue(value)
    }
}

// MARK: Mapping between Json and Jay types

extension JayType {
    private init(_ json: Json) {
        switch json {
        case .ObjectValue(let dict):
            var newDict = JsonObject()
            for (k,v) in dict {
                newDict[k] = JayType(v)
            }
            self = .Object(newDict)
        case .ArrayValue(let arr):
            var newArray = JsonArray()
            for i in arr {
                newArray.append(JayType(i))
            }
            self = .Array(newArray)
        case .NullValue:
            self = .Null
        case .NumberValue(let num):
            self = .Number(JsonNumber.JsonDbl(num))
        case .BooleanValue(let bool):
            self = .Boolean(bool ? .True : .False)
        case .StringValue(let str):
            self = .String(str)
        }
    }
}

extension Json {
    private init(_ jay: JayType) {
        switch jay {
        case .Object(let dict):
            var newDict = [String : Json]()
            for (k,v) in dict {
                newDict[k] = Json(v)
            }
            self = Json(newDict)
        case .Array(let arr):
            var newArray = [Json]()
            for i in arr {
                newArray.append(Json(i))
            }
            self = Json(newArray)
        case .Null: self = Json.NullValue
        case .Number(let num):
            switch num {
            case .JsonDbl(let dbl):
                self = Json(dbl)
            case .JsonInt(let int):
                self = Json(Double(int))
            }
        case .Boolean(let bool):
            self = Json(bool == .True)
        case .String(let str):
            self = Json(str)
        }
        
    }
}

// MARK: Serialization

extension Json {
    public static func deserialize<T: SequenceType where T.Generator.Element == UInt8>(source: T) throws -> Json {
        let byteArray = [UInt8](source)
        let jayValue = try Jay().typesafeJsonFromData(byteArray)
        return Json(jayValue)
    }
}

extension Json {
    
    public func serialize() throws -> [UInt8] {
        let jayValue = JayType(self)
        return try Jay().dataFromJson(jayValue)
    }
}

// MARK: Convenience

extension Json {
    public var isNull: Bool {
        guard case .NullValue = self else { return false }
        return true
    }
    
    public var boolValue: Bool? {
        if case let .BooleanValue(bool) = self {
            return bool
        } else if let integer = intValue where integer == 1 || integer == 0 {
            // When converting from foundation type `[String : AnyObject]`, something that I see as important,
            // it's not possible to distinguish between 'bool', 'double', and 'int'.
            // Because of this, if we have an integer that is 0 or 1, and a user is requesting a boolean val,
            // it's fairly likely this is their desired result.
            return integer == 1
        } else {
            return nil
        }
    }
    
    public var floatValue: Float? {
        guard let double = doubleValue else { return nil }
        return Float(double)
    }
    
    public var doubleValue: Double? {
        guard case let .NumberValue(double) = self else {
            return nil
        }
        
        return double
    }
    
    public var intValue: Int? {
        guard case let .NumberValue(double) = self where double % 1 == 0 else {
            return nil
        }
        
        return Int(double)
    }
    
    public var uintValue: UInt? {
        guard let intValue = intValue else { return nil }
        return UInt(intValue)
    }
    
    public var stringValue: String? {
        guard case let .StringValue(string) = self else {
            return nil
        }
        
        return string
    }
    
    public var arrayValue: [Json]? {
        guard case let .ArrayValue(array) = self else { return nil }
        return array
    }
    
    public var objectValue: [String : Json]? {
        guard case let .ObjectValue(object) = self else { return nil }
        return object
    }
}

extension Json {
    public subscript(index: Int) -> Json? {
        assert(index >= 0)
        guard let array = arrayValue where index < array.count else { return nil }
        return array[index]
    }
    
    public subscript(key: String) -> Json? {
        get {
            guard let dict = objectValue else { return nil }
            return dict[key]
        }
        set {
            guard let object = objectValue else { fatalError("Unable to set string subscript on non-object type!") }
            var mutableObject = object
            mutableObject[key] = newValue
            self = Json(mutableObject)
        }
    }
}

public func ==(lhs: Json, rhs: Json) -> Bool {
    switch lhs {
    case .NullValue:
        return rhs.isNull
    case .BooleanValue(let lhsValue):
        guard let rhsValue = rhs.boolValue else { return false }
        return lhsValue == rhsValue
    case .StringValue(let lhsValue):
        guard let rhsValue = rhs.stringValue else { return false }
        return lhsValue == rhsValue
    case .NumberValue(let lhsValue):
        guard let rhsValue = rhs.doubleValue else { return false }
        return lhsValue == rhsValue
    case .ArrayValue(let lhsValue):
        guard let rhsValue = rhs.arrayValue else { return false }
        return lhsValue == rhsValue
    case .ObjectValue(let lhsValue):
        guard let rhsValue = rhs.objectValue else { return false }
        return lhsValue == rhsValue
    }
}

// MARK: Literal Convertibles

extension Json: NilLiteralConvertible {
    public init(nilLiteral value: Void) {
        self = .NullValue
    }
}

extension Json: BooleanLiteralConvertible {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .BooleanValue(value)
    }
}

extension Json: IntegerLiteralConvertible {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .NumberValue(Double(value))
    }
}

extension Json: FloatLiteralConvertible {
    public init(floatLiteral value: FloatLiteralType) {
        self = .NumberValue(Double(value))
    }
}

extension Json: StringLiteralConvertible {
    public typealias UnicodeScalarLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    
    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self = .StringValue(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterType) {
        self = .StringValue(value)
    }
    
    public init(stringLiteral value: StringLiteralType) {
        self = .StringValue(value)
    }
}

extension Json: ArrayLiteralConvertible {
    public init(arrayLiteral elements: Json...) {
        self = .ArrayValue(elements)
    }
}

extension Json: DictionaryLiteralConvertible {
    public init(dictionaryLiteral elements: (String, Json)...) {
        var object = [String : Json](minimumCapacity: elements.count)
        elements.forEach { key, value in
            object[key] = value
        }
        self = .ObjectValue(object)
    }
}

