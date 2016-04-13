public struct Validation {
    public enum Error: ErrorProtocol {
        case Failed(Any)
    }
}

extension Validator {
    public static var error: ErrorProtocol {
        return Validation.Error.Failed(Self)
    }
    public var error: ErrorProtocol {
        return Validation.Error.Failed(self)
    }
}
