public protocol StringInitializable {
    init?(_ string: String) throws
}

extension Int: StringInitializable { }
