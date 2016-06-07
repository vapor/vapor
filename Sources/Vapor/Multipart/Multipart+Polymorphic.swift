extension Multipart: Polymorphic {
    public var isNull: Bool {
        return self.input == "null"
    }

    public var bool: Bool? {
        if case .input(let bool) = self {
            return Bool(bool)
        }

        return nil
    }

   public var int: Int? {
        guard let double = double else { return nil }
        return Int(double)
    }

    public var uint: UInt? {
        guard let double = double else { return nil }
        return UInt(double)
    }

    public var float: Float? {
        guard let double = double else { return nil }
        return Float(double)
    }

    public var double: Double? {
        if case .input(let d) = self {
            return Double(d)
        }

        return nil
    }

    public var string: String? {
        return self.input
    }
    
    public var array: [Polymorphic]? {
        guard case .input(let a) = self else {
            return nil
        }

        return [a]
    } 

    public var object: [String : Polymorphic]? {
        return nil
    }

    public var json: JSON? {
        if case .input(let j) = self {
            return JSON(j)
        }

        return nil
    }
}
