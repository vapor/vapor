import Foundation

internal struct StackTrace {
    static func get(maxStackSize: Int = 32) -> [String] {
        return Thread.callStackSymbols
    }
}
