public typealias Metadata = [String: MetadataValue]

public struct MetadataValue {
    public var value: Any
    
    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }
}
   
extension MetadataValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int8 as Int8:
            try container.encode(int8)
        case let int16 as Int16:
            try container.encode(int16)
        case let int32 as Int32:
            try container.encode(int32)
        case let int64 as Int64:
            try container.encode(int64)
        case let uint as UInt:
            try container.encode(uint)
        case let uint8 as UInt8:
            try container.encode(uint8)
        case let uint16 as UInt16:
            try container.encode(uint16)
        case let uint32 as UInt32:
            try container.encode(uint32)
        case let uint64 as UInt64:
            try container.encode(uint64)
        case let float as Float:
            try container.encode(float)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let date as Date:
            try container.encode(date)
        case let url as URL:
            try container.encode(url)
        case let array as [Any?]:
            try container.encode(array.map { MetadataValue($0) })
        case let dictionary as [String: Any?]:
            try container.encode(dictionary.mapValues { MetadataValue($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "MetadataValue cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}
