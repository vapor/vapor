public enum StringLength: Validator {
    case min(Int)
    case max(Int)
    case containedIn(Range<Int>)

    public func validate(input value: String) -> Bool {
        print("Testing: \(value)")
        let length = value.characters.count
        switch self {
        case .min(let m):
            return length >= m
        case .max(let m):
            return length <= m
        case .containedIn(let range):
            return range ~= length
        }
    }
}
