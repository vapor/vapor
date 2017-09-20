import Foundation

public typealias UUID = Foundation.UUID

extension UUID {
    static func random() -> String {
        return UUID().uuidString
    }
}
