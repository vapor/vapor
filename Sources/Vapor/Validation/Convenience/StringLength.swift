public enum StringLength: Validator {
    case min(Int)
    case max(Int)
    case containedIn(Range<Int>)

    public func validate(input value: String) throws {
        print("Testing: \(value)")
        let length = value.characters.count
        switch self {
        case .min(let m) where length >= m:
            break
        case .max(let m) where length <= m:
            break
        case .containedIn(let range) where range ~= length:
            break
        default:
            throw error
        }
    }
}
