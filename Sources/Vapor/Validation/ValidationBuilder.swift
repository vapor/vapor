@_functionBuilder
public struct ValidationBuilder {
    public static func buildBlock(_ v: Validation ...) -> [Validation] { v }
}

public func Validations(@ValidationBuilder build: () -> [Validation]) -> [Validation] {
    build()
}

extension Validation {
    public init(_ key: String, required: Bool = true, @ValidationBuilder builder: () -> [Validation]) {
        self.init(key, required: required, validations: builder())
    }
}
