import Foundation

internal struct StackTrace {
    static func get(maxStackSize: Int = 32) -> [String] {
        #if os(Linux)
            return ["Stack traces not yet available on Linux"]
        #else
            return Thread.callStackSymbols
        #endif
        /*
        #if os(Linux)
            return ["Stack traces coming to Linux soon."]
        #else
            var count: Int32 = 0
            let maxStackSize = Int32(maxStackSize)
            guard let cStrings = get_stack_trace(maxStackSize, &count) else {
                return []
            }

            var result: [String] = []

            for i in 0..<Int(count) {
                guard let cString = cStrings[i] else {
                    break
                }

                let string = String(cString: cString)
                free(cString)
                let demangled = _stdlib_demangleName(string)
                result.append(demangled)
            }

            free(cStrings)
            return result.flatMap {
                guard $0.count > 5 else {
                    // removes strange empty / garbage lines
                    return nil
                }
                return $0
            }
        #endif
        */
    }
}
