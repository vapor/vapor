extension String: Polymorphic {
    public var isNull: Bool {
        return self == "null"
    }

    public var bool: Bool? {
        return Bool(self)
    }

    public var int: Int? {
        guard let double = double else { return nil }
        return Int(double)
    }

    public var float: Float? {
        guard let double = double else { return nil }
        return Float(double)
    }

    public var double: Double? {
        return Double(self)
    }

    public var string: String? {
        return self
    }

    public var array: [Polymorphic]? {
        return self
            .components(separatedBy: ",")
            .map { $0 as Polymorphic }
    }

    public var object: [String : Polymorphic]? {
        return nil
    }
}

