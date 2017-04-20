public protocol StringInitializable {
    init?(_ string: String) throws
}

extension String: StringInitializable { }
extension Int: StringInitializable { }
