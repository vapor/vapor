import struct Foundation.Decimal

/// Capable of converting to / from `URLEncodedFormData`.
protocol URLEncodedFormFieldConvertible {
    /// Converts `URLEncodedFormData` to self.
    init?(urlEncodedFormValue value: URLQueryFragment)
    
    /// Converts self to `URLEncodedFormData`.
    var urlEncodedFormValue: URLQueryFragment { get }
}

extension String: URLEncodedFormFieldConvertible {
    init?(urlEncodedFormValue value: URLQueryFragment) {
        guard let result = try? value.asUrlDecoded() else {
            return nil
        }
        self = result
    }
    
    var urlEncodedFormValue: URLQueryFragment {
        return .urlDecoded(self)
    }
}

extension FixedWidthInteger {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlEncodedFormValue value: URLQueryFragment) {
        guard let decodedString = try? value.asUrlDecoded(),
            let fwi = Self.init(decodedString) else {
            return nil
        }
        self = fwi
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormValue: URLQueryFragment {
        return .urlDecoded(self.description)
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
    init?(urlEncodedFormValue value: URLQueryFragment) {
        guard let decodedString = try? value.asUrlDecoded(),
            let double = Double(decodedString) else {
            return nil
        }
        self = Self.init(double)
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormValue: URLQueryFragment {
        return .urlDecoded(Double(self).description)
    }
}

extension Float: URLEncodedFormFieldConvertible { }
extension Double: URLEncodedFormFieldConvertible { }

extension Bool: URLEncodedFormFieldConvertible {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlEncodedFormValue value: URLQueryFragment) {
        guard let decodedString = try? value.asUrlDecoded() else {
            return nil
        }
        switch decodedString.lowercased() {
        case "1", "true": self = true
        case "0", "false": self = false
        default: return nil
        }
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormValue: URLQueryFragment {
        return .urlDecoded(self.description)
    }
}

extension Decimal: URLEncodedFormFieldConvertible {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlEncodedFormValue value: URLQueryFragment) {
        guard let decodedString = try? value.asUrlDecoded(),
            let decimal = Decimal(string: decodedString) else {
            return nil
        }
        self = decimal
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlEncodedFormValue: URLQueryFragment {
        return .urlDecoded(self.description)
    }
}
