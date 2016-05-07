import Foundation

public class Email: ValidationSuite {
    public static func validate(input value: String) throws {
        // Thanks Ben Wu :)
        let range = value.range(of: ".@.+\\..",
                                options: .regularExpressionSearch)
        guard let _ = range else {
            throw error(with: value)
        }
    }
}



