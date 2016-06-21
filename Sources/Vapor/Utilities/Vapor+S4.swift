import S4
import C7

public typealias Byte = C7.Byte
public typealias Data = C7.Data
public typealias URI = C7.URI
public typealias SendingStream = C7.SendingStream

public typealias StructuredData = C7.StructuredData
public typealias StructuredDataInitializable = C7.StructuredDataInitializable
public typealias StructuredDataRepresentable = C7.StructuredDataRepresentable
public typealias StructuredDataConvertible = C7.StructuredDataConvertible

extension String: StructuredDataRepresentable {
    public var structuredData: StructuredData {
        return .string(self)
    }
}

extension Double: StructuredDataRepresentable {
    public var structuredData: StructuredData {
        return .double(self)
    }
}

extension Int: StructuredDataRepresentable {
    public var structuredData: StructuredData {
        return .int(self)
    }
}

extension S4.Headers {
    public typealias Key = C7.CaseInsensitiveString
}

public typealias Headers = S4.Headers
public typealias Version = S4.Version

public typealias Status = S4.Status
public typealias Method = S4.Method
