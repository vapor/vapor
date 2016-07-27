
extension JSON: Polymorphic {
    public var isNull: Bool {
        switch self {
        case .null:
            return true
        default:
            return false
        }
    }

    public var bool: Bool? {
        switch self {
        case .bool(let bool):
            return bool
        case .string(let string):
            return string.bool
        case .number(let number):
            switch number {
            case .integer(let int):
                switch int {
                case 1:
                    return true
                case 0:
                    return false
                default:
                    return nil
                }
            case .double(let double):
                switch double {
                case 1.0:
                    return true
                case 0.0:
                    return false
                default:
                    return nil
                }
            }
        default:
            return false
        }
    }

    public var float: Float? {
        switch self {
        case .number(let number):
            switch number {
            case .double(let double):
                return Float(double)
            case .integer(let int):
                return Float(int)
            }
        default:
            return nil
        }
    }

    public var double: Double? {
        switch self {
        case .number(let number):
            switch number {
            case .double(let double):
                return double
            case .integer(let int):
                return Double(int)
            }
        default:
            return nil
        }
    }

    public var int: Int? {
        switch self {
        case .number(let number):
            switch number {
            case .integer(let int):
                return int
            case .double(let double):
                return Int(double)
            }
        case .string(let string):
            return Int(string)
        default:
            return nil
        }
    }

    public var string: String? {
        switch self {
        case .string(let string):
            return string
        case .bool(let bool):
            return bool ? "true" : "false"
        case .number(let number):
            switch number {
            case .double(let double):
                return double.description
            case .integer(let int):
                return int.description
            }
        default:
            return nil
        }
    }

    public var array: [Polymorphic]? {
        switch self {
        case .array(let array):
            return array.map { item in
                return item
            }
        default:
            return nil
        }
    }

    public var object: [String : Polymorphic]? {
        switch self {
        case .object(let object):
            var dict: [String : Polymorphic] = [:]

            object.forEach { (key, val) in
                dict[key] = val
            }

            return dict
        default:
            return nil
        }
    }
}
