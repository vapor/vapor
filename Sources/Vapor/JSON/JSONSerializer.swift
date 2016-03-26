import Jay

public  typealias JayType = JsonValue

/**
    Handles the conversion from JayType
    Json values to Vapor Json values.
*/
public enum Json {
    
    public init(_ obj: Any) {
        self = .NullValue
    }
    
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
    public init(_ jay: JaySON) {
        print(jay)
        self = .NullValue
    }
    public init(_ jay: JayType) {
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
    #if swift(>=3.0)
        public static func deserialize<T: Sequence where T.Iterator.Element == UInt8>(source: T) throws -> Json {
            let byteArray = [UInt8](source)
            let jayValue = try Jay().typesafeJsonFromData(byteArray)
            return Json(jayValue)
        }
    #else
        public static func deserialize<T: SequenceType where T.Generator.Element == UInt8>(source: T) throws -> Json {
            let byteArray = [UInt8](source)
            let jayValue = try Jay().typesafeJsonFromData(byteArray)
            return Json(jayValue)
        }
    #endif
}

extension Json {
    
    public func serialize() throws -> [UInt8] {
        let jayValue = JayType(self)
        return try Jay().dataFromJson(jayValue)
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

