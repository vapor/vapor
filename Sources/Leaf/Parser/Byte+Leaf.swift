import Bits

/// Leaf specific byte helpers
extension Byte {

    var isAllowedInIdentifier: Bool {
        return isAlphanumeric || self == .hyphen || self == .underscore || self == .colon || self == .period
    }

    var isAllowedInTagName: Bool {
        return isAlphanumeric || self == .hyphen || self == .underscore || self == .colon || self == .forwardSlash || self == .asterisk
    }
}
