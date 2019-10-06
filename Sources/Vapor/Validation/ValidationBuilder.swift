@_functionBuilder
public struct ValidationBuilder {
    public static func buildBlock(_ v: Validation ...) -> [Validation] { v }
}

public func Validations(@ValidationBuilder build: () -> [Validation]) -> [Validation] {
    build()
}

extension Validation {
    public init(key: BasicCodingKey, required: Bool = true, @ValidationBuilder builder: () -> [Validation]) {
        self.init(key: key, required: required, validations: builder())
    }
    public init(key: String, required: Bool = true, @ValidationBuilder builder: () -> [Validation]) {
        self.init(key: BasicCodingKey(key), required: required, builder: builder)
    }
    public init(key: CodingKey, required: Bool = true, @ValidationBuilder builder: () -> [Validation]) {
        self.init(key: BasicCodingKey(key), required: required, builder: builder)
    }
}
