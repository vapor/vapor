/**
    A validator that can be used to check that a
    given string contains only alphanumeric characters
*/
public struct OnlyAlphanumeric: ValidationSuite {
    public typealias InputType = String
    
    private static let alphanumeric = "abcdefghijklmnopqrstuvwxyz0123456789"
    private static let validCharacters = alphanumeric.characters

    /**
        Validate whether or not an input string contains only
        alphanumeric characters. a...z0...9

        - parameter value: input value to validate

        - throws: an error if validation fails
    */
    public static func validate(input value: String) throws {
        let passed = value
            .lowercased()
            .characters
            .filter(validCharacters.contains)
            .count

        if passed != value.characters.count {
            throw error(with: value)
        }
    }
}
