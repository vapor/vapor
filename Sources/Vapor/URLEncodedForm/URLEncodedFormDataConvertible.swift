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
