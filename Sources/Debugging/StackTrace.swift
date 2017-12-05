import Foundation

internal struct StackTrace {
    static func get(maxStackSize: Int = 32) -> [String] {
        #if os(Linux)
            return ["Stack traces not yet available on Linux"]
        #else
            return Thread.callStackSymbols
        #endif
    }
}
