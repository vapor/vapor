import Foundation

extension Hash {
    /// Hashes the string as `UTF-8` encoded data
    public static func hash(_ string: String) -> Data {
        return self.hash(Data(string.utf8))
    }
}
