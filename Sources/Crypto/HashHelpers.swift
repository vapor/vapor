import Foundation

extension Hash {
    public static func hash(_ string: String) -> Data {
        return self.hash(Data(string.utf8))
    }
}
