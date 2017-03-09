import Foundation

/// Validate a string input represents a valid Email address
public class EmailValidator: Validator {
    public init() {}

    public func validate(_ input: String) throws {
        guard
            let localName = input.components(separatedBy: "@").first,
            isValidLocalName(localName),
            // Thanks Ben Wu :)
            let _ = input.range(of: ".@.+\\..", options: .regularExpression)
            else {
                throw error("\(input) is not a valid email")
            }
    }

    private func isValidLocalName(_ string: String) -> Bool {
        let original = string.characters
        let valid = original.filter(isValid)
        return valid.count == original.count
    }

    // Based on http://stackoverflow.com/a/2049510/2611971
    private func isValid(_ character: Character) -> Bool {
        switch character {
        case "a"..."z", "A"..."Z", "0"..."9":
            return true
        // valid non alphanumeric characters
        case "!", "#", "$", "%", "&", "'", "*", "+", "-", "/", "=", "?", "^", "_", "`", "{", "|", "}", "~", ".":
            return true
        default:
            return false
        }
    }
}
