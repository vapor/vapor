
// Temporary, probably better way to write
public struct OnlyAlphanumeric: ValidationSuite {
    public static func validate(input value: String) throws {
        let alphanumeric = "abcdefghijklmnopqrstuvwxyz0123456789"
            .characters
        let validCharacters = value
            .lowercased()
            .characters
            .filter(alphanumeric.contains)

        guard validCharacters.count == value.characters.count else {
            throw error
        }
    }
}
