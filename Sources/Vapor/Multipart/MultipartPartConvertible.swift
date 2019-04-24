import struct Foundation.Data

/// Supports converting to / from a `MultipartPart`.
public protocol MultipartPartConvertible {
    /// Converts `self` to `MultipartPart`.
    func convertToMultipartPart() throws -> MultipartPart

    /// Converts a `MultipartPart` to `Self`.
    static func convertFromMultipartPart(_ part: MultipartPart) throws -> Self
}

extension MultipartPart: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart { return self }
    
    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> MultipartPart { return part }
}

extension String: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(body: self)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> String {
        var buffer = part.body
        return buffer.readString(length: buffer.readableBytes)!
    }
}

extension FixedWidthInteger {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(headers: [:], body: self.description)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Self {
        guard let fwi = try Self(String.convertFromMultipartPart(part)) else {
            throw MultipartError(identifier: "int", reason: "Could not convert `Data` to `\(Self.self)`.")
        }
        return fwi
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
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(body: description)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Float {
        guard let float = try Float(String.convertFromMultipartPart(part)) else {
            throw MultipartError(identifier: "float", reason: "Could not convert `Data` to `\(Float.self)`.")
        }
        return float
    }
}

extension Double: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(body: description)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Double {
        guard let double = try Double(String.convertFromMultipartPart(part)) else {
            throw MultipartError(identifier: "double", reason: "Could not convert `Data` to `\(Double.self)`.")
        }
        return double
    }
}

extension Bool: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(body: description)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Bool {
        guard let option = try Bool(String.convertFromMultipartPart(part)) else {
            throw MultipartError(identifier: "boolean", reason: "Could not convert `Data` to `Bool`. Must be one of: [true, false]")
        }
        return option
    }
}

extension File: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        var part = MultipartPart(body: data)
        part.filename = filename
        part.contentType = contentType
        return part
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> File {
        guard let filename = part.filename else {
            throw MultipartError(identifier: "filename", reason: "Multipart part missing a filename.")
        }
        return File(data: part.body, filename: filename)
    }
}

extension Data: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        var buffer = ByteBufferAllocator().buffer(capacity: self.count)
        buffer.writeBytes(self)
        return MultipartPart(body: buffer)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Data {
        var buffer = part.body
        return buffer.readData(length: buffer.readableBytes)!
    }
}
