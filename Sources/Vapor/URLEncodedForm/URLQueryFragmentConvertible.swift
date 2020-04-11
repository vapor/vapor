import struct Foundation.Decimal

/// Capable of converting to / from `URLQueryFragment`.
protocol URLQueryFragmentConvertible {
    /// Converts `URLQueryFragment` to self.
    init?(urlQueryFragmentValue value: URLQueryFragment)
    
    /// Converts self to `URLQueryFragment`.
    var urlQueryFragmentValue: URLQueryFragment { get }
}

extension String: URLQueryFragmentConvertible {
    init?(urlQueryFragmentValue value: URLQueryFragment) {
        guard let result = try? value.asUrlDecoded() else {
            return nil
        }
        self = result
    }
    
    var urlQueryFragmentValue: URLQueryFragment {
        return .urlDecoded(self)
    }
}

extension FixedWidthInteger {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlQueryFragmentValue value: URLQueryFragment) {
        guard let decodedString = try? value.asUrlDecoded(),
            let fwi = Self.init(decodedString) else {
            return nil
        }
        self = fwi
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlQueryFragmentValue: URLQueryFragment {
        return .urlDecoded(self.description)
    }
}

extension Int: URLQueryFragmentConvertible { }
extension Int8: URLQueryFragmentConvertible { }
extension Int16: URLQueryFragmentConvertible { }
extension Int32: URLQueryFragmentConvertible { }
extension Int64: URLQueryFragmentConvertible { }
extension UInt: URLQueryFragmentConvertible { }
extension UInt8: URLQueryFragmentConvertible { }
extension UInt16: URLQueryFragmentConvertible { }
extension UInt32: URLQueryFragmentConvertible { }
extension UInt64: URLQueryFragmentConvertible { }


extension BinaryFloatingPoint {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlQueryFragmentValue value: URLQueryFragment) {
        guard let decodedString = try? value.asUrlDecoded(),
            let double = Double(decodedString) else {
            return nil
        }
        self = Self.init(double)
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlQueryFragmentValue: URLQueryFragment {
        return .urlDecoded(Double(self).description)
    }
}

extension Float: URLQueryFragmentConvertible { }
extension Double: URLQueryFragmentConvertible { }

extension Bool: URLQueryFragmentConvertible {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlQueryFragmentValue value: URLQueryFragment) {
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
    var urlQueryFragmentValue: URLQueryFragment {
        return .urlDecoded(self.description)
    }
}

extension Decimal: URLQueryFragmentConvertible {
    /// `URLEncodedFormDataConvertible` conformance.
    init?(urlQueryFragmentValue value: URLQueryFragment) {
        guard let decodedString = try? value.asUrlDecoded(),
            let decimal = Decimal(string: decodedString) else {
            return nil
        }
        self = decimal
    }
    
    /// `URLEncodedFormDataConvertible` conformance.
    var urlQueryFragmentValue: URLQueryFragment {
        return .urlDecoded(self.description)
    }
}

extension Date: URLQueryFragmentConvertible {
    init?(urlQueryFragmentValue value: URLQueryFragment) {
        guard let double = Double(urlQueryFragmentValue: value) else {
            return nil
        }
        self = Date(timeIntervalSince1970: double)
    }
    
    var urlQueryFragmentValue: URLQueryFragment {
        return timeIntervalSince1970.urlQueryFragmentValue
    }
}

extension URL: URLQueryFragmentConvertible {
    init?(urlQueryFragmentValue value: URLQueryFragment) {
        guard let string = String(urlQueryFragmentValue: value) else {
            return nil
        }
        self.init(string: string)
    }

    var urlQueryFragmentValue: URLQueryFragment {
        self.absoluteString.urlQueryFragmentValue
    }
}
