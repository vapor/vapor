// Might have to tweak for linux
import Foundation

public class Email: ValidationSuite {
    public static func validate(input value: String) -> Bool {
        return value.range(of: ".@.+\\..", options: .regularExpressionSearch) != nil
    }
}
