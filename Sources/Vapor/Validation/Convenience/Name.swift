class Name: ValidationSuite {
    static func validate(input value: String) -> Bool {
        let evaluation = OnlyAlphanumeric.self
            + StringLength.min(5)
            + StringLength.max(20)

        return value.passes(evaluation)
    }
}

// Temporary, probably better way to write
public struct OnlyAlphanumeric: ValidationSuite {
    public static func validate(input value: String) -> Bool {
        let alphanumeric = "abcdefghijklmnopqrstuvwxyz0123456789"
            .characters
        let validCharacters = value
            .characters
            .filter(alphanumeric.contains)
        return validCharacters.count == value.characters.count
    }
}
