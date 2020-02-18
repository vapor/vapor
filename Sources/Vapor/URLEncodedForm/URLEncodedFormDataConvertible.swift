import struct Foundation.Decimal

/// Capable of converting to / from `URLEncodedFormData`.
protocol URLEncodedFormFieldConvertible {
    /// Converts `URLEncodedFormData` to self.
    init?(urlEncodedFormValue value: String)
    
    /// Converts self to `URLEncodedFormData`.
    var urlEncodedFormValue: String { get }
}

extension String: URLEncodedFormFieldConvertible {
    init?(urlEncodedFormValue value: String) {
        self = value
    }
    
    var urlEncodedFormValue: String {
        return self
    }
}

extension FixedWidthInteger {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlEncodedFormValue value: String) {
        guard let fwi = Self.init(value) else {
            return nil
        }
        self = fwi
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormValue: String {
        return self.description
    }
}

extension Int: URLEncodedFormFieldConvertible { }
extension Int8: URLEncodedFormFieldConvertible { }
extension Int16: URLEncodedFormFieldConvertible { }
extension Int32: URLEncodedFormFieldConvertible { }
extension Int64: URLEncodedFormFieldConvertible { }
extension UInt: URLEncodedFormFieldConvertible { }
extension UInt8: URLEncodedFormFieldConvertible { }
extension UInt16: URLEncodedFormFieldConvertible { }
extension UInt32: URLEncodedFormFieldConvertible { }
extension UInt64: URLEncodedFormFieldConvertible { }


extension BinaryFloatingPoint {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlEncodedFormValue value: String) {
        guard let double = Double(value) else {
            return nil
        }
        self = Self.init(double)
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormValue: String {
        return Double(self).description
    }
}

extension Float: URLEncodedFormFieldConvertible { }
extension Double: URLEncodedFormFieldConvertible { }

extension Bool: URLEncodedFormFieldConvertible {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlEncodedFormValue value: String) {
        switch value.lowercased() {
        case "1", "true": self = true
        case "0", "false": self = false
        default: return nil
        }
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormValue: String {
        return self.description
    }
}

extension Decimal: URLEncodedFormFieldConvertible {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlEncodedFormValue value: String) {
        guard let decimal = Decimal(string: value) else {
            return nil
        }
        self = decimal
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormValue: String {
        return self.description
    }
}


///////////////////



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
