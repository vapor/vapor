
public typealias EmptyString = Validated<EmptyStringValidator>
public typealias NotEmptyString = Validated<Not<EmptyStringValidator>>

public struct EmptyStringValidator: Validator {
    public static func validate(value: String) -> Bool {
        return value.isEmpty
    }
}

public protocol RequestInitializable {
    init(_ request: Request) throws
}

public struct Example: RequestInitializable {
    let name: NotEmptyString

    public init(_ request: Request) throws {
        name = try request.data.validated("name")
    }
}
