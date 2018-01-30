import Foundation

public class Email: ValidationSuite {
    public typealias InputType = String
    
    public static func validate(input value: String) throws {
        guard
            let localName = value.components(separatedBy: "@").first,
            isValidLocalName(localName)
            else {
                throw error(with: value)
            }

        // Thanks Ben Wu :)
        let range = value.range(of: ".@.+\\..",
                                options: .regularExpression)
        guard let _ = range else {
            throw error(with: value)
        }
    }

    private static func isValidLocalName(_ string: String) -> Bool {
        let original = string.characters
        let valid = original.filter(isValid)
        return valid.count == original.count
    }

    // Based on http://stackoverflow.com/a/2049510/2611971
    private static func isValid(_ character: Character) -> Bool {
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



