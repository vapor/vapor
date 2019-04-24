import struct Foundation.Decimal

/// Capable of converting to / from `URLEncodedFormData`.
protocol URLEncodedFormDataConvertible {
    /// Converts `URLEncodedFormData` to self.
    init?(urlEncodedFormData: URLEncodedFormData)
    
    /// Converts self to `URLEncodedFormData`.
    var urlEncodedFormData: URLEncodedFormData? { get }
}

extension String: URLEncodedFormDataConvertible {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlEncodedFormData: URLEncodedFormData) {
        guard let string = urlEncodedFormData.string else {
            return nil
        }
        
        self = string
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormData: URLEncodedFormData? {
        return .string(self)
    }
}

extension FixedWidthInteger {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlEncodedFormData: URLEncodedFormData) {
        guard let fwi = urlEncodedFormData.string.flatMap(Self.init) else {
            return nil
        }
        
        self = fwi
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormData: URLEncodedFormData? {
        return .string(self.description)
    }
}

extension Int: URLEncodedFormDataConvertible { }
extension Int8: URLEncodedFormDataConvertible { }
extension Int16: URLEncodedFormDataConvertible { }
extension Int32: URLEncodedFormDataConvertible { }
extension Int64: URLEncodedFormDataConvertible { }
extension UInt: URLEncodedFormDataConvertible { }
extension UInt8: URLEncodedFormDataConvertible { }
extension UInt16: URLEncodedFormDataConvertible { }
extension UInt32: URLEncodedFormDataConvertible { }
extension UInt64: URLEncodedFormDataConvertible { }

extension BinaryFloatingPoint {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlEncodedFormData: URLEncodedFormData) {
        guard let bfp = urlEncodedFormData.string.flatMap(Double.init).flatMap(Self.init) else {
            return nil
        }
        self = bfp
    }

    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormData: URLEncodedFormData? {
        return .string(Double(self).description)
    }
}

extension Float: URLEncodedFormDataConvertible { }
extension Double: URLEncodedFormDataConvertible { }

extension Bool: URLEncodedFormDataConvertible {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlEncodedFormData: URLEncodedFormData) {
        guard let string = urlEncodedFormData.string else {
            return nil
        }
        switch string.lowercased() {
        case "1", "true": self = true
        case "0", "false": self = false
        default: return nil
        }
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormData: URLEncodedFormData? {
        return .string(self.description)
    }
}

extension Decimal: URLEncodedFormDataConvertible {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlEncodedFormData: URLEncodedFormData) {
        guard let string = urlEncodedFormData.string, let decimal = Decimal(string: string) else {
            return nil
        }
        
        self = decimal
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormData: URLEncodedFormData? {
        return .string(self.description)
    }
}
