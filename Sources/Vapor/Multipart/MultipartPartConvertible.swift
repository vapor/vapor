import struct Foundation.Data

public protocol MultipartPartConvertible {
    var multipart: MultipartPart? { get }
    init?(multipart: MultipartPart)
}

extension MultipartPart: MultipartPartConvertible {
    public var multipart: MultipartPart? {
        return self
    }
    
    public init?(multipart: MultipartPart) {
        self = multipart
    }
}

extension String: MultipartPartConvertible {
    public var multipart: MultipartPart? {
        return MultipartPart(body: self)
    }
    
    public init?(multipart: MultipartPart) {
        self.init(decoding: multipart.body.readableBytesView, as: UTF8.self)
    }
}

extension FixedWidthInteger {
    public var multipart: MultipartPart? {
        return MultipartPart(body: self.description)
    }
    
    public init?(multipart: MultipartPart) {
        guard let string = String(multipart: multipart) else {
            return nil
        }
        self.init(string)
    }
}

extension Int: MultipartPartConvertible { }
extension Int8: MultipartPartConvertible { }
extension Int16: MultipartPartConvertible { }
extension Int32: MultipartPartConvertible { }
extension Int64: MultipartPartConvertible { }
extension UInt: MultipartPartConvertible { }
extension UInt8: MultipartPartConvertible { }
extension UInt16: MultipartPartConvertible { }
extension UInt32: MultipartPartConvertible { }
extension UInt64: MultipartPartConvertible { }


extension Float: MultipartPartConvertible {
    public var multipart: MultipartPart? {
        return MultipartPart(body: self.description)
    }
    
    public init?(multipart: MultipartPart) {
        guard let string = String(multipart: multipart) else {
            return nil
        }
        self.init(string)
    }
}

extension Double: MultipartPartConvertible {
    public var multipart: MultipartPart? {
        return MultipartPart(body: self.description)
    }
    
    public init?(multipart: MultipartPart) {
        guard let string = String(multipart: multipart) else {
            return nil
        }
        self.init(string)
    }
}

extension Bool: MultipartPartConvertible {
    public var multipart: MultipartPart? {
        return MultipartPart(body: self.description)
    }
    
    public init?(multipart: MultipartPart) {
        guard let string = String(multipart: multipart) else {
            return nil
        }
        self.init(string)
    }
}

extension Data: MultipartPartConvertible {
    public var multipart: MultipartPart? {
        return MultipartPart(body: self)
    }
    
    public init?(multipart: MultipartPart) {
        self.init(multipart.body.readableBytesView)
    }
}
