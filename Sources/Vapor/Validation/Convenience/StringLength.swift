/**
 Use this to validate the length of a given String

 - min:         validate length is >= associated value
 - max:         validate length <= associated value
 - containedIn: validate length is contained in range
 */
public enum StringLength: Validator {
    case min(Int)
    case max(Int)
    case containedIn(Range<Int>)

    /**
     Validate that a string passes associated length evaluation

     - parameter value: input string to validate

     - throws: an error if validation fails
     */
    public func validate(input value: String) throws {
        let length = value.characters.count
        switch self {
        case .min(let m) where length >= m:
            break
        case .max(let m) where length <= m:
            break
        case .containedIn(let range) where range ~= length:
            break
        default:
            throw error(with: value)
        }
    }
}
