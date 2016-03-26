import Jay

public  typealias JayType = JsonValue
public typealias Json = JayType

extension Json {
    public init(_ value: Bool) {
        self = .Boolean(value ? .True : .False)
    }
    
    public init(_ value: Double) {
        self = .Number(.JsonDbl(value))
    }
    
    public init(_ value: Int) {
        self = .Number(.JsonInt(value))
    }
    
    public init(_ value: Swift.String) {
        self = .String(value)
    }
    
    public init(_ value: [Json]) {
        self = .Array(value)
    }
    
    public init(_ value: JsonObject) {
        self = .Object(value)
    }
}

// MARK: Serialization

extension Json {
    #if swift(>=3.0)
        public static func deserialize<T: Sequence where T.Iterator.Element == UInt8>(source: T) throws -> Json {
            let byteArray = [UInt8](source)
            let jayValue = try Jay().typesafeJsonFromData(byteArray)
            return jayValue
        }
    #else
        public static func deserialize<T: SequenceType where T.Generator.Element == UInt8>(source: T) throws -> Json {
            let byteArray = [UInt8](source)
            let jayValue = try Jay().typesafeJsonFromData(byteArray)
            return jayValue
        }
    #endif
}

extension Json {
    public func serialize() throws -> [UInt8] {
        return try Jay().dataFromJson(self)
    }
}


// MARK: Literal Convertibles

extension Json: NilLiteralConvertible {
    public init(nilLiteral value: Void) {
        self = .Null
    }
}

extension Json: BooleanLiteralConvertible {
    public init(booleanLiteral value: BooleanLiteralType) {
        let val: JsonBoolean = value ? .True : .False
        self = .Boolean(val)
    }
}

extension Json: IntegerLiteralConvertible {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .Number(.JsonInt(value))
    }
}

extension Json: FloatLiteralConvertible {
    public init(floatLiteral value: FloatLiteralType) {
        self = .Number(.JsonDbl(Double(value)))
    }
}

extension Json: StringLiteralConvertible {
    public typealias UnicodeScalarLiteralType = Swift.String
    public typealias ExtendedGraphemeClusterLiteralType = Swift.String
    
    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self = .String(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterType) {
        self = .String(value)
    }
    
    public init(stringLiteral value: StringLiteralType) {
        self = .String(value)
    }
}

extension Json: ArrayLiteralConvertible {
    public init(arrayLiteral elements: Json...) {
        self = .Array(elements)
    }
}

extension Json: DictionaryLiteralConvertible {
    public init(dictionaryLiteral elements: (Swift.String, Json)...) {
        var object = JsonObject(minimumCapacity: elements.count)
        elements.forEach { key, value in
            object[key] = value
        }
        self = .Object(object)
    }
}


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

extension Json {
    
    /** Recursively merges two Json objects */
    mutating func merge(with json: Json) {
        switch json {
        case .Object(let object):
            guard case let .Object(object2) = self else {
                self = json
                return
            }
            
            var merged = object2
            
            for (key, value) in object {
                if let original = merged[key] {
                    var newValue = original
                    newValue.merge(with: value)
                    merged[key] = newValue
                } else {
                    merged[key] = value
                }
            }
            
            self = .Object(merged)
        case .Array(let array):
            guard case let .Array(array2) = self else {
                self = json
                return
            }
            
            self = .Array(array + array2)
        default:
            self = json
        }
        
    }
    
}