import Foundation
import libc

extension Int {
    /// Generates a random number between (and inclusive of)
    /// the given minimum and maximum.
    static private var randomInitialized: Bool = false

    public static func random(min: Int, max: Int) -> Int {
        let top = max - min + 1
        #if os(Linux)
            if !Int.randomInitialized {
                let current = Date().timeIntervalSinceReferenceDate
                let salt = current.truncatingRemainder(dividingBy: 1) * 100000000
                libc.srand(UInt32(current + salt))
                Int.randomInitialized = true
            }
            return Int(libc.random() % top) + min
        #else
            return Int(arc4random_uniform(UInt32(top))) + min
        #endif
    }
}
