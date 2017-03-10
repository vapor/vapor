private let alphanumeric = "abcdefghijklmnopqrstuvwxyz0123456789"
private let validCharacters = alphanumeric.characters

/// A validator that can be used to check that a
/// given string contains only alphanumeric characters
public struct OnlyAlphanumeric: Validator {
    public init() {}
    /**
        Validate whether or not an input string contains only
        alphanumeric characters. a...z0...9

        - parameter value: input value to validate

        - throws: an error if validation fails
    */
    public func validate(_ input: String) throws {
        let passed = input
            .lowercased()
            .characters
            .filter(validCharacters.contains)
            .count

        if passed != input.characters.count {
            throw error("\(input) is not alphanumeric")
        }
    }
}
